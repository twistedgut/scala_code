package XT::DC::Messaging::Plugins::PRL::ContainerReady;
use NAP::policy "tt", 'class';
use MooseX::Params::Validate;
use NAP::DC::Barcode::Container;
use XTracker::Constants qw/$APPLICATION_OPERATOR_ID/;
use XTracker::Constants::FromDB
    qw/:allocation_item_status :flow_status :shipment_class :shipment_item_status/;
use XT::Data::PRL::Conveyor::Route::ToPacking::FromContainerReady;
use XT::Data::PRL::Conveyor::Route::ToIntegration;
use XTracker::Logfile 'xt_logger';

=head1 NAME

XT::DC::Messaging::Consumer::Plugins::PRL::ContainerReady - Handle container_ready from PRL

=head1 DESCRIPTION

Handle container_ready from PRL

=head1 METHODS

=head2 message_type

Returns the name of the message

=cut

sub message_type { 'container_ready' }

=head2 handler

Receives the class name, context, and pre-validated payload.

=cut

sub handler {
    my ( $self, $c, $message ) = @_;

    # The contents of the message is essentially a container_id and a bunch of
    # allocation ids...
    my $container_id = NAP::DC::Barcode::Container->new_from_id($message->{'container_id'});
    my @allocation_ids = map { $_->{'allocation_id'} } @{ $message->{'allocations'} };

    # Start a transaction here, in case something goes wrong
    $c->model('Schema')->txn_do( sub {

        my @allocation_rows;
        # Loop through the allocation ids they gave us
        for my $allocation_id ( @allocation_ids ) {
            # Lookup that allocation id
            my $allocation_obj = $c->model('Schema')->resultset('Public::Allocation')->search(
                { 'me.id' => $allocation_id },
                { prefetch => { allocation_items => 'shipment_item' } }
            )->first or die sprintf( "Can't find an allocation with id [%s]",
                $allocation_id );

            push @allocation_rows, $allocation_obj;

            # Pass the allocation and the container_id to code that has a better
            # idea of what it's doing...
            $self->pick_allocation_items_in_container({
                container_id => $container_id,
                allocation   => $allocation_obj,
            });
        }

        # Send the container to integration if we can
        my $route_to_integration = XT::Data::PRL::Conveyor::Route::ToIntegration->new({
            container_id   => $container_id,
        });
        if ($route_to_integration->send(\@allocation_rows)) {
            $route_to_integration->allocation_row->create_integration_container(
                container_id    => $container_id->as_id,
                integration_prl => $route_to_integration->integration_prl_row,
            );
        } else {
            # If it's not going to integration, try to send to packing
            XT::Data::PRL::Conveyor::Route::ToPacking::FromContainerReady->new({
                container_id => $container_id,
            })->send({
                prl_amq_name => $message->{prl},
            });
        }
    } ); # end txn

}

# This may one day be a good candidate for factoring out. My opinion is that as
# of now, this is actually the best place for it. I have tried to make it as
# moveable as possible so that in the future something else can pull it out.
# The light-weight property of these plugin classes mean that it can be easily
# unit tested (or even used) by other code without that needing to have loaded
# up any handler gubbins - hence why we don't assign `$self`
sub pick_allocation_items_in_container {
    my $unused_by_design_see_comment = shift;

    my %args = validated_hash(
        \@_,
        container_id => { isa => 'NAP::DC::Barcode' },
        allocation   => { isa => 'XTracker::Schema::Result::Public::Allocation' },
    );
    my $schema = $args{'allocation'}->result_source->schema;

    # Find all the allocation items that are in this container
    my @allocation_items = grep {
        ($_->picked_into//'') eq $args{'container_id'}
    } $args{'allocation'}->allocation_items;

    # We go through each allocation item
    for my $allocation_item ( @allocation_items ) {

        # Mark it as picked
        $allocation_item->update_status($ALLOCATION_ITEM_STATUS__PICKED, $APPLICATION_OPERATOR_ID);

        # Pick the item in to the container
        my $shipment_item = $allocation_item->shipment_item;

        # Sometimes we get duplicate container_ready messages.
        # Until we can fix this bug, the following line will ignore
        # shipment items that have already been picked. Most importantly,
        # we skip the call to $move_stock below which would decrement XT's
        # inventory for the SKU a second time.
        # We do this by checking if the shipment item already thinks it is
        # in the given container.
        if ($shipment_item->container &&
            $shipment_item->container->id eq $args{'container_id'}) {

            xt_logger->info("Duplicate container_ready message received " .
                "for container $args{'container_id'} / allocation " .
                $args{'allocation'}->id);
            # return rather than next as there's no point in checking every
            # item in the allocation.
            return;
        }

        my $shipment = $shipment_item->shipment;

        my $pick_into_options = {
            # We blindly trust that IWS is right about the container, and this
            # mechanism allows it, so we're going to reuse that for the PRL.
            dont_validate => 1,
        };

        # for those items that were cancelled after request for picking was sent
        # change their status to be "cancel pending" after picking them to container
        $pick_into_options->{status} = $SHIPMENT_ITEM_STATUS__CANCEL_PENDING
            if ($shipment_item->is_cancelled || $shipment_item->is_cancel_pending);

        $shipment_item->pick_into(
            $args{'container_id'}, $APPLICATION_OPERATOR_ID, $pick_into_options
        );

        # Lookup the PRL location - this is where we're going to move the item
        # from...
        my $prl_location = $args{'allocation'}->prl_location;

        # ... and where we move it 'to' is down to if it's a Sample Transfer
        # (see: WHM-119), so we provide a curried sub that does the common part
        # of the move:
        my $move_stock = sub {
            my $to = shift;
            $schema->resultset('Public::Quantity')->move_stock({
                force           => 1,
                variant         => $shipment_item->get_true_variant->id,
                channel         => $shipment->get_channel->id,
                quantity        => 1,
                from            => {
                    location => $prl_location,
                    status   => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
                },
                to              => $to,
                log_location_as => $APPLICATION_OPERATOR_ID,
            });
        };

        # WHM-119 - Sample Transfer stock shouldn't "just disappear"
        if ($shipment->shipment_class->id == $SHIPMENT_CLASS__TRANSFER_SHIPMENT) {
            # Stock is moved to imaginary Transfer Pending location
            $move_stock->({
                location => $schema->resultset('Public::Location')->find({
                    location => 'Transfer Pending' }),
                status => $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS,
            });
        } else {
            # Stock is moved to "Nowhere"
            $move_stock->( undef );
        }

    } # End allocation_item loop
}

1;
