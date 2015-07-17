#!/usr/bin/env perl
## no critic(ProhibitExcessMainComplexity,ProhibitUselessNoCritic)
use NAP::policy "tt", 'test';
use Data::Dump qw/pp/;
use FindBin::libs;

use Test::Data::JSON;
use Test::XTracker::Data;

use XT::Business;
use XTracker::Constants::FromDB qw/ :currency /;

my $BASIC_BAG_MESSAGE = 'Provide basic garment bag for ';
my $LONG_BAG_MESSAGE = 'Provide long garment bag for ';

my $LENGTH_THRESHOLD = 95;

my $GBP_THRESHOLD = 300;
my $EUR_THRESHOLD = 350;
my $USD_THRESHOLD = 400;

my $test = [
    {
        length => $LENGTH_THRESHOLD - 1,
        price => $GBP_THRESHOLD - 1,
        currency_id => $CURRENCY__GBP,
        packing_other_info => undef,
    },{
        length => $LENGTH_THRESHOLD - 1,
        price => $GBP_THRESHOLD,
        currency_id => $CURRENCY__GBP,
        packing_other_info => $BASIC_BAG_MESSAGE,
    },{
        length => $LENGTH_THRESHOLD - 1,
        price => $GBP_THRESHOLD + 1,
        currency_id => $CURRENCY__GBP,
        packing_other_info => $BASIC_BAG_MESSAGE,
    },{
        length => $LENGTH_THRESHOLD - 1,
        price => $EUR_THRESHOLD - 1,
        currency_id => $CURRENCY__EUR,
        packing_other_info => undef,
    },{
        length => $LENGTH_THRESHOLD - 1,
        price => $EUR_THRESHOLD,
        currency_id => $CURRENCY__EUR,
        packing_other_info => $BASIC_BAG_MESSAGE,
    },{
        length => $LENGTH_THRESHOLD - 1,
        price => $EUR_THRESHOLD + 1,
        currency_id => $CURRENCY__EUR,
        packing_other_info => $BASIC_BAG_MESSAGE,
    },{
        length => $LENGTH_THRESHOLD - 1,
        price => $USD_THRESHOLD - 1,
        currency_id => $CURRENCY__USD,
        packing_other_info => undef,
    },{
        length => $LENGTH_THRESHOLD - 1,
        price => $USD_THRESHOLD,
        currency_id => $CURRENCY__USD,
        packing_other_info => $BASIC_BAG_MESSAGE,
    },{
        length => $LENGTH_THRESHOLD - 1,
        price => $USD_THRESHOLD + 1,
        currency_id => $CURRENCY__USD,
        packing_other_info => $BASIC_BAG_MESSAGE,
    },
    {
        length => $LENGTH_THRESHOLD,
        price => $GBP_THRESHOLD - 1,
        currency_id => $CURRENCY__GBP,
        packing_other_info => undef,
    },{
        length => $LENGTH_THRESHOLD,
        price => $GBP_THRESHOLD,
        currency_id => $CURRENCY__GBP,
        packing_other_info => $LONG_BAG_MESSAGE,
    },{
        length => $LENGTH_THRESHOLD,
        price => $GBP_THRESHOLD + 1,
        currency_id => $CURRENCY__GBP,
        packing_other_info => $LONG_BAG_MESSAGE,
    },{
        length => $LENGTH_THRESHOLD,
        price => $EUR_THRESHOLD - 1,
        currency_id => $CURRENCY__EUR,
        packing_other_info => undef,
    },{
        length => $LENGTH_THRESHOLD,
        price => $EUR_THRESHOLD,
        currency_id => $CURRENCY__EUR,
        packing_other_info => $LONG_BAG_MESSAGE,
    },{
        length => $LENGTH_THRESHOLD,
        price => $EUR_THRESHOLD + 1,
        currency_id => $CURRENCY__EUR,
        packing_other_info => $LONG_BAG_MESSAGE,
    },{
        length => $LENGTH_THRESHOLD,
        price => $USD_THRESHOLD - 1,
        currency_id => $CURRENCY__USD,
        packing_other_info => undef,
    },{
        length => $LENGTH_THRESHOLD,
        price => $USD_THRESHOLD,
        currency_id => $CURRENCY__USD,
        packing_other_info => $LONG_BAG_MESSAGE,
    },{
        length => $LENGTH_THRESHOLD,
        price => $USD_THRESHOLD + 1,
        currency_id => $CURRENCY__USD,
        packing_other_info => $LONG_BAG_MESSAGE,
    },
    {
        length => $LENGTH_THRESHOLD + 1,
        price => $GBP_THRESHOLD - 1,
        currency_id => $CURRENCY__GBP,
        packing_other_info => undef,
    },{
        length => $LENGTH_THRESHOLD + 1,
        price => $GBP_THRESHOLD,
        currency_id => $CURRENCY__GBP,
        packing_other_info => $LONG_BAG_MESSAGE,
    },{
        length => $LENGTH_THRESHOLD + 1,
        price => $GBP_THRESHOLD + 1,
        currency_id => $CURRENCY__GBP,
        packing_other_info => $LONG_BAG_MESSAGE,
    },{
        length => $LENGTH_THRESHOLD + 1,
        price => $EUR_THRESHOLD - 1,
        currency_id => $CURRENCY__EUR,
        packing_other_info => undef,
    },{
        length => $LENGTH_THRESHOLD + 1,
        price => $EUR_THRESHOLD,
        currency_id => $CURRENCY__EUR,
        packing_other_info => $LONG_BAG_MESSAGE,
    },{
        length => $LENGTH_THRESHOLD + 1,
        price => $EUR_THRESHOLD + 1,
        currency_id => $CURRENCY__EUR,
        packing_other_info => $LONG_BAG_MESSAGE,
    },{
        length => $LENGTH_THRESHOLD + 1,
        price => $USD_THRESHOLD - 1,
        currency_id => $CURRENCY__USD,
        packing_other_info => undef,
    },{
        length => $LENGTH_THRESHOLD + 1,
        price => $USD_THRESHOLD,
        currency_id => $CURRENCY__USD,
        packing_other_info => $LONG_BAG_MESSAGE,
    },{
        length => $LENGTH_THRESHOLD + 1,
        price => $USD_THRESHOLD + 1,
        currency_id => $CURRENCY__USD,
        packing_other_info => $LONG_BAG_MESSAGE,
    },

];


