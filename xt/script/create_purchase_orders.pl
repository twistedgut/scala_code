#!/opt/xt/xt-perl/bin/perl -w

# script to allow tester to create purchase orders

use strict;
use warnings;

use lib 't/lib/';
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );

use Test::XT::Flow;
use Test::XTracker::Data;

use XTracker::Constants::FromDB qw(
    :stock_order_status
);

my $flow = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Data::Location',
        'Test::XT::Data::PurchaseOrder',
        'Test::XT::Flow::GoodsIn',
        'Test::XT::Flow::StockControl',
        'Test::XT::Feature::AppMessages',
        'Test::XT::Feature::Ch11n',
        'Test::XT::Feature::Ch11n::GoodsIn',
        'Test::XT::Feature::Ch11n::StockControl',
        'Test::XT::Flow::WMS',
    ],
);

my $purchase_order;
my $channel_id_rs = $flow->schema->resultset('Public::Channel')->get_column('id');

while (my $channel_id = $channel_id_rs->next){

    $purchase_order = Test::XTracker::Data->create_from_hash({
        channel_id      => $channel_id,
        placed_by       => 'Toni Turbo',
        stock_order     => [{
            status_id       => $STOCK_ORDER_STATUS__ON_ORDER,
            product         => {
                product_type_id => 61,
                style_number    => 'ICD STYLE',
                variant         => [{
                    size_id         => 1,
                    stock_order_item    => {
                        quantity            => 40,
                    },
                }],
                product_channel => [{
                    channel_id      => $channel_id,
                }],
                product_attribute => {
                    description     => 'Turbonator Description',
                },
                price_purchase => {},
            },
        }],
    });

}
$flow->purchase_order($purchase_order);
