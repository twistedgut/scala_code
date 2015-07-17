#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use Data::Dump qw/pp/;
use FindBin::libs;

use Test::Data::JSON;
use Test::XTracker::Data;

use XT::Business;
use XTracker::Constants::FromDB qw/ :currency /;

my $BASIC_BAG_MESSAGE = 'Provide basic garment bag for ';
my $LUXURY_BAG_MESSAGE = 'Provide luxury garment bag for ';

my $default_threshold = [
    {
        price => 1199,
        currency_id => $CURRENCY__GBP,
        packing_other_info => $BASIC_BAG_MESSAGE,
    },{
        price => 1200,
        currency_id => $CURRENCY__GBP,
        packing_other_info => $LUXURY_BAG_MESSAGE,
    },{
        price => 1201,
        currency_id => $CURRENCY__GBP,
        packing_other_info => $LUXURY_BAG_MESSAGE,
    },{
        price => 1919,
        currency_id => $CURRENCY__USD,
        packing_other_info => $BASIC_BAG_MESSAGE,
    },{
        price => 1920,
        currency_id => $CURRENCY__USD,
        packing_other_info => $LUXURY_BAG_MESSAGE,
    },{
        price => 1921,
        currency_id => $CURRENCY__USD,
        packing_other_info => $LUXURY_BAG_MESSAGE,
    },{
        price => 1439,
        currency_id => $CURRENCY__EUR,
        packing_other_info => $BASIC_BAG_MESSAGE,
    },{
        price => 1440,
        currency_id => $CURRENCY__EUR,
        packing_other_info => $LUXURY_BAG_MESSAGE,
    },{
        price => 1441,
        currency_id => $CURRENCY__EUR,
        packing_other_info => $LUXURY_BAG_MESSAGE,
    },
];

my %test = (
    Random => [
        {
            price => 2000,
            currency_id => $CURRENCY__GBP,
            packing_other_info => undef,
        },{
            price => 1199,
            currency_id => $CURRENCY__GBP,
            packing_other_info => undef,
        },{
            price => 1200,
            currency_id => $CURRENCY__GBP,
            packing_other_info => undef,
        },{
            price => 1201,
            currency_id => $CURRENCY__GBP,
            packing_other_info => undef,
        },{
            price => 2000,
            currency_id => $CURRENCY__USD,
            packing_other_info => undef,
        },{
            price => 1919,
            currency_id => $CURRENCY__USD,
            packing_other_info => undef,
        },{
            price => 1920,
            currency_id => $CURRENCY__USD,
            packing_other_info => undef,
        },{
            price => 1921,
            currency_id => $CURRENCY__USD,
            packing_other_info => undef,
        },{
            price => 2000,
            currency_id => $CURRENCY__EUR,
            packing_other_info => undef,
        },{
            price => 1439,
            currency_id => $CURRENCY__EUR,
            packing_other_info => undef,
        },{
            price => 1440,
            currency_id => $CURRENCY__EUR,
            packing_other_info => undef,
        },{
            price => 1441,
            currency_id => $CURRENCY__EUR,
            packing_other_info => undef,
        },
    ],
    'Casual Jackets' => $default_threshold,
    Coats => $default_threshold,
    'Formal Jackets' => $default_threshold,
    Jackets => $default_threshold,
    Suits => $default_threshold,
);


my $schema = Test::XTracker::Data->get_schema;
#my $path = 't/data/json/content_validation';
my $daddy = XT::Business->new({ });

isa_ok($daddy, 'XT::Business');

foreach my $name (keys %{$daddy->plugin_for}) {
    my $plugin =  $daddy->plugin_for->{$name};
    note "name  : $name plugin: $plugin";
}


my $channel = Test::XTracker::Data->get_local_channel_or_nap('mrp');
is($channel->web_name =~ /mrp/i, 1, 'Got mrp channel');