my $schema = Test::XTracker::Data->get_schema;
#my $path = 't/data/json/content_validation';
my $daddy = XT::Business->new({ });

isa_ok($daddy, 'XT::Business');

foreach my $name (keys %{$daddy->plugin_for}) {
    my $plugin =  $daddy->plugin_for->{$name};
    note "name  : $name plugin: $plugin";
}


my $channel = Test::XTracker::Data->get_local_channel_or_nap('out');
is($channel->web_name =~ /out/i, 1, 'Got out channel');

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

foreach my $input ( @{ $test }  ) {
    foreach my $classification ( qw(Clothing Random) ) {
        foreach my $use_length ( 1,0 ) {
            foreach my $with_vouchers ( 0, 1 ) {        # test that with or without vouchers everything still works ok

                note "Classification $classification, use length flag: $use_length, with Gift Vouchers: $with_vouchers";

                # override expected msg from input when testing item with no Length or not Clothing
                my $packing_other_info;
                # if it is as in the test plan then use the test plans expected result
                if ( ($classification eq 'Clothing') && ( $use_length ) ) {
                    $packing_other_info = $input->{packing_other_info};
                # if it has no length then override the message with basic message but leave if undef aleady
                } elsif ( ($classification eq 'Clothing') && ( !$use_length ) && $input->{packing_other_info}) {
                    $packing_other_info = $BASIC_BAG_MESSAGE;
                # and if its not clothing then force to undef no matter what
                } else {
                    $packing_other_info = undef;
                }

                my $po;
                if ($use_length) {
                    $po = create_product_with_classification_and_measurement( $channel, $classification, 'Length', $input->{length} );
                } else {
                    $po = create_product_with_classification_and_measurement( $channel, $classification, 'Width', 100 );
                }

                my $product = $po->stock_orders->first->public_product;

                is($product->classification->classification, $classification,
                    "Found/created product with classification $classification");
                if ($use_length) {
                    is($product->variants->first->get_measurements->{'Length'}, $input->{length},
                        "Found/created product with variant of length $input->{length}");
                } else {
                    is($product->variants->first->get_measurements->{'Length'}, undef,
                        "Found/created product with variant that does not have a length");

                }

                # create order with one of each product
                my $order_args  = {
                    base => {
                      currency_id => $input->{currency_id},
                    },
                    pids => [{
                        pid        => $product->id,
                        product    => $product,
                        variant    => $product->variants->first,
                        variant_id => $product->variants->first->id,
                        size_id    => $product->variants->first->size_id,
                        sku        => $product->variants->first->sku,
                    }],
                    attrs => [
                        { price => $input->{price} },
                    ],
                };
                if ( $with_vouchers ) {
                    push @{ $order_args->{pids} }, @{ $vouchers };
                    push @{ $order_args->{attrs} }, { price => $vouchers->[0]{product}->value };    # Physical Voucher
                    push @{ $order_args->{attrs} }, { price => $vouchers->[1]{product}->value };    # Virtual Voucher
                }
                my ($order, $order_hash) = Test::XTracker::Data->create_db_order( $order_args );

                my $shipment = $order->shipments->first;

                $plugin->call('shipment_modifier',$shipment);
                $shipment->discard_changes;

                if ($packing_other_info) {
                    my $currency
                        = $schema->resultset('Public::Currency')
                            ->find($input->{currency_id})
                            ->currency;
                    like($shipment->packing_other_info, qr/^$packing_other_info/,
                            $shipment->packing_other_info
                            . "...  for classification: $classification length: " . ($use_length ? $input->{length} : 'undef') . " price: $input->{price} $currency ok")
                        or note 'expected order_id ' . $order->id . "\n"
                            . 'shipment_id ' . $shipment->id . "\n"
                            . 'currency ' . $order->currency_id;
                } else {
                    is($shipment->packing_other_info,
                        undef,
                        'packing_other_info is undef as expected')
                     or diag "packing_other info is $shipment->packing_other_info";
                }
            }
        }
    }
}

