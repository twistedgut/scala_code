#!/usr/bin/env perl

#
# Test Receive::RetailMgmt::Navigation job
#

use NAP::policy "tt", 'test';
use FindBin::libs;

use Test::XTracker::Data;
use XTracker::Constants::FromDB     qw( :product_attribute_type );

use Data::Dump qw(pp);
use Test::MockObject;
use Test::Exception;


use Test::XTracker::RunCondition database => 'full';

my ($schema);
BEGIN {
    use_ok('XTracker::Schema');
    use_ok('XTracker::Database',':common');
    use_ok("XT::JQ::DC::Receive::RetailMgmt::Navigation");
    $schema = Test::XTracker::Data->get_schema;
    isa_ok( $schema, 'XTracker::Schema' );
}


#--------------- Run TESTS ---------------

_test_navigation();

#--------------- END TESTS ---------------

done_testing;

#----------------------- Test Functions -----------------------

sub _test_navigation {

    my $payload;
    my $channel     = Test::XTracker::Data->get_local_channel();
    my $tree_rs     = $schema->resultset('Product::NavigationTree')->search( {}, { order_by => 'me.id DESC' } );
    my $tmp;
    my $old_sort_order;

    $schema->txn_do( sub {

        my $test_name   = "TESTNAMEXOX".$$;

        note "Create a Navigation Category";
        $payload    = [ {
                action      => 'add',
                channel_id  => $channel->id,
                name        => $test_name,
                level       => 1,
                is_tag      => 0,
                visible     => 1,
            } ];
        lives_ok( sub {
            send_job( $payload );
        }, "Create LEVEL 1 Category" );
        $tree_rs->reset;
        $tmp    = $tree_rs->first;
        is( $tmp->attribute->name, $test_name, "Level 1 Name Correct: $test_name" );
        cmp_ok( $tmp->attribute->attribute_type_id, '==', $PRODUCT_ATTRIBUTE_TYPE__CLASSIFICATION, "Level 1 Attr Type Correct: Classification" );
        cmp_ok( $tmp->visible, '==', 1, "Category IS Visible" );
        $old_sort_order = $tmp->sort_order;

        note "Update a Navigation Category";
        $payload->[0]{action}       = 'update';
        $payload->[0]{update_name}  = 'NEW_'.$test_name;
        $payload->[0]{visible}      = 0;
        $payload->[0]{sort_order}   = $tmp->sort_order - 1;
        lives_ok( sub {
            send_job( $payload );
        }, "Update LEVEL 1 Category" );
        $tmp->discard_changes;
        is( $tmp->attribute->name, 'NEW_'.$test_name, "Updated Level 1 Name Correct: NEW_$test_name" );
        cmp_ok( $tmp->visible, '==', 0, "Category is NOT Visible" );
        cmp_ok( $tmp->sort_order, '==', ( $old_sort_order - 1 ), "Sort Order has been Changed" );

        note "Delete a Navigation Category";
        $payload    = [ {
                action      => 'delete',
                channel_id  => $channel->id,
                name        => 'NEW_'.$test_name,
                level       => 1,
            } ];
        lives_ok( sub {
            send_job( $payload );
        }, "Delete LEVEL 1 Category with correct name" );
        $tmp->discard_changes;
        cmp_ok( $tmp->deleted, '==', 1, "Navigation Category has been deleted" );

        $schema->txn_rollback();
    } );
}


#--------------------------------------------------------------

# Creates and executes a job
sub send_job {
    my $payload = shift;

    my $fake_job = _setup_fake_job();
    my $funcname = 'XT::JQ::DC::Receive::RetailMgmt::Navigation';
    my $job = new_ok( $funcname => [ payload => $payload, schema => $schema ] );
    my $errstr = $job->check_job_payload($fake_job);
    die $errstr if $errstr;
    $job->do_the_task( $fake_job );

    return;
}


# setup a fake TheShwartz::Job
sub _setup_fake_job {
    my $fake = Test::MockObject->new();
    $fake->set_isa('TheSchwartz::Job');
    $fake->set_always( completed => 1 );
    return $fake;
}
