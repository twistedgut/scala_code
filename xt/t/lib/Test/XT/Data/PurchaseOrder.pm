package Test::XT::Data::PurchaseOrder;

use NAP::policy "tt",     qw( test role );

#
# Data for the test workflow of a Purchase Order
#
use XTracker::Config::Local;
use Test::XTracker::Data;


use XTracker::Constants::FromDB qw(
    :channel
    :business
    :stock_order_status
    :authorisation_level
    :delivery_status
    :std_size
);

has purchase_order => (
    is          => 'rw',
    isa         => 'XTracker::Schema::Result::Public::PurchaseOrder',
    lazy        => 1,
    builder     => '_set_purchase_order',
    );

has product => (
    is          => 'ro',
    lazy        => 1,
    builder     => '_set_product',
    );

has channel => (
    is          => 'ro',
    lazy        => 1,
    builder     => '_set_channel',
    );

has alternate_channel => (
    is          => 'ro',
    lazy        => 1,
    builder     => '_set_alternate_channel',
    );

has stock_order => (
    is          => 'ro',
    lazy        => 1,
    builder     => '_set_stock_order',
    );


############################
# Attribute default builders
############################

# Create a default purchase order if one is not defined.
#
sub _set_purchase_order {
    my ($self) = @_;

    my $size_ids = Test::XTracker::Data->find_valid_size_ids(2);

    my $purchase_order = Test::XTracker::Data->create_from_hash({
        channel_id      => $self->mech->channel->id,
        placed_by       => 'Ian Docherty',
        stock_order     => [{
            status_id       => $STOCK_ORDER_STATUS__ON_ORDER,
            product         => {
                product_type_id => 6,
                style_number    => 'ICD STYLE',
                variant         => [{
                    size_id         => $size_ids->[0],
                    stock_order_item    => {
                        quantity            => 40,
                    },
                },{
                    size_id         => $size_ids->[1],
                    stock_order_item    => {
                        quantity            => 33,
                    },
                }],
                product_channel => [{
                    channel_id      => $self->mech->channel->id,
                    upload_date     => \'now()',
                }],
                product_attribute => {
                    description     => 'New Description',
                },
                price_purchase => {},
                #delivery => {
                #    status_id   => $DELIVERY_STATUS__COUNTED,
                #},
            },
        }],
    });

    return $purchase_order;
}

# Return the product
#
sub _set_product {
    my ($self) = @_;

    # Create an RTV location
    my $schema  = Test::XTracker::Data->get_schema;

    my $stock_order = $self->purchase_order->stock_orders->first;
    my $product     = $stock_order->public_product;

    return $product;
}

# Create the channel
#
sub _set_channel {
    my ($self) = @_;

    my $channel = Test::XTracker::Data->get_local_channel_or_nap('nap');
}

# Create an alternate channel
# Because sometimes we need to do tests that involve more than one
# Should be ok to use outnet for this
#
sub _set_alternate_channel {
    my ($self) = @_;

    my $channel = Test::XTracker::Data->get_local_channel('out');
}

# Return the stock_order
#
sub _set_stock_order {
    my ($self) = @_;

    my $schema  = Test::XTracker::Data->get_schema;

    my $stock_order = $self->purchase_order->stock_orders->first;

    return $stock_order;
}

1;
