package Test::Role::DBSamples;

use Carp;

use NAP::policy "tt", qw/test role/;
use Test::XTracker::Data;
use Test::XT::Data;
use XTracker::Constants::FromDB qw(
    :flow_status
    :shipment_class
    :shipment_item_returnable_state
    :shipment_item_status
    :shipment_status
    :shipment_type
    :stock_transfer_status
    :stock_transfer_type
);

requires 'schema';

has 'test_data' => (
    is  => 'ro',
    isa => 'Test::XT::Data',
    lazy_build => 1,
);
sub _build_test_data {
    return Test::XT::Data->new_with_traits(
        traits => [ 'Test::XT::Data::Order' ],
    );
}

# Make the transfer appear on the samples goods in page
# Actual mech flow would involve lots of goods in requests, apparently
#
sub flow_data__samples__update_transfer_status {
    my ($self, $stock_transfer, $variant_ids) = @_;

    croak 'You need to pass an arrayref of variant ids' unless @$variant_ids;

    # Set the correct status and class for the shipment
    $stock_transfer->link_stock_transfer__shipments->first->shipment->update({
        'shipment_status_id' => $SHIPMENT_STATUS__DISPATCHED,
        'shipment_class_id'  => $SHIPMENT_CLASS__TRANSFER_SHIPMENT,
    });

    # Move everything we've got for the variant(s) we've made into the Transfer Pending location
    # and set the status to $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS
    my $transfer_pending_location = $self->schema->resultset('Public::Location')->search({
        'location' => 'Transfer Pending',
    })->first;
    $self->schema->resultset('Public::Quantity')->search({
        'variant_id'    => $variant_ids,
    })->update({
        'location_id'   => $transfer_pending_location->id,
        'status_id'     => $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS,
    });

    return $self;
}

=head2 db__samples__create_stock_transfer

A method to create a stock transfer with overridable defaults.

=cut

sub db__samples__create_stock_transfer {
    my $self = shift;
    my $channel_id = shift || croak 'You need to specify a channel_id';
    my $variant_id = shift || croak 'You need to specify a variant_id';
    my %args = %{$_[0]||{}};

    return $self->schema->resultset('Public::StockTransfer')->create({
        variant_id => $variant_id,
        channel_id => $channel_id,
        type_id    => $args{type_id} // $STOCK_TRANSFER_TYPE__UPLOAD,
        status_id  => $args{status_id} // $STOCK_TRANSFER_STATUS__REQUESTED,
        info       => $args{info} // 'Test stock transfer',
    });
}

=head2 db__samples__create_shipment

A method to create a sample shipment.

=cut

sub db__samples__create_shipment {
    my ( $self, $args ) = @_;
    $args //= {};

    my $channel_id = $args->{channel_id} // Test::XTracker::Data->any_channel->id();
    my $variant_id = $args->{variant_id} // (Test::XTracker::Data->grab_products({
        channel_id => $channel_id,
        force_create => 1,
    }))[1][0]->{variant}->id();

    my $shipment_args = $args->{shipment}||{};
    my $shipment_item_args = $args->{shipment_item}||{};

    my $stock_transfer = $self->db__samples__create_stock_transfer(
        $channel_id, $variant_id, { status_id => $STOCK_TRANSFER_STATUS__APPROVED },
    );

    my $shipment = $stock_transfer->add_to_shipments({
        shipment_type_id    => $SHIPMENT_TYPE__PREMIER,
        shipment_class_id   => $SHIPMENT_CLASS__TRANSFER_SHIPMENT,
        shipment_status_id  => $SHIPMENT_STATUS__PROCESSING,
        email               => 'test@example.com',
        telephone           => 'samples telephone',
        mobile_telephone    => 'samples mobile',
        packing_instruction => 'Sample test',
        shipping_charge     => 0, # i.e. Unknown - Yes this is what it's set to in production too...
        shipment_address_id => Test::XTracker::Data->create_order_address_in('sample')->id,
        %$shipment_args,
    });

    $shipment->apply_SLAs;
    $shipment->create_related('shipment_items', {
        variant_id => $variant_id,
        shipment_item_status_id => $shipment_item_args->{shipment_item_status_id}
                                || $SHIPMENT_ITEM_STATUS__NEW,
        (map {; $_ => 0 } qw{unit_price tax duty}),
        returnable_state_id => $SHIPMENT_ITEM_RETURNABLE_STATE__YES,
    });

    $self->test_data->allocate_to_shipment($shipment)
        unless (!!$args->{dont_allocate});

    return $shipment;
}
