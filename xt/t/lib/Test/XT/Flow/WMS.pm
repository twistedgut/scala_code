package Test::XT::Flow::WMS;

use NAP::policy "tt", qw( test role);

use XTracker::Constants qw/$APPLICATION_OPERATOR_ID/;
use Test::XTracker::Artifacts::RAVNI;
use Test::XTracker::MessageQueue;

=head1 PROCESS OVERVIEW

Documenting some of the responsibilities of the WMS.

 ..... WIP ....

=cut

has 'wms_amq' => (
    is => 'ro',
    required => 0,
    isa      =>'Test::XTracker::MessageQueue',
    default => sub { Test::XTracker::MessageQueue->new() },
);

=head2 wms_receipt_dir()

Return a L<Test::XTracker::Artifacts::RAVNI> monitor for messages going from
WMS to XT.

Note that this is a method and not an attribute as we don't want the message
monitor to persist once it's been created.

=cut

sub wms_receipt_dir {
    return Test::XTracker::Artifacts::RAVNI->new('wms_to_xt');
}

=head1 METHODS

=head2 flow_wms__send_ready_for_printing

 $flow->flow_wms__send_ready_for_printing(
   shipment_id  => $shipment_id,
   pick_station => 3
 );

=cut

sub flow_wms__send_ready_for_printing {
    my ( $self, %payload ) = @_;
    note "Sending ready_for_printing for shipment " . $payload{'shipment_id'};
    my $wms_to_xt = $self->wms_receipt_dir;
    $self->wms_amq->transform_and_send('XT::DC::Messaging::Producer::WMS::ReadyForPrinting', \%payload);
    $wms_to_xt->expect_messages({
        messages => [ { type => 'ready_for_printing' } ]
    });
}

=head2 flow_wms__send_shipment_ready(
    shipment_id => $shipment_id,
    container => { $container_id => [ sku_list ] },
);

Requires a shipment_id and a hashref containing a list of skus per container
to fake a ShipmentReady message being sent by IWS.

This message will be consumed by XTDC and the shipment will be ready to be packed.

=cut

sub flow_wms__send_shipment_ready {
    my ( $self, %args ) = @_;
    note "Sending shipment ready for " . $args{'shipment_id'};
    # Send a ShipmentReady
    my @containers = ( map {
        {
            container_id => $_,
            items => [
                map {{ sku => $_, quantity => 1 }} @{ $args{container}{$_} }
            ],
        }
    } keys %{$args{container}} );

    my $wms_to_xt = $self->wms_receipt_dir;
    $self->wms_amq->transform_and_send( 'XT::DC::Messaging::Producer::WMS::ShipmentReady', [$args{shipment_id}, \@containers] );
    $wms_to_xt->expect_messages({
        messages => [ { type => 'shipment_ready' } ]
    });

    return $self;
}

=head2 flow_wms__send_stock_changed (
    transfer_id => $transfer_id,
);

Requires a transfer id to fake a StockChanged message from IWS.

This message will be consumed by XT to complete a channel transfer.

One day we might use the stock_change message to change stock statuses as
well as channels, in which case we'll probably either make this method more
complicated or create a new one for that, but for now this is all we need.

=cut

sub flow_wms__send_stock_changed {
    my ( $self, $transfer_id ) = @_;
    note "Sending stock_changed for " . $transfer_id;
    my $wms_to_xt = $self->wms_receipt_dir;
    $self->wms_amq->transform_and_send( 'XT::DC::Messaging::Producer::WMS::StockChanged', {transfer_id => $transfer_id});
    $wms_to_xt->expect_messages({
        messages => [ { type => 'stock_changed' } ]
    });

    return $self;
}

=head2 flow_wms__send_incomplete_pick(
    shipment_id => $shipment_id,
    operator_id => $operator_id
    items => { $container_id => [ sku_list ] },
);

Requires a shipment_id an operator_id and an array ref of skus
to fake an IncompletePick sent by IWS.

This message will be consumed by XTDC and the shipment will be put on hold

=cut

sub flow_wms__send_incomplete_pick {
    my ( $self, %args ) = @_;

    my $wms_to_xt = $self->wms_receipt_dir;
    # Send the message
    $self->wms_amq->transform_and_send( 'XT::DC::Messaging::Producer::WMS::IncompletePick', {
        operator_id => $args{operator_id},
        shipment_id => $args{shipment_id},
        items => [
            map {
                {
                    sku => $_,
                    quantity => 1,
                }
            } @{ $args{items} }
        ]
    });
    $wms_to_xt->expect_messages({
        messages => [ { type => 'incomplete_pick' } ]
    });
}

=head2 flow_wms__send_stock_received( sp_group_rs => $sp_group_id, operator => $operator_row );

Requires a stock process resultset to fake a StockReceived by IWS. Not passing
an operator defaults to logging the action against C<$APPLICATION_OPERATOR_ID>.

=cut

sub flow_wms__send_stock_received {
    my ( $self, %args ) = @_;

    die "death: I need either a sp_group_rs,sp or an sr"
        unless ($args{sp_group_rs} || $args{sp} || $args{sr});

    my $operator = $args{operator}
        // $self->schema->resultset('Public::Operator')->find( $APPLICATION_OPERATOR_ID );

    my $wms_to_xt = $self->wms_receipt_dir;
    # Send the message
    $self->wms_amq->transform_and_send( 'XT::DC::Messaging::Producer::WMS::StockReceived', {
        %args,
        operator => $args{operator},
    });
    $wms_to_xt->expect_messages({
        messages => [ { type => 'stock_received' } ]
    });
}


=head2 flow_wms__send_inventory_adjust( %args );

Fake an inventory request from IWS. Accepts a hash, with the
following keys:

=over

=item C<sku> - I<Req> sku

=item C<quantity_change> - I<Req> Negative quantity

=item C<reason> - I<req> reason

=item C<stock_status> - I<req> enum : main, sample, faulty, rtv, dead

=cut

sub flow_wms__send_inventory_adjust {
    my ( $self, %args ) = @_;

    my $wms_to_xt = $self->wms_receipt_dir;
    # Send the message
    $self->wms_amq->transform_and_send( 'XT::DC::Messaging::Producer::WMS::InventoryAdjust', \%args );
    $wms_to_xt->expect_messages({
        messages => [ { type => 'inventory_adjust' } ]
    });
}

=head2 flow_wms__send_picking_commenced( $shipment )

Sorry about the shipment object but I'm not about to rewrite the producer.

=cut

sub flow_wms__send_picking_commenced {
    my ( $self, $shipment ) = @_;

    Carp::croak( sprintf 'shipment %i has already received picking_commenced message', $shipment->id )
        if $shipment->is_picking_commenced;
    my $wms_to_xt = $self->wms_receipt_dir;
    $self->wms_amq->transform_and_send( 'XT::DC::Messaging::Producer::WMS::PickingCommenced', $shipment );
    $wms_to_xt->expect_messages({
        messages => [ { type => 'picking_commenced' } ]
    });
}

1;
