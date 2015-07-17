#!/usr/bin/env perl

use NAP::policy "tt", 'test';

# FIXME ideally should work with blank db, does not currently
use Test::XTracker::RunCondition
    database => 'full';

use XTracker::Config::Local qw( config_var );


#use XTracker::Constants::FromDB qw( :authorisation_level  );
use Data::Dump qw/pp/;
use Test::Data::JSON;
use Test::XTracker::Mock::PSP;
use Test::XTracker::Mock::DHL::XMLRequest;
use Test::XTracker::Model;
use XT::Order::Parser;
#use Test::XTracker::Model;

# loop through json data
    # parse in json OR provide perl structure
    # generate xml from structure
    # run importer
    # compare expect record OR hash against DB row

my $mock = Test::XTracker::Mock::DHL::XMLRequest->setup_mock(
    [ ({ service_code => 'LON' }) x 25 ],
);

my $path = config_var('JimmyChooOrder', 'test_data');


note "data path is : $path";

my $count;
my $files = Test::Data::JSON->find_json_in_dir($path);

my $max = scalar @{$files};
note "Found $max tests";
# read in each file and run it
foreach my $file (@{$files}) {
    ++$count;
    note "  testing.. $count/$max $file";
    eval {
        my $data = Test::Data::JSON->slurp_json_order_file($file);
        my $schema = Test::XTracker::Model->get_schema;
        $schema->txn_begin;

        my $parser = XT::Order::Parser->new_parser({
            data => $data,
            schema => $schema,
        });

        isa_ok($parser,'XT::Order::Parser::IntegrationServiceJSON');

        my $orders = $parser->parse;

        ok( @{$orders} > 0, 'Got some orders...');
        foreach ( @{$orders} ) {
            my $order_hash = ref $data eq 'ARRAY' ? shift @{$data} : $data;
            if ( exists $order_hash->{orders}->[0]->{language} ) {
                cmp_ok( $_->language_preference, 'eq', $order_hash->{orders}->[0]->{language}, 'Language is correct' );
            }
            SKIP: {
                skip "These test orders need rolling back...", 1;

                diag( "XT::Data::Order - $file" );
                isa_ok( $_, "XT::Data::Order" );
                Test::XTracker::Mock::PSP->set_coin_amount($_->gross_total->value * 100);
                $_->digest;
            }
        }
        $schema->txn_rollback;
    };

    my $e = $@;
    is($e,'','No error') && note "==> ". $e;


}

done_testing;
