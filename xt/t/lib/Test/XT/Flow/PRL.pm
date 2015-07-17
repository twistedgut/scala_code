package Test::XT::Flow::PRL;

use NAP::policy "tt", qw( test role );

use Test::XTracker::Data;
use Moose::Role;
use Carp qw/croak confess/;

requires 'schema';
with 'XTracker::Role::WithAMQMessageFactory';

use XTracker::Constants qw/$APPLICATION_OPERATOR_ID :prl_type/;
use XTracker::Config::Local qw( config_var );
use XT::Data::Fulfilment::InductToPacking;

use Test::XTracker::Artifacts::RAVNI;

=head1 DESCRIPTION

Provides some methods for interacting with PRLs in tests.

=cut


has 'prl_amq' => (
    is => 'ro',
    required => 0,
    isa      =>'Test::XTracker::MessageQueue',
    default => sub { Test::XTracker::MessageQueue->new() },
);

sub prl_receipt_dir {
    return Test::XTracker::Artifacts::RAVNI->new('prls_to_xt');
}

=head1 METHODS

=head2 flow_msg__prl__products_into_transit

Move some products out of PRL into transit by sending
stock_adjust messages.

=over 4

=item how_many

How many distinct products to take out of PRL into transit

=item quantity

Product count

=item channel_id

the channel to create products in

=item Return Value

C<@products>

=back

=cut

sub flow_msg__prl__products_into_transit {
    my ($self, $args) = @_;

    my (undef, $pids) = Test::XTracker::Data->grab_products({
        how_many => $args->{how_many},
        channel_id => $args->{channel}->id,
        ensure_stock_all_variants => 1,
    });

    my ($status,$reason) = ('Main Stock','STOCK OUT TO XT');

    foreach my $transit_product (@$pids) {

        my ($sku, $product, $variant_id, $variant ) = @{$transit_product}{ qw( sku product variant_id variant ) };

        my $quantity_change = $args->{quantity};

        my $prl_receipt_dir = $self->prl_receipt_dir;
        $self->prl_amq->transform_and_send('XT::DC::Messaging::Producer::PRL::StockAdjust',{
            sku               => $sku,
            delta_quantity    => -$quantity_change,
            reason            => $reason,
            stock_status      => $status,
            stock_correction  => $PRL_TYPE__BOOLEAN__FALSE,
            'update_wms'      => $PRL_TYPE__BOOLEAN__TRUE,
            version           => '1.0',
            'total_quantity'  => 23, #   This doesn't have any effect
            'client'          => $args->{channel}->business->client->prl_name,
            'date_time_stamp' => '2012-04-02T13:24:00+0000', # And we don't do anything with this either
            'prl'             => $args->{prl},
        });

        $prl_receipt_dir->expect_messages( {
            messages => [ {   type    => 'stock_adjust',
                              path    => qr{/xt_prl$},
                              details => { reason => $reason,
                                           sku => $sku,
                                           stock_correction => $PRL_TYPE__BOOLEAN__FALSE,
                                           delta_quantity => -$quantity_change
                                       }
                          } ]
        } );
    }

    # Return list of products sent into transit
    return @$pids;
}

=head2 flow_msg__prl__pick_shipment

Pretend that our shipment has been picked into the container(s)
specified by all the PRLs it had allocations with.

Takes the same inputs as flow_wms__send_shipment_ready because it's
designed to be used from the same places.

This method just accepts what is given for sku+container combinations,
so can be used to fake a short pick by missing out some of the skus.

Things we don't worry about here:

If you specify the same container for skus coming from different PRLs,
this method doesn't care but the app itself might, so, well, don't do
that because it doesn't make sense.

If the shipment's allocations weren't already in the right state (status
should be 'picking') then all sorts of things probably won't work, but
again, we don't check that here.

If you want to split the same sku across several containers, you can't
use this (yet).

=item Return Value

None

=back

=cut

