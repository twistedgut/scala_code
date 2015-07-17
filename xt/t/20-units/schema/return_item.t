#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;


use Test::XTracker::Data;
use Test::XTracker::Carrier;

use XTracker::Constants     qw( :application );




# evil globals
our ($schema);

BEGIN {
    use_ok('XTracker::Schema');
    use_ok('XTracker::Database',':common');
    use_ok('XTracker::Schema::Result::Public::ReturnItem');
    use_ok('XTracker::Schema::ResultSet::Public::ReturnItem');
    can_ok('XTracker::Schema::ResultSet::Public::ReturnItem',
           qw(
                 update_exchange_item_id
         )
       );
}

# get a schema to query
$schema = get_database_handle(
    {
        name    => 'xtracker_schema',
    }
);
isa_ok($schema, 'XTracker::Schema',"Schema Created");

my($channel,$pids) = Test::XTracker::Data->grab_products({
    how_many => 2,
});
my $rma = Test::XTracker::Data->create_rma({
    items => {
        map {
            $_->{sku} => { },
        } @$pids,
    }
}, $pids);

my $ri_rs = $schema->resultset('Public::ReturnItem');
isa_ok($ri_rs, 'XTracker::Schema::ResultSet::Public::ReturnItem', "Return Item Result Set");

eval { $ri_rs->update_exchange_item_id( 1, 2 ); };
like($@,qr/Type not passed in or not recognised don't know what to search on!/, "'update_exchange_item_id' method failed with no 'Type' passed in" );
eval { $ri_rs->update_exchange_item_id( 1, 2, 'NOT_EXIST' ); };
like($@,qr/Type not passed in or not recognised don't know what to search on!/, "'update_exchange_item_id' method failed with wrong 'Type' passed in" );


$schema->txn_do( sub {
        my @ship_items  = $schema->resultset('Public::ShipmentItem')->search( undef, { rows => 2 } )->all;
        my $ri  = $ri_rs->search( undef, { rows => 1 } )->first;

        # test 'update_exchange_item_id' with type 'shipment'
        $ri->update( { shipment_item_id => $ship_items[0]->id, exchange_shipment_item_id => undef } );
        $ri_rs->update_exchange_item_id( $ship_items[0]->id, $ship_items[1]->id, 'shipment' );
        $ri->discard_changes;
        cmp_ok( $ri->exchange_shipment_item_id, '==', $ship_items[1]->id, "Exchange Shipment Item Id Updated as expected based on Shipment Search" );

        # test 'update_exchange_item_id' with type 'exchange'
        $ri_rs->update_exchange_item_id( $ship_items[1]->id, $ship_items[0]->id, 'exchange' );
        $ri->discard_changes;
        cmp_ok( $ri->exchange_shipment_item_id, '==', $ship_items[0]->id, "Exchange Shipment Item Id Updated as expected based on Exchange Search" );

        $schema->txn_rollback();
    } );


done_testing();