done_testing;

sub create_product_with_classification_and_measurement {
    my($channel, $classification_name, $measurement_type, $value) = @_;
    isa_ok( $channel, 'XTracker::Schema::Result::Public::Channel' );
    my $classification = retrieve_or_create_classification($classification_name);
    my $measurement = retrieve_or_create_measurement($measurement_type);

    my $po = Test::XTracker::Data->create_from_hash({
        placed_by       => 'Biddy',
        stock_order     => [{
            product         => {
                classification_id     => $classification->id,
                style_number    => 'GARMENT BAG TEST',
                variants         => [{
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
        skip_measurements => 1,
    });

    my $product = $po->stock_orders->first->public_product;

    $schema->resultset('Public::VariantMeasurement')->create({
        variant_id     => $product->variants->first->id,
        measurement_id => $measurement->id,
        value          => $value,
    });

    return $po;
}

sub retrieve_or_create_classification {
    my($name) = @_;

    my $classification = $schema->resultset('Public::Classification')->find_or_create({
        classification => $name
    });

    die "Cannot find or create subtype '$name'" if (!$classification);

    return $classification;
}

sub retrieve_or_create_measurement {
    my($name) = @_;

    my $measurement = $schema->resultset('Public::Measurement')->find_or_create({
        measurement => $name
    });

    die "Cannot find or create measurement '$name'" if (!$measurement);

    return $measurement;
}

