#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

use Test::XTracker::Data;
use XTracker::Constants     qw( :application );


use Data::Dump      qw( pp );

use_ok( 'XTracker::Database::Return' );
can_ok( 'XTracker::Database::Return', qw( update_return_arrival_AWB ) );

# get a schema and check we have one
my $schema  = Test::XTracker::Data->get_schema;
isa_ok($schema, 'XTracker::Schema',"Schema Created");

#
# This tests that the 'update_return_arrival_AWB' function can
# update records regardless of the case of the AWB used.
#

$schema->txn_do( sub {
        my $test_awb    = 'TesT111AirWayBi1L'.$$;
        note "Using Mixed case AWB: $test_awb";

        # create a Return Delivery & Return Arrival Record
        my $ret_delivery    = $schema->resultset('Public::ReturnDelivery')->create( {
                                                confirmed       => 1,
                                                date_confirmed  => \'now()',
                                                created_by      => $APPLICATION_OPERATOR_ID,
                                                operator_id     => $APPLICATION_OPERATOR_ID,
                                        } );
        my $ret_arrival     = $schema->resultset('Public::ReturnArrival')->create( {
                                                return_airway_bill  => $test_awb,
                                                return_delivery_id  => $ret_delivery->id,
                                                operator_id         => $APPLICATION_OPERATOR_ID,
                                                removed             => 0,
                                                goods_in_processed  => 0,
                                        } );

        # test you can update using the AWB in
        # a different case to what is on the record

        note "Update using all UPPER Case AWB: ".uc($test_awb);
        update_return_arrival_AWB( $schema->storage->dbh, uc($test_awb) );
        $ret_arrival->discard_changes;
        cmp_ok( $ret_arrival->goods_in_processed, '==', 1, "'goods_in_processed' field is now TRUE" );

        # reset the flag
        $ret_arrival->update( { goods_in_processed => 0 } );

        note "Update using all LOWER Case AWB: ".lc($test_awb);
        update_return_arrival_AWB( $schema->storage->dbh, lc($test_awb) );
        $ret_arrival->discard_changes;
        cmp_ok( $ret_arrival->goods_in_processed, '==', 1, "'goods_in_processed' field is now TRUE" );

        $schema->txn_rollback;
    } );

done_testing();
