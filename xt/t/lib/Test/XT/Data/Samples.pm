package Test::XT::Data::Samples;

use NAP::policy "tt",     qw( test role );

#
# Data for the test workflow of a Purchase Order
#
use Test::XTracker::Data;
use Test::XTracker::Model;


use XTracker::Database::StockTransfer qw(create_stock_transfer);

use XTracker::Constants::FromDB qw(
    :channel
    :business
    :stock_order_status
    :stock_transfer_type
    :authorisation_level
    :delivery_status
);

has attr__samples__stock_transfer => (
    is          => 'rw',
    isa         => 'XTracker::Schema::Result::Public::StockTransfer',
    lazy        => 1,
    builder     => '_attr__samples__set_stock_transfer',
    );



############################
# Attribute default builders
############################

# Create a default stock_transfer
# Assumes we already have a purchase order
#
sub _attr__samples__set_stock_transfer {
    my ($self, $args) = @_;

    my $channel        = $args->{'channel'}        || $self->channel;
    my $purchase_order = $args->{'purchase_order'} || $self->purchase_order;
    my $location_name  = $args->{'location_name'}  ||
        $self->{'attr__samples__default_location_name'};

    # Create the delivery entries for the stock order
    my $stock_order = $purchase_order->stock_orders->first;
    Test::XTracker::Model->create_delivery_for_so($stock_order);

    # Choose one of our existing stock order items to link to the
    # stock transfer we'll create
    my $variant = $args->{'variant'} || $stock_order->stock_order_items->first->variant;
    Test::XTracker::Data->ensure_product_storage_type( $variant->product );

    # We'll need a quantity in the db so that we can approve the transfer
    if ( $location_name ) {
        $self->data__quantity__insert_quantity({
            'location_name' => $location_name,
            'variant_id'    => $variant->id,
            channel_id      => $channel->id,
        });
    } else {
        note "we need a location_name, please supply a valid one";
    }

    my $stock_transfer_id = create_stock_transfer(
        $self->dbh,
        $STOCK_TRANSFER_TYPE__SAMPLE,
        1,  # maybe this should be a constant, but the code itself uses
            # the hardcoded value when it's displaying transfer requests
        $variant->id,
        $channel->id
    );

    # return the stock transfer object
    note "added stock transfer: [".$stock_transfer_id."]";
    return $self->schema->resultset('Public::StockTransfer')->find($stock_transfer_id);
}

sub data__samples__create_transfer_request {
    my ($self, $args) = @_;
    return $self->attr__samples__stock_transfer(
        $self->_attr__samples__set_stock_transfer( $args )
    );
}


1;
