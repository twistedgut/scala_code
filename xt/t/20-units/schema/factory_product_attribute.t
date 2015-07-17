#!/usr/bin/env perl
use NAP::policy "tt", 'test';
use FindBin::libs;


use Test::XTracker::Data;
use XTracker::Constants                 qw( :application );
use XTracker::Config::Local             qw( config_var );
use XTracker::Comms::DataTransfer       qw( get_transfer_sink_handle );


use Test::Exception;

use_ok( 'XTracker::DB::Factory::ProductAttribute' );
use Test::XTracker::RunCondition database => 'full';

my $schema  = Test::XTracker::Data->get_schema();
isa_ok( $schema, 'XTracker::Schema', "sanity check: got a schema" );

my $channel = Test::XTracker::Data->get_local_channel();
my $tmp;

# set-up a dbh ref that will be passed into the functions
# for the NAP Web DB
my $dbh_ref = get_transfer_sink_handle( { environment => 'live', channel => $channel->business->config_section } );
# pass the XT DB Handle as well
$dbh_ref->{dbh_source}  = $schema->storage->dbh;
my $dbh_sink    = $dbh_ref->{dbh_sink};     # store the Web Handle for later use

my $factory = XTracker::DB::Factory::ProductAttribute->new({ schema => $schema });

$schema->txn_do( sub {

        my $attr_type   = $factory->get_attribute_types( { web_attribute => 'NAV_LEVEL3' } )->first;
        # find an appropriate channel node for the Sales Channel
        my $tree_node   = $schema->resultset('Product::NavigationTree')->search( {
                                                                'attribute.channel_id' => $channel->id
                                                            }, { join => [ 'attribute' ] } )->first;
        die "No tree node found" unless $tree_node;

        my $test_name   = 'WITHWEBDBH_TESTXOXNAME'.$$;
        ok( $tmp = $factory->create_attribute( $test_name, $attr_type->id, $channel->id, $dbh_ref ), "Create an Attribute WITH Web Handle" );
        is( $schema->resultset('Product::Attribute')->find( $tmp )->name, $test_name, "Found new Attribute and has correct 'name': $test_name" );
        ok( ($tmp) = $factory->update_attribute( $tmp, $tree_node, 'NEW_'.$test_name, $attr_type->id, $dbh_ref, $channel->id, $APPLICATION_OPERATOR_ID ),
                                                    "Update an Attribute WITH Web Handle" );
        is( $schema->resultset('Product::Attribute')->find( $tmp )->name, 'NEW_'.$test_name, "Found updated Attribute and has correct 'name': NEW_$test_name" );

        $dbh_ref->{dbh_sink}    = undef;    # clear the Web DB Handle
        $test_name  = 'NOWEBDBH_TESTXOXNAME'.$$;
        ok( $tmp = $factory->create_attribute( $test_name, $attr_type->id, $channel->id, $dbh_ref ), "Create an Attribute WITHOUT Web Handle" );
        is( $schema->resultset('Product::Attribute')->find( $tmp )->name, $test_name, "Found new Attribute and has correct 'name': $test_name" );
        ok( ($tmp) = $factory->update_attribute( $tmp, $tree_node, 'NEW_'.$test_name, $attr_type->id, $dbh_ref, $channel->id, $APPLICATION_OPERATOR_ID ),
                                                    "Update an Attribute WITHOUT Web Handle" );
        is( $schema->resultset('Product::Attribute')->find( $tmp )->name, 'NEW_'.$test_name, "Found updated Attribute and has correct 'name': NEW_$test_name" );

        $schema->txn_rollback();
    } );

done_testing();
