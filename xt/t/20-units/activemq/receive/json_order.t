#!/usr/bin/env perl -I t/lib
use NAP::policy "tt",     'test';

use Test::XTracker::Data;
use Test::XTracker::Data::Order;
use Test::XTracker::Artifacts::JSONOrders;
use Test::Data::JSON;
use Test::XTracker::MessageQueue;

use XTracker::Config::Local                         qw( config_var );
use XTracker::Utilities                             qw( ff_deeply );

# Test procedure:
## Iterate over the json order files
## Make sure that what comes off the queue is the same as what was put onto it
## Check that after consuming the order, the order is in the /var/data/json/proc/ directory

my $schema  = Test::XTracker::Data->get_schema;

# get PID to replace the SKU in each test file
my ( $channel, $pids )  = Test::XTracker::Data->grab_products({
                                        how_many => 1,
                                        ensure_stock => 1,
                                        force_create => 1,
                                        channel => Test::XTracker::Data->channel_for_business( name => 'JC' ),
                                });
my $jc_sku      = $pids->[0]{variant}->third_party_sku->third_party_sku;
note "Using Third Party SKU: $jc_sku";

# make each Order a Premier Order to make it easier to import
my $ship_charge = $schema->resultset('Public::ShippingCharge')
                            ->search( { channel_id => $channel->id, sku => { 'ILIKE' => '%prem%' } } )
                                ->first;
my $country     = $schema->resultset('Public::Country')->find( { country => config_var('DistributionCentre','country') } );

# used to test for the presence of files in the 'processed' directory
my $proc_dir    = Test::XTracker::Artifacts::JSONOrders->new();

my $json_dir = config_var('JimmyChooOrder', 'test_data');
note "JSON DIR: $json_dir";

my $files = Test::Data::JSON->find_json_in_dir($json_dir);

my ($amq,$app) = Test::XTracker::MessageQueue->new_with_app;
my $receive_queue = Test::XTracker::Config->messaging_config
    ->{'Consumer::JimmyChooOrder'}{routes_map}{destination};

foreach my $file (@{$files}) {
    $amq->clear_destination($receive_queue);
    Test::XTracker::Data::Order->purge_order_directories('JSON');
    note 'Loading order file ' . $file;
    # Slurp and change all the order ids so that there's no conflict in the database
    my $test_data = Test::Data::JSON->slurp_json_order_file($file, { alpha_order_nr => 1 } );
    my ($test_header,$test_payload) = $amq->transform(
        'Test::XTracker::Messaging::Producer::ThirdPartyOrder',
        $test_data,
    );
    my $order_id    = $test_payload->{orders}[0]{o_id};
    note "Order Id: $order_id";

    # replace the data in the payload to be-able to import the Order
    foreach my $order ( @{ $test_payload->{orders} } ) {
        $order->{billing_detail}{address}{country}  = $country->code;
        if ( ref( $order->{delivery_detail} ) eq 'ARRAY' ) {
            # apparently Delivery Detail can be an Array according to its Parser
            foreach my $detail ( @{ $order->{delivery_detail} } ) {
                $detail->{address}{country} = $country->code;
                $_->{sku}   = $jc_sku           foreach ( @{ $detail->{order_line} } );
            }
        }
        else {
            $order->{delivery_detail}{address}{country} = $country->code;
            $_->{sku}   = $jc_sku           foreach ( @{ $order->{delivery_detail}{order_line} } );
        }
        $order->{shipping_method}   = $ship_charge->sku;
        $_->{type}      = 'Store Credit'    foreach ( @{ $order->{tender_lines} } );
    }

    # consume (import) the Order
    my $res = $amq->request(
        $app,
        $receive_queue,
        $test_payload,
        $test_header,
    );
    ok( $res->is_success, "order consumed" );

    # check if order_number exists
    my $order_obj = $schema->resultset('Public::Orders')->search({ order_nr => $order_id })->single;
    cmp_ok( $order_obj->order_nr, 'eq', $order_id, "Order Number is as expected ");

    # check the file has been moved to the 'processed'
    # directory and is for the correct Order Number
    my @proc_files  = $proc_dir->new_files();
    cmp_ok( @proc_files, '==', 1, "Found 1 file in the 'processed' directory" );
    is( $proc_files[0]{file_id}, $order_id, "and the File is for the correct Order Nr: ".$proc_files[0]{filename} );
}

Test::XTracker::Data::Order->purge_order_directories('JSON');

done_testing;
