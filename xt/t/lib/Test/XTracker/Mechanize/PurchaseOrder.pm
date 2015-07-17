package Test::XTracker::Mechanize::PurchaseOrder;

use XTracker::Constants::FromDB qw( :channel );
use Test::XTracker::Data;
use Data::Dumper;
use XTracker::Constants::FromDB qw(
    :channel
    :business
    :stock_order_status
    :delivery_status
);

use Carp;


use Moose;

extends 'Test::XTracker::Mechanize';

#
# Set up the user permissions for PurchaseOrder processing
#
sub setup_user_perms {
    Test::XTracker::Model->grant_permissions(
        'it.god', 'Stock Control', 'Purchase Order', 2);
}

#
# Create a bog-standard purchase order for use in testing
#
sub create_test_data {
    my ($class, $channel_id) = @_;

    if (! defined $channel_id) {
        $channel_id = $class->get_local_channel_or_nap('nap')->id;
    }

    my $purchase_order = Test::XTracker::Data->create_from_hash({
        channel_id      => $channel_id,
        placed_by       => 'Ian Docherty',
        stock_order     => [{
            status_id       => $STOCK_ORDER_STATUS__ON_ORDER,
            product         => {
                product_type_id => 6,
                style_number    => 'ICD STYLE',
                variant         => [{
                    size_id         => 1,
                    stock_order_item    => {
                        quantity            => 40,
                    },
                },{
                    size_id         => 5,
                    stock_order_item    => {},
                }],
                product_channel => [{
                    channel_id      => $channel_id,
                    live            => 0,
                }],
                product_attribute => {
                    description     => 'New Description',
                },
                delivery => {
                    status_id       => $DELIVERY_STATUS__COUNTED,
                },
            },
        }],
    });
    return $purchase_order;
}

#
# Create data suitable for imput into RTV process
#
sub create_rtv_data {
    my ($class, $channel_id) = @_;

    if (! defined $channel_id) {
        $channel_id = $class->get_local_channel_or_nap('nap')->id;
    }

    my $purchase_order = Test::XTracker::Data->create_from_hash({
        channel_id      => $channel_id,
        placed_by       => 'Ian Docherty',
        stock_order     => [{
            status_id       => $STOCK_ORDER_STATUS__ON_ORDER,
            product         => {
                product_type_id => 6,
                style_number    => 'ICD STYLE',
                variant         => [{
                    size_id         => 1,
                    stock_order_item    => {
                        quantity            => 40,
                    },
                }],
                product_channel => [{
                    channel_id      => $channel_id,
                    live            => 0,
                }],
                product_attribute => {
                    description     => 'New Description',
                },
                price_purchase => {},
                delivery => {
                    status_id       => $DELIVERY_STATUS__COUNTED,
                },
            },
        }],
    });
    return $purchase_order;
}

#
# Create a purchase order for use in testing Vendor Sample
#
sub create_test_data_for_vendor_sample {
    my ($class, $channel_id) = @_;

    if (! defined $channel_id) {
        $channel_id = $class->get_local_channel_or_nap('nap')->id;
    }

    my $purchase_order = Test::XTracker::Data->create_from_hash({
        channel_id      => $channel_id,
        placed_by       => 'Ian Docherty',
        stock_order     => [{
            status_id       => $STOCK_ORDER_STATUS__ON_ORDER,
            product         => {
                product_type_id => 6, # Dresses
                style_number    => 'ICD STYLE',
                variant         => [{
                    type_id         => 3, # Sample
                    size_id         => 14, # Large
                    stock_order_item    => {
                        quantity            => 40,
                    },
                    stock_transfer => [{
                        shipment    => [{
                            shipment_item       => [{}],
                            shipment_class_id   => 7, # Transfer shipment
                            shipment_status_id  => 4, # Dispatched
                        }],
                    }],
                }],
                product_channel => [{
                    channel_id      => $channel_id,
                    live            => 0,
                }],
                product_attribute => {
                    description     => 'New Description',
                },
                delivery => {
                    status_id       => $DELIVERY_STATUS__COUNTED,
                },
            },
        }],
    });
    return $purchase_order;
}

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
no Moose;

1;