sub flow_msg__prl__pick_shipment {
    my ($self, %args) = @_;

    my $shipment = $self->schema->resultset('Public::Shipment')->find($args{shipment_id});

    return unless $shipment;
    note "faking pick messages for shipment ".$shipment->id;

    my %sku_allocations;
    my %sku_counts;
    # Map each sku to the allocation it was requested in.
    # Also make a note of how many of this sku there are in the shipment.
    foreach my $shipment_item ($shipment->shipment_items) {
        my $allocation_item = $shipment_item->active_allocation_item;
        next unless ($allocation_item); # Could legitimately not exist for virtual vouchers
        $sku_allocations{$allocation_item->variant_or_voucher_variant->sku} = $allocation_item->allocation_id;
        $sku_counts{$allocation_item->variant_or_voucher_variant->sku}++;
    }

    foreach my $container_id (keys %{$args{container}}) {
        my %container_allocations;
        foreach my $sku (@{$args{container}->{$container_id}}) {
            note "item_picked for sku $sku in container $container_id";
            for (1 .. $sku_counts{$sku}) {
                my $prl_receipt_dir = $self->prl_receipt_dir;
                $self->prl_amq->transform_and_send('XT::DC::Messaging::Producer::PRL::ItemPicked',{
                    allocation_id => $sku_allocations{$sku},
                    container_id => $container_id,
                    sku => $sku,
                    user => "Test User", #  TODO use application user?
                    pgid => "p0",  # any valid pgid will do for now - we don't use it here yet
                    client => $shipment->order->channel->business->client->prl_name,
                });
                $prl_receipt_dir->expect_messages({
                    messages => [{
                        type => 'item_picked',
                        path    => qr{/xt_prl$},
                        details => {
                            container_id => $container_id,
                            sku => $sku,
                        }
                    }]
                });
            }
            $container_allocations{$sku_allocations{$sku}} = 1;
        }
        note "container_ready for $container_id";
        my $prl_receipt_dir = $self->prl_receipt_dir;
        $self->prl_amq->transform_and_send('XT::DC::Messaging::Producer::PRL::ContainerReady',{
            container_id => $container_id,
            allocations  => [
                map { +{ allocation_id => $_ } } keys %container_allocations,
            ],
            prl          => "Full",
        });
        $prl_receipt_dir->expect_messages({
            messages => [{
                type => 'container_ready',
                path    => qr{/xt_prl$},
                details => {
                    container_id => $container_id,
                }
            }]
        });
    }

    foreach my $allocation ($shipment->allocations()) {
        note "pick_complete for allocation ".$allocation->id;
        $self->flow_msg__prl__send_pick_complete( $allocation->id );
    }

}

=head2 flow_msg__prl__send_pick_complete( $allocation_id )

Send a C<pick_complete> message.

=cut

sub flow_msg__prl__send_pick_complete {
    my ( $self, $allocation_id ) = @_;

    my $prl_receipt_dir = $self->prl_receipt_dir;
    $self->prl_amq->transform_and_send(
        'XT::DC::Messaging::Producer::PRL::PickComplete',
        { allocation_id => $allocation_id, }
    );
    $prl_receipt_dir->expect_messages({
        messages => [{
            type    => 'pick_complete',
            path    => qr{/xt_prl$},
            details => { allocation_id => $allocation_id, }
        }]
    });

    return $self;
}

=head2 flow_msg__prl__induct_container( :$container_row )

Induct the $contianer_row, if it's in the Staging Area.

=cut

sub flow_msg__prl__induct_container {
    my ($self, %args) = @_;
    my $container_row = $args{container_row};

    $container_row->is_ready_for_induction or return $self;

    my $induct = XT::Data::Fulfilment::InductToPacking->new({
        schema          => $self->schema,
        operator_id     => $APPLICATION_OPERATOR_ID,
        message_factory => $self->msg_factory,
        is_force        => 1,
    });
    $induct->set_container_row( $container_row->id, undef )
        or confess("No Container id to induct");
    $induct->set_answer_to_question("yes");
    $induct->induct_containers();

    return $self;
}

=head2 flow_msg__prl__induct_shipment( :$shipment_id?, :$shipment_row )

Induct the containers in $shipment_id/$shipment_row, if they're in the
Staging Area.

=cut

sub flow_msg__prl__induct_shipment {
    my ($self, %args) = @_;

    my $shipment_row
        = $args{shipment_row}
            || $self->schema->resultset('Public::Shipment')->find(
                $args{shipment_id},
            ) or confess("Shipment not found");
    my $container_row = $shipment_row->containers->first;

    return $self->flow_msg__prl__induct_container(
        container_row => $container_row,
    );
}

=head2 flow_msg__prl__send_pick_for_allocation ( $allocation_id )

Send a pick message for an allocation.

Note: This doesn't update any allocation or allocation_item statuses,
it just sends the message. Maybe we can have a flow_task thing to do
it all at once.

=cut

sub flow_msg__prl__send_pick_for_allocation  {
    my ($self, $allocation_id) = @_;

    $self->prl_amq->transform_and_send('XT::DC::Messaging::Producer::PRL::Pick',{
        allocation_id => $allocation_id,
    });
}

1;