# CANDO-377:
# create Gift Vouchers to be used in some
# of the tests to make sure Shipments with
# Gift Vouchers still work.
my ($forget,$vouchers)  = Test::XTracker::Data->grab_products( {
            how_many => 1,
            channel => $channel,
            phys_vouchers   => {
                how_many => 1,
                want_stock => 1000,
                value => '100.00',
            },
            virt_vouchers   => {
                value => '50.00',
                how_many => 1,
            },
    } );
shift @{ $vouchers };   # discard the first normal product


my $plugin = $daddy->find_plugin($channel,'OrderImporter');

isa_ok( $plugin,
    "XT::Business::Logic::"
    . $channel->business->short_name
    . "::OrderImporter",
);

# create product with product_type for coat, jackets, suit
foreach my $product_type ( keys %test ) {
    foreach my $input ( @{ $test{$product_type} } ) {
        foreach my $with_vouchers ( 0, 1 ) {        # test that with or without vouchers everything still works ok

            my $po = create_product_with_product_type($product_type,$channel);
            my $product = $po->stock_orders->first->public_product;
            is($product->product_type->product_type, $product_type,
                "Found/created product_type $product_type");

            # create order with one of each product
            my $order_args  = {
                base => {
                    currency_id => $input->{currency_id},
                },
                pids => [
                    {
                        pid        => $product->id,
                        product    => $product,
                        variant    => $product->variants->first,
                        variant_id => $product->variants->first->id,
                        size_id    => $product->variants->first->size_id,
                        sku        => $product->variants->first->sku,
                    },
                ],
                attrs => [
                    { price => $input->{price} },
                ],
            };
            if ( $with_vouchers ) {
                note "testing with Physical & Virtual Vouchers";
                push @{ $order_args->{pids} }, @{ $vouchers };
                push @{ $order_args->{attrs} }, { price => $vouchers->[0]{product}->value };    # Physical Voucher
                push @{ $order_args->{attrs} }, { price => $vouchers->[1]{product}->value };    # Virtual Voucher
            }
            my ($order, $order_hash) = Test::XTracker::Data->create_db_order( $order_args );

            my $shipment = $order->shipments->first;

            $plugin->call('shipment_modifier',$shipment);
            $shipment->discard_changes;

            if ($input->{packing_other_info}) {
                my $currency
                    = $schema->resultset('Public::Currency')
                            ->find($input->{currency_id})
                            ->currency;
                like($shipment->packing_other_info, qr/^$input->{packing_other_info}/,
                    $shipment->packing_other_info
                . " ($product_type) for $input->{price} $currency ok")
                    or note 'expected order_id ' . $order->id . "\n"
                        . 'shipment_id ' . $shipment->id . "\n"
                        . 'currency ' . $order->currency_id;
            } else {
                is($shipment->packing_other_info,
                    undef,
                    'packing_other_info is undef as expected');
            }
        }
    }
}

done_testing;

sub create_product_with_product_type {
    my($product_type_name,$channel) = @_;
    my $product_type = retrieve_or_create_product_type($product_type_name);

    my $po = Test::XTracker::Data->create_from_hash({
        channel_id      => $channel->id,
        placed_by       => 'Bobby',
        stock_order     => [{
            product         => {
                product_type_id     => $product_type->id,
                style_number    => 'GARMENT BAG TEST',
                variant         => [{
                    size_id         => 1,
                    stock_order_item    => {
                        quantity            => 40,
                    },
                }],
                product_channel => [{
                    channel_id      => $channel->id,
                }],
                product_attribute => {
                    description     => 'New Description',
                },
                price_purchase => {},
            },
        }],
    });
}

sub retrieve_or_create_product_type {
    my($name) = @_;

    my $subtype = $schema->resultset('Public::ProductType')->find_or_create({
        product_type => $name
    });

    die "Cannot find or create subtype '$name'" if (!$subtype);

    return $subtype;
}
1;
