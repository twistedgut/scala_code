#!/usr/bin/env perl
use NAP::policy "tt",     'test';

=head2 Generic tests for the 'XTracker::Schmea::Result::Public::RoutingSchedule' class

This will test various things to do with the 'RoutingSchedule' class and it's appropriate associates, currently it tests:

* Reading the 'routing_schedule' table to get a list to display on the Order View page for a Shipment/RMA
* Sending Alert Notifications for various different types of 'routing_schedule' records.


First done for CANDO-373.

=cut

use Test::XTracker::LoadTestConfig;

# these are used in the '_redefined_send_email' function
my %redef_email_args    = ();
my $redef_email_todie   = 0;

# Need to re-define the 'send_email' function here before anything
# loads the 'XT::Correspondence::Method' Class, such as Schema files.
REDEFINE: {
    no warnings "redefine";
    *XT::Correspondence::Method::send_email = \&_redefined_send_email;
    use warnings "redefine";
};

use Test::XTracker::Data;
use Test::XTracker::MessageQueue;

use Data::Dump      qw( pp );
use DateTime;

use XTracker::XTemplate;
use XTracker::Config::Local         qw( config_var premier_email );
use XTracker::Constants             qw( :application );
use XTracker::Constants::FromDB     qw(
                                        :branding
                                        :correspondence_templates
                                        :customer_category
                                        :customer_issue_type
                                        :routing_schedule_status
                                        :routing_schedule_type
                                        :return_status
                                        :shipment_class
                                        :shipment_status
                                        :shipment_item_status
                                    );

use_ok( 'XT::Routing::Schedule' );


my $schema  = Test::XTracker::Data->get_schema();
isa_ok( $schema, 'XTracker::Schema', "sanity check: got a schema" );

# get a new instance of 'XT::Domain::Return'
my $domain  = Test::XTracker::Data->returns_domain_using_dump_dir();

#----------------------------------------------------------
_test_schedule_list( $schema, $domain, 1 );
_test_send_notifications( $schema, $domain, $domain->msg_factory, 1 );
#----------------------------------------------------------

done_testing();


# this tests the method 'list' on the 'ResultSet::Public::RoutingSchedule' class
sub _test_schedule_list {
    my ( $schema, $domain, $oktodo )    = @_;

    SKIP: {
        skip "_test_schedule_list", 1               if ( !$oktodo );

        note "in '_test_schedule_list'";

        # create an order
        my ( $channel, $pids )  = Test::XTracker::Data->grab_products( { channel => Test::XTracker::Data->channel_for_nap } );
        my ( $order, undef )    = Test::XTracker::Data->create_db_order( { pids => $pids } );
        my $shipment            = $order->get_standard_class_shipment;
        my $return              = _create_return( $domain, $shipment );

        note "Order Nr/Id:   ".$order->order_nr."/".$order->id;
        note "Shipment Id:   ".$shipment->id;
        note "Return RMA/Id: ".$return->rma_number."/".$return->id;

        # to be used in later tests
        my $date1           = DateTime->new( time_zone => config_var('DistributionCentre', 'timezone'), day => 20, month => 1, year => 2011, hour => 14, minute => 34, second => 56 );
        my $sched_rs        = $schema->resultset('Public::RoutingSchedule');
        my $ship_sched_rs   = $shipment->routing_schedules->search( {}, { order_by => 'id DESC' } );
        my $ret_sched_rs    = $return->routing_schedules->search( {}, { order_by => 'id DESC' } );

        # get a list of Routing Schedules to create
        my $sched_args  = _build_list_of_schedules( $date1, { delivery => 1 } );

        # these test when records get created out of sequence, which
        # happens because of the way Route Monkey outputs its XML files
        note "test 'in_correct_sequence' method";

        note "test with no records";
        my $recs    = $shipment->routing_schedules->in_correct_sequence;
        isa_ok( $recs, 'ARRAY', "Delivery: 'in_correct_sequence' returns as expected" );
        cmp_ok( scalar( @{ $recs } ), '==', 0, "Delivery: Got ZERO elements back" );
        $recs       = $return->routing_schedules->in_correct_sequence;
        isa_ok( $recs, 'ARRAY', "Collection: 'in_correct_sequence' returns as expected" );
        cmp_ok( scalar( @{ $recs } ), '==', 0, "Collection: Got ZERO elements back" );

        # this tests the method 'in_correct_sequence' which is used by
        # 'list_schedules' to process the records in the correct sequence
        # it relies on the 'rank' values on the 'routing_schedule_status'
        # which are tested in: 't/10-env/config/routing_schedule_status.t'
        my %sequence_tests  = (
                    'COMMON MIS-SEQUENCE: Re-Schedule1, Schedule1' => {
                            create  => [
                                    $sched_args->{rescheduled1},
                                    $sched_args->{scheduled1},
                                ],
                            expected=> [
                                    { %{ $sched_args->{scheduled1} } },
                                    { %{ $sched_args->{rescheduled1} } },
                                ],
                        },
                    'TWO DIFFERENT EXTERNAL IDs: Re-Schedule1, Schedule2, Schedule1'    => {
                            create  => [
                                    $sched_args->{rescheduled1},
                                    $sched_args->{scheduled2},
                                    $sched_args->{scheduled1},
                                ],
                            expected=> [
                                    { %{ $sched_args->{scheduled1} } },
                                    { %{ $sched_args->{rescheduled1} } },
                                    { %{ $sched_args->{scheduled2} } },
                                ],
                        },
                    'ALL STATUSES SAME EXTERNAL ID: Re-Schedule1, Success1, Failed1, Scheduled1'   => {
                            create  => [
                                    $sched_args->{rescheduled1},
                                    $sched_args->{success1},
                                    $sched_args->{failed1},
                                    $sched_args->{scheduled1},
                                ],
                            expected=> [
                                    { %{ $sched_args->{scheduled1} } },
                                    { %{ $sched_args->{success1} } },
                                    { %{ $sched_args->{failed1} } },
                                    { %{ $sched_args->{rescheduled1} } },
                                ],
                        },
                    'ALL STATUSES SAME EXTERNAL ID: Re-Schedule1, Failed1, Success1, Scheduled1'   => {
                            create  => [
                                    $sched_args->{rescheduled1},
                                    $sched_args->{failed1},
                                    $sched_args->{success1},
                                    $sched_args->{scheduled1},
                                ],
                            expected=> [
                                    { %{ $sched_args->{scheduled1} } },
                                    { %{ $sched_args->{failed1} } },
                                    { %{ $sched_args->{success1} } },
                                    { %{ $sched_args->{rescheduled1} } },
                                ],
                        },
                    'EXTERNAL ID MIS-SEQUENCE: Schedule3, Success3, Scheduled2, Failed2, Re-Scheduled2, Scheduled1, Failed1, Re-Scheduled1' => {
                            create  => [
                                    $sched_args->{scheduled3},
                                    $sched_args->{success3},
                                    $sched_args->{scheduled2},
                                    $sched_args->{failed2},
                                    $sched_args->{rescheduled2},
                                    $sched_args->{scheduled1},
                                    $sched_args->{failed1},
                                    $sched_args->{rescheduled1},
                                ],
                            expected=> [
                                    { %{ $sched_args->{scheduled1} } },
                                    { %{ $sched_args->{failed1} } },
                                    { %{ $sched_args->{rescheduled1} } },
                                    { %{ $sched_args->{scheduled2} } },
                                    { %{ $sched_args->{failed2} } },
                                    { %{ $sched_args->{rescheduled2} } },
                                    { %{ $sched_args->{scheduled3} } },
                                    { %{ $sched_args->{success3} } },
                                ],
                        },
                    'ALL STATUSES & EXTERNAL IDs MIS-SEQUENCE: Success3, Schedule3, Re-Scheduled2, Failed2, Scheduled2, Re-Scheduled1, Failed1, Scheduled1' => {
                            create  => [
                                    $sched_args->{success3},
                                    $sched_args->{scheduled3},
                                    $sched_args->{rescheduled2},
                                    $sched_args->{failed2},
                                    $sched_args->{scheduled2},
                                    $sched_args->{rescheduled1},
                                    $sched_args->{failed1},
                                    $sched_args->{scheduled1},
                                ],
                            expected=> [
                                    { %{ $sched_args->{scheduled1} } },
                                    { %{ $sched_args->{failed1} } },
                                    { %{ $sched_args->{rescheduled1} } },
                                    { %{ $sched_args->{scheduled2} } },
                                    { %{ $sched_args->{failed2} } },
                                    { %{ $sched_args->{rescheduled2} } },
                                    { %{ $sched_args->{scheduled3} } },
                                    { %{ $sched_args->{success3} } },
                                ],
                        },
                    'MIX-UP STATUSES & EXTERNAL IDs: Failed1, Re-Scheduled1, Scheduled1, Success3, Scheduled3, Re-Scheduled2, Scheduled2, Failed2'  => {
                            create  => [
                                    $sched_args->{failed1},
                                    $sched_args->{rescheduled1},
                                    $sched_args->{scheduled1},
                                    $sched_args->{success3},
                                    $sched_args->{scheduled3},
                                    $sched_args->{rescheduled2},
                                    $sched_args->{scheduled2},
                                    $sched_args->{failed2},
                                ],
                            expected=> [
                                    { %{ $sched_args->{scheduled1} } },
                                    { %{ $sched_args->{failed1} } },
                                    { %{ $sched_args->{rescheduled1} } },
                                    { %{ $sched_args->{scheduled2} } },
                                    { %{ $sched_args->{failed2} } },
                                    { %{ $sched_args->{rescheduled2} } },
                                    { %{ $sched_args->{scheduled3} } },
                                    { %{ $sched_args->{success3} } },
                                ],
                        },
                );

        note "test for 'Deliveries'";
        _run_sequence_tests( $shipment, \%sequence_tests );

        note "test for 'Collections'";
        _convert_tests_for_collections( \%sequence_tests, $sched_args );
        _run_sequence_tests( $return, \%sequence_tests );

        # now test the main 'list_schedules' method itself
        note "test 'list_schedules' method";
        $sched_args = _build_list_of_schedules( $date1, { delivery => 1 } );

        note "test with no records";
        my $list    = $shipment->routing_schedules->list_schedules;
        ok( !defined $list, "'list' method returns 'undef'" );

        note "test with records";
        # flags set in the return hashes
        my %expect_flags    = (
                    success => 0,
                    failed  => 0,
                    resched => 0,
                );

        my %tests   = (
                'One Scheduled Record Exists' => {
                        create  => [
                                $sched_args->{scheduled1},
                            ],
                        expected_elems  => 1,
                        expected=> [
                                {
                                    %{ $sched_args->{scheduled1} },
                                    %expect_flags,
                                },
                            ],
                    },
                'Just One Success Record Exists' => {
                        create  => [
                                $sched_args->{success1},
                            ],
                        expected_elems  => 1,
                        expected=> [
                                {
                                    %{ $sched_args->{success1} },
                                    %expect_flags,
                                    success         => 1,
                                    sig_date_cmp    => $date1,
                                },
                            ],
                    },
                'Shipment has Been Successful'=> {
                        create  => [
                                $sched_args->{scheduled1},
                                $sched_args->{success1},
                            ],
                        expected_elems  => 1,
                        expected=> [
                                {
                                    %{ $sched_args->{success1} },
                                    %expect_flags,
                                    sig_date_cmp    => $date1,
                                    success         => 1,
                                },
                            ],
                    },
                'Shipment has Been Re-Scheduled'=> {
                        create  => [
                                $sched_args->{scheduled1},
                                $sched_args->{rescheduled1},
                            ],
                        expected_elems  => 2,
                        expected=> [
                                {
                                    %{ $sched_args->{rescheduled1} },
                                    %expect_flags,
                                    task_window => 'TBC',
                                },
                                {
                                    %{ $sched_args->{scheduled1} },
                                    %expect_flags,
                                    resched => 1,
                                },
                            ],
                    },
                'Scheduled, Re-Schedule, Re-Schedule'=> {
                        create  => [
                                $sched_args->{scheduled1},
                                $sched_args->{rescheduled1},
                                $sched_args->{rescheduled2},
                            ],
                        expected_elems  => 2,
                        expected=> [
                                {
                                    %{ $sched_args->{rescheduled2} },
                                    %expect_flags,
                                    task_window => 'TBC',
                                },
                                {
                                    %{ $sched_args->{scheduled1} },
                                    %expect_flags,
                                    resched => 1,
                                },
                            ],
                    },
                'Shipment has Failed'   => {
                        create  => [
                                $sched_args->{scheduled1},
                                $sched_args->{failed1},
                            ],
                        expected_elems  => 1,
                        expected=> [
                                {
                                    %{ $sched_args->{failed1} },
                                    %expect_flags,
                                    failed  => 1,
                                },
                            ],
                    },
                'Scheduled, Re-Schedule, Scheduled, Success'   => {
                        create  => [
                                $sched_args->{scheduled1},
                                $sched_args->{rescheduled1},
                                $sched_args->{scheduled2},
                                $sched_args->{success2},
                            ],
                        expected_elems  => 2,
                        expected=> [
                                {
                                    %{ $sched_args->{success2} },
                                    %expect_flags,
                                    sig_date_cmp    => $date1,
                                    success         => 1,
                                },
                                {
                                    %{ $sched_args->{scheduled1} },
                                    %expect_flags,
                                    resched => 1,
                                },
                            ],
                    },
                'Scheduled, Re-Schedule, Scheduled, Failed, Re-Schedule, Scheduled, Success'   => {
                        create  => [
                                $sched_args->{scheduled1},
                                $sched_args->{rescheduled1},
                                $sched_args->{scheduled2},
                                $sched_args->{failed2},
                                $sched_args->{rescheduled2},
                                $sched_args->{scheduled3},
                                $sched_args->{success3},
                            ],
                        expected_elems  => 3,
                        expected=> [
                                {
                                    %{ $sched_args->{success3} },
                                    %expect_flags,
                                    sig_date_cmp    => $date1,
                                    success         => 1,
                                },
                                {
                                    %{ $sched_args->{failed2} },
                                    %expect_flags,
                                    failed  => 1,
                                },
                                {
                                    %{ $sched_args->{scheduled1} },
                                    %expect_flags,
                                    resched => 1,
                                },
                            ],
                    },
                'Scheduled, Failed, Re-Schedule, Scheduled, Re-Schedule, Scheduled, Success'    => {
                        create  => [
                                $sched_args->{scheduled1},
                                $sched_args->{failed1},
                                $sched_args->{rescheduled1},
                                $sched_args->{scheduled2},
                                $sched_args->{rescheduled2},
                                $sched_args->{scheduled3},
                                $sched_args->{success3},
                            ],
                        expected_elems  => 3,
                        expected=> [
                                {
                                    %{ $sched_args->{success3} },
                                    %expect_flags,
                                    sig_date_cmp    => $date1,
                                    success         => 1,
                                },
                                {
                                    %{ $sched_args->{scheduled2} },
                                    %expect_flags,
                                    resched => 1,
                                },
                                {
                                    %{ $sched_args->{failed1} },
                                    %expect_flags,
                                    failed  => 1,
                                },
                            ],
                    },
                'SEQUENCE TEST: Re-Scheduled, Scheduled' => {
                        create  => [
                                $sched_args->{rescheduled1},
                                $sched_args->{scheduled1},
                            ],
                        expected_elems  => 2,
                        expected=> [
                                {
                                    %{ $sched_args->{rescheduled1} },
                                    %expect_flags,
                                    task_window => 'TBC',
                                },
                                {
                                    %{ $sched_args->{scheduled1} },
                                    %expect_flags,
                                    resched => 1,
                                },
                            ],
                    },
            );

        note "test for 'Deliveries'";
        _run_the_tests( $shipment, \%tests );


        # this bit tests that the correct record id appears
        # in the output array of routing shedule hashes
        my @id_recs;
        foreach my $args (
                            $sched_args->{scheduled1},
                            $sched_args->{rescheduled1},
                            $sched_args->{scheduled2},
                            $sched_args->{failed2},
                            $sched_args->{rescheduled2},
                            $sched_args->{scheduled3},
                            $sched_args->{success3},
                        ) {
            push @id_recs, _create_rout_sched( $shipment, $args );
        }
        my %id_test = (
                'ID Test: Scheduled, Re-Schedule, Scheduled, Failed, Re-Schedule, Scheduled, Success'   => {
                        no_create       => 1,
                        expected_elems  => 3,
                        expected=> [
                                {
                                    %{ $sched_args->{success3} },
                                    %expect_flags,
                                    sig_date_cmp    => $date1,
                                    success         => 1,
                                    id              => $id_recs[6]->id,
                                },
                                {
                                    %{ $sched_args->{failed2} },
                                    %expect_flags,
                                    failed  => 1,
                                    id      => $id_recs[3]->id,
                                },
                                {
                                    %{ $sched_args->{scheduled1} },
                                    %expect_flags,
                                    resched => 1,
                                    id      => $id_recs[0]->id,
                                },
                            ],
                    },
            );
        _run_the_tests( $shipment, \%id_test );
        _delete_rout_sched( @id_recs );

        note "test for 'Collections'";
        # change the records and tests to be for Collections
        _convert_tests_for_collections( \%tests, $sched_args );
        _convert_tests_for_collections( \%id_test );
        _run_the_tests( $return, \%tests );

        # ID Test for Collections
        @id_recs    = ();
        foreach my $args (
                            $sched_args->{scheduled1},
                            $sched_args->{rescheduled1},
                            $sched_args->{scheduled2},
                            $sched_args->{failed2},
                            $sched_args->{rescheduled2},
                            $sched_args->{scheduled3},
                            $sched_args->{success3},
                        ) {
            push @id_recs, _create_rout_sched( $return, $args );
        }
        # change the expected Id's to the ones created for the Return
        my $test    = $id_test{'ID Test: Scheduled, Re-Schedule, Scheduled, Failed, Re-Schedule, Scheduled, Success'}->{expected};
        $test->[0]{id}  = $id_recs[6]->id;
        $test->[1]{id}  = $id_recs[3]->id;
        $test->[2]{id}  = $id_recs[0]->id;
        _run_the_tests( $return, \%id_test );
        _delete_rout_sched( @id_recs );

        # this tests that when a duplicate Record for the same Status & Task Window as
        # a record that has already been 'notified' that the notified flag is set to TRUE
        # for that record too and any subsequent duplicates
        note "test 'notified' flag is TRUE for Duplicate: 'Status, Task Window Date & Task Window Schedule' records";

        # set-up what will be used for all records in the test to make sure
        # the Task Window and Task Window Date are the same, unless overwritten
        my $task_window_date    = $date1->clone->set( hour => 0, minute => 0, second => 0 );
        my $different_date      = $task_window_date->clone->add( days => 1 );   # used in tests wanting same time different date
        my $task_window         = '13:30 to 16:00';
        my $exp_task_window     = '1:30pm-4pm';         # the foramatted Task Window that is returned

        my @dupe_test   = (
                {
                    label => 'scheduled1',
                    expected => [ { rec_key => 'scheduled1', notified => 0 } ],
                },
                {
                    label => 'rescheduled1',
                    expected => [
                            { rec_key => 'rescheduled1' },
                            { rec_key => 'scheduled1', notified => 0 },
                        ],
                },
                {
                    label => 'scheduled2',
                    expected => [
                            { rec_key => 'scheduled2', notified => 0 },
                            { rec_key => 'scheduled1', notified => 0 },
                        ],
                },
                {
                    label => 'failed2',
                    overwrite => {
                            notified => 1,
                        },
                    expected => [
                            { rec_key => 'failed2', notified => 1 },
                            { rec_key => 'scheduled1', notified => 0 },
                        ],
                },
                {
                    label => 'rescheduled2',
                    expected => [
                            { rec_key => 'rescheduled2' },
                            { rec_key => 'failed2', notified => 1 },
                            { rec_key => 'scheduled1', notified => 0 },
                        ],
                },
                {
                    label => 'scheduled3',
                    overwrite => {
                            notified => 1,
                        },
                    expected => [
                            { rec_key => 'scheduled3', notified => 1 },
                            { rec_key => 'failed2', notified => 1 },
                            { rec_key => 'scheduled1', notified => 0 },
                        ],
                },
                {   # this will test that when the 'Task Window' is the same but the 'Date'
                    # is different it is NOT considered a Duplicate of the previous 'scheduled3'
                    description => 'scheduled3 same time different date',
                    label => 'scheduled3',
                    overwrite => {
                            task_window_date    => $different_date,
                        },
                    expected => [
                            { rec_key => 'scheduled3', notified => 0, task_window_date => $different_date },
                            { rec_key => 'failed2', notified => 1 },
                            { rec_key => 'scheduled1', notified => 0 },
                        ],
                },
                {   # back to using the Duplicate one
                    description => 'scheduled3 duplicate of previous scheduled3',
                    label => 'scheduled3',
                    expected => [
                            { rec_key => 'scheduled3', notified => 1 },
                            { rec_key => 'failed2', notified => 1 },
                            { rec_key => 'scheduled1', notified => 0 },
                        ],
                },
                {   # this will test that when the 'Task Window' is the same but the 'Date'
                    # is different it is NOT considered a Duplicate of 'failed2'
                    description => 'failed3 same time different date',
                    label => 'failed3',
                    overwrite => {
                            task_window_date    => $different_date,
                        },
                    expected => [
                            { rec_key => 'failed3', notified => 0, task_window_date => $different_date },
                            { rec_key => 'failed2', notified => 1 },
                            { rec_key => 'scheduled1', notified => 0 },
                        ],
                },
                {   # back to using Duplicates and now it should be 'notified'
                    description => 'failed3 duplicate of failed2',
                    label => 'failed3',
                    expected => [
                            { rec_key => 'failed3', notified => 1 },
                            { rec_key => 'failed3', notified => 0, task_window_date => $different_date },
                            { rec_key => 'failed2', notified => 1 },
                            { rec_key => 'scheduled1', notified => 0 },
                        ],
                },
                {
                    label => 'scheduled4',
                    expected => [
                            { rec_key => 'scheduled4', notified => 1 },
                            { rec_key => 'failed3', notified => 1 },
                            { rec_key => 'failed3', notified => 0, task_window_date => $different_date },
                            { rec_key => 'failed2', notified => 1 },
                            { rec_key => 'scheduled1', notified => 0 },
                        ],
                },
                {
                    label => 'success4',
                    overwrite => {
                            notified => 1,
                        },
                    expected => [
                            { rec_key => 'success4', notified => 1 },
                            { rec_key => 'failed3', notified => 1 },
                            { rec_key => 'failed3', notified => 0, task_window_date => $different_date },
                            { rec_key => 'failed2', notified => 1 },
                            { rec_key => 'scheduled1', notified => 0 },
                        ],
                },
                {
                    label => 'success4',
                    expected => [
                            { rec_key => 'success4', notified => 1 },
                            { rec_key => 'success4', notified => 1 },
                            { rec_key => 'failed3', notified => 1 },
                            { rec_key => 'failed3', notified => 0, task_window_date => $different_date },
                            { rec_key => 'failed2', notified => 1 },
                            { rec_key => 'scheduled1', notified => 0 },
                        ],
                },
                {
                    label => 'scheduled5',
                    expected => [
                            { rec_key => 'scheduled5', notified => 1 },
                            { rec_key => 'success4', notified => 1 },
                            { rec_key => 'success4', notified => 1 },
                            { rec_key => 'failed3', notified => 1 },
                            { rec_key => 'failed3', notified => 0, task_window_date => $different_date },
                            { rec_key => 'failed2', notified => 1 },
                            { rec_key => 'scheduled1', notified => 0 },
                        ],
                },
                {
                    label => 'success5',
                    expected => [
                            { rec_key => 'success5', notified => 1 },
                            { rec_key => 'success4', notified => 1 },
                            { rec_key => 'success4', notified => 1 },
                            { rec_key => 'failed3', notified => 1 },
                            { rec_key => 'failed3', notified => 0, task_window_date => $different_date },
                            { rec_key => 'failed2', notified => 1 },
                            { rec_key => 'scheduled1', notified => 0 },
                        ],
                },
                {   # this will test that when the 'Task Window' is the same but the 'Date'
                    # is different it is NOT considered a Duplicate of previous 'success5'
                    description => 'succcess5 same time different date',
                    label => 'success5',
                    overwrite => {
                            task_window_date => $different_date,
                        },
                    expected => [
                            { rec_key => 'success5', notified => 0, task_window_date => $different_date },
                            { rec_key => 'success5', notified => 1 },
                            { rec_key => 'success4', notified => 1 },
                            { rec_key => 'success4', notified => 1 },
                            { rec_key => 'failed3', notified => 1 },
                            { rec_key => 'failed3', notified => 0, task_window_date => $different_date },
                            { rec_key => 'failed2', notified => 1 },
                            { rec_key => 'scheduled1', notified => 0 },
                        ],
                },
            );

        my @compare_keys        = ( qw(
                    routing_schedule_status_id
                    task_window
                    task_window_date
                    notified
                ) );

        foreach my $base_rec ( $shipment, $return ) {
            my @recs_to_delete;

            my $class   = ref( $base_rec );
            $class      =~ s/.*::Public/Public/;
            $sched_args = _build_list_of_schedules( $date1, { delivery => ( $class =~ /::Shipment$/ ? 1 : 0 ) } );

            foreach my $test ( @dupe_test ) {
                my $label   = $test->{label};
                note "$class, Schedule Type: " . ( $test->{description} || $label );

                # make sure every record is for the same Task Window
                my $args    = {
                        %{ $sched_args->{ $label } },
                        task_window_date    => $task_window_date,
                        task_window         => $task_window,
                        notified            => 0,
                        ( exists( $test->{overwrite} ) ? %{ $test->{overwrite} } : () ),
                    };
                push @recs_to_delete, _create_rout_sched( $base_rec, $args );

                # get the list and what to expect
                $list   = $base_rec->routing_schedules->list_schedules;
                my $expect_list = $test->{expected};

                # only compare specific keys for the lists
                my @got;
                foreach my $row ( @{ $list } ) {
                    my %hash    = map { $_ => $row->{ $_ } } @compare_keys;
                    push @got, \%hash;
                }
                my @expected;
                foreach my $exp ( @{ $expect_list } ) {
                    my $rec_key = $exp->{rec_key};
                    my %row     = ( %{ $sched_args->{ $rec_key } }, %{ $exp } );
                    delete $row{rec_key};   # don't need this for the comparison
                    my %hash    = map { $_ => $row{ $_ } } @compare_keys;
                    $hash{task_window_date} = $exp->{task_window_date} // $task_window_date;
                    $hash{task_window}      = $exp->{task_window} // (
                                                        $hash{routing_schedule_status_id} == $ROUTING_SCHEDULE_STATUS__RE_DASH_SCHEDULED
                                                        ? 'TBC'
                                                        : $exp_task_window
                                                    );
                    push @expected, \%hash;
                }
                is_deeply( \@got, \@expected, "List returned as Expected" );
            }
            _delete_rout_sched( @recs_to_delete );
        }

        # test when a Schedule record doesn't have a Task Window Date
        note "check when Task Window Date is 'null'";
        my @recs_to_delete;
        $sched_args = _build_list_of_schedules( $date1, { delivery => 1 } );
        push @recs_to_delete, _create_rout_sched( $shipment, { %{ $sched_args->{scheduled1} }, task_window_date => undef } );
        lives_ok { $shipment->routing_schedules->list_schedules() } "Shipment: 'list_schedules' ok with a 'null' Task Window Date";
        $sched_args = _build_list_of_schedules( $date1, { delivery => 0 } );
        push @recs_to_delete, _create_rout_sched( $return, { %{ $sched_args->{scheduled1} }, task_window_date => undef } );
        lives_ok { $return->routing_schedules->list_schedules() } "Return: 'list_schedules' ok with a 'null' Task Window Date";
        _delete_rout_sched( @recs_to_delete );
    };

    return;
}


# this will test the various scenarios as to when to send a
# notification to a Customer about a planned Delivery/Collection
# or it's Success or Failure
sub _test_send_notifications {
    ## no critic(ProhibitDeepNests)
    my ( $schema, $domain, $amq, $oktodo )  = @_;

    my $msg_factory = $domain->msg_factory;

    SKIP: {
        skip "_test_send_notifications", 1              if ( !$oktodo );

        note "in '_test_send_notifications'";

        $schema->txn_do( sub {
            # create an order
            my ( $channel, $pids )  = Test::XTracker::Data->grab_products( { how_many => 2, channel => Test::XTracker::Data->channel_for_nap } );
            my ( $order, undef )    = Test::XTracker::Data->create_db_order( { pids => $pids } );
            my $customer            = $order->customer;
            my $shipment            = $order->get_standard_class_shipment;
            my $ship_items          = $shipment->shipment_items;
            my $return              = _create_return( $domain, $shipment );

            my $ship_class_rs       = $schema->resultset('Public::ShipmentClass');
            my $shipitem_status_rs  = $schema->resultset('Public::ShipmentItemStatus');

            # set-up a TT parser
            my $template            = XTracker::XTemplate->template( {
                        PRE_CHOMP  => 0,
                        POST_CHOMP => 1,
                        STRICT => 0,
                    } );

            note "Order Nr/Id:   ".$order->order_nr."/".$order->id;
            note "Shipment Id:   ".$shipment->id;
            note "Return RMA/Id: ".$return->rma_number."/".$return->id;

            # get the AMQ Queue for the SMS Proxy
            my $sms_proxy_queue = config_var('Producer::Correspondence::SMS','destination');

            # change the Shipment Email Address & Mobile Number
            $shipment->update( { email => $shipment->id . '.' . $$ . '@test.com', mobile_telephone => '+44723456789'  } );

            # get some branding for the Sales Channel
            my $plain_name  = $channel->branding( $BRANDING__PLAIN_NAME );
            my $prem_name   = $channel->branding( $BRANDING__PREM_NAME );
            my $email_signoff= $channel->branding( $BRANDING__EMAIL_SIGNOFF );
            my $sms_sender_id= $channel->branding( $BRANDING__SMS_SENDER_ID );
            my $salutation  = $shipment->branded_salutation;
            my $order_nr    = $order->order_nr;

            # make up the bare bones of an Email & SMS to check that something
            # was produced when the notifications are parsed in later tests
            my $email_pattern   = qr/Dear $salutation,\r?\n.*\w+.*\r?\n$email_signoff,\r?\n$prem_name\r?\n/s;
            my $sms_pattern     = qr/\b($prem_name|$order_nr)\b/;

            # get a list of Routing Schedules to create
            my $date        = DateTime->new( time_zone => config_var('DistributionCentre', 'timezone'), day => 20, month => 1, year => 2011, hour => 14, minute => 34, second => 56 );
            my $delv_scheds = _build_list_of_schedules( $date, { delivery => 1, default_notified_columns => 1 } );
            my $coll_scheds = _build_list_of_schedules( $date, { collection => 1, default_notified_columns => 1 } );

            note "Testing Helper Methods";

            # checking: _rtschd_is_return, _rtschd_is_shipment, _rtschd_get_shipment
            foreach my $rec ( $shipment, $return ) {
                my $class   = ref( $rec );
                $class      =~ s/.*::Public/Public/;
                my ( $is_return, $is_shipment ) = ( $class =~ /::Return$/ ? ( 1, 0 ) : ( 0, 1 ) );

                cmp_ok( $rec->_rtschd_is_return, '==', $is_return, "$class: '_rtschd_is_return' as expected: $is_return" );
                cmp_ok( $rec->_rtschd_is_shipment, '==', $is_shipment, "$class: '_rtschd_is_shipment' as expected: $is_shipment" );
                isa_ok( $rec->_rtschd_get_shipment, 'XTracker::Schema::Result::Public::Shipment', "$class: '_rtschd_get_shipment,' returned as expected" );

                is( $rec->_rtschd_type_name( { routing_schedule_type_id => $ROUTING_SCHEDULE_TYPE__DELIVERY } ), 'Delivery',
                                                                        "$class: '_rtschd_type_name' method returns correct name for 'Delivery' type" );
                is( $rec->_rtschd_type_name( { routing_schedule_type_id => $ROUTING_SCHEDULE_TYPE__COLLECTION } ), 'Collection',
                                                                        "$class: '_rtschd_type_name' method returns correct name for 'Collection' type" );
            }

            # checking: '_rtschd_can_send_notification' and the various states that it will return TRUE or FALSE

            my @notok_classes   = ( $SHIPMENT_CLASS__SAMPLE, $SHIPMENT_CLASS__PRESS, $SHIPMENT_CLASS__TRANSFER_SHIPMENT, $SHIPMENT_CLASS__RTV_SHIPMENT );
            my @ok_classes      = $schema->resultset('Public::ShipmentClass')->search( { id => { 'NOT IN' => \@notok_classes } } )->all;
            my @notok_statuses  = ( $SHIPMENT_ITEM_STATUS__NEW, $SHIPMENT_ITEM_STATUS__SELECTED,
                                    $SHIPMENT_ITEM_STATUS__PICKED, $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION );
            my @ok_statuses     = ( $SHIPMENT_ITEM_STATUS__PACKED, $SHIPMENT_ITEM_STATUS__DISPATCHED );

            # set-up record statuses etc.
            $customer->update( { category_id => $CUSTOMER_CATEGORY__NONE } );
            $shipment->update( { shipment_status_id => $SHIPMENT_STATUS__PROCESSING } );
            $ship_items->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PACKED } );

            # check Shipment should be connected to an Order - not a Sample or Stock Transfer
            $shipment->link_orders__shipment->delete;
            _discard_changes( $shipment, $return );
            cmp_ok( $shipment->_rtschd_can_send_notification, '==', 0,
                                                    "Shipment: '_rtschd_can_send_notification' fails when Shipment is not Connected to an Order" );
            cmp_ok( $return->_rtschd_can_send_notification, '==', 0,
                                                    "Return: '_rtschd_can_send_notification' fails when Shipment is not Connected to an Order" );
            $shipment->create_related( 'link_orders__shipment', { orders_id => $order->id } );
            _discard_changes( $shipment, $return );
            cmp_ok( $shipment->_rtschd_can_send_notification, '==', 1,
                                                    "Shipment: '_rtschd_can_send_notification' succeeds when Shipment IS Connected to an Order" );
            cmp_ok( $return->_rtschd_can_send_notification, '==', 1,
                                                    "Return: '_rtschd_can_send_notification' succeeds when Shipment IS Connected to an Order" );

            # check Shipment Item Statuses - test only suitable for Shipment
            foreach my $status_id ( @notok_statuses ) {
                my $status  = $shipitem_status_rs->find( $status_id );
                $ship_items->update( { shipment_item_status_id => $status_id } );
                cmp_ok( $shipment->discard_changes->_rtschd_can_send_notification, '==', 0, "Public::Shipment: '_rtschd_can_send_notification' fails when Shipment Item Status is: ".$status->status );
            }
            cmp_ok( $return->discard_changes->_rtschd_can_send_notification, '==', 1, "Public::Return: '_rtschd_can_send_notification' succeeds when Shipment Items are not 'Packed' but called by a 'Return'" );
            foreach my $status_id ( @ok_statuses ) {
                my $status  = $shipitem_status_rs->find( $status_id );
                $ship_items->update( { shipment_item_status_id => $status_id } );
                cmp_ok( $shipment->discard_changes->_rtschd_can_send_notification, '==', 1, "Public::Shipment: '_rtschd_can_send_notification' succeeds when Shipment Item Status is: ".$status->status );
            }

            $shipment->update( { shipment_status_id => $SHIPMENT_STATUS__CANCELLED } );
            $return->update( { return_status_id => $RETURN_STATUS__CANCELLED } );
            cmp_ok( $shipment->_rtschd_can_send_notification, '==', 0, "Public::Shipment: '_rtschd_can_send_notification' fails when Shipment Status is 'Cancelled'" );
            cmp_ok( $return->_rtschd_can_send_notification, '==', 0, "Public::Return: '_rtschd_can_send_notification' fails when Return Status is 'Cancelled'" );
            $shipment->update( { shipment_status_id => $SHIPMENT_STATUS__PROCESSING } );
            $return->update( { return_status_id => $RETURN_STATUS__AWAITING_RETURN } );

            $customer->update( { category_id => $CUSTOMER_CATEGORY__STAFF } );
            cmp_ok( $shipment->discard_changes->_rtschd_can_send_notification, '==', 0,
                                                        "Public::Shipment: '_rtschd_can_send_notification' fails when Customer Category is 'Staff'" );
            cmp_ok( $return->discard_changes->_rtschd_can_send_notification, '==', 0,
                                                        "Public::Return: '_rtschd_can_send_notification' fails when Customer Category is 'Staff'" );

            # put the records back to working again
            $customer->update( { category_id => $CUSTOMER_CATEGORY__NONE } );
            $shipment->update( { shipment_class_id => $SHIPMENT_CLASS__STANDARD } );
            $ship_items->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PACKED } );

            # make sure everything is up to date
            _discard_changes( $shipment, $return );

            # just check everything is fine with '_rtschd_can_send_notification' when all the Statuses etc. are ok
            cmp_ok( $shipment->_rtschd_can_send_notification, '==', 1, "Public::Shipment: '_rtschd_can_send_notification' is succeeds when records are all ok" );
            cmp_ok( $return->_rtschd_can_send_notification, '==', 1, "Public::Return: '_rtschd_can_send_notification' is succeeds when records are all ok" );

            # when there are NO Schedules
            cmp_ok( $shipment->send_routing_schedule_notification, '==', 0, "Public::Shipment: With no Routing Schedules method returns 0 as nothing to do" );
            cmp_ok( $return->send_routing_schedule_notification, '==', 0, "Public::Return: With no Routing Schedules method returns 0 as nothing to do" );

            # create a Schedule and then set the Customer to be Staff to check ZERO is returned
            my @recs;
            $customer->update( { category_id => $CUSTOMER_CATEGORY__STAFF } );
            push @recs, _create_rout_sched( $shipment, $delv_scheds->{scheduled1} );
            push @recs, _create_rout_sched( $return, $delv_scheds->{scheduled1} );
            _discard_changes( $shipment, $return );
            cmp_ok( $shipment->send_routing_schedule_notification, '==', 0,
                                                "Public::Shipment: With Routing Schedules but as a Staff Customer method returns 0 as nothing to do" );
            cmp_ok( $return->send_routing_schedule_notification, '==', 0,
                                                "Public::Return: With Routing Schedules but as a Staff Customer method returns 0 as nothing to do" );
            _delete_rout_sched( @recs );
            $customer->update( { category_id => $CUSTOMER_CATEGORY__NONE } );           # make sure the Customer is ok again
            _discard_changes( $shipment, $return, $order );


            note "Testing '_rtschd_decide_what_to_send' method";
            # make sure the settings are what we want
            Test::XTracker::Data->remove_config_group( 'Premier_Delivery', $channel );
            my $prem_conf_grp   = Test::XTracker::Data->create_config_group( 'Premier_Delivery', {
                                                                    channel => $channel,
                                                                    settings => [
                                                                            { setting => 'Email Alert', value => 'On' },
                                                                            { setting => 'SMS Alert', value => 'On' },
                                                                            { setting => 'send_hold_alert_threshold', value => '3' },
                                                                        ],
                                                                } );
            my $prem_conf_email = $prem_conf_grp->config_group_settings->search( { setting => 'Email Alert' } )->first;
            my $prem_conf_sms   = $prem_conf_grp->config_group_settings->search( { setting => 'SMS Alert' } )->first;

            # all of the Correspondence Methods
            my $corr_subject= $channel->get_correspondence_subject( 'Premier Delivery' );
            my %methods     = map { $_->method => $_ }
                                $schema->resultset('Public::CorrespondenceMethod')->all;
            # make sure they are all enabled
            $_->update( { enabled => 1 } )      foreach ( values %methods );

            # make sure it's ok to send ALL Alerts to that Order
            $corr_subject->update( { enabled => 1 } );
            $order->change_csm_preference( $corr_subject->id, {
                                                                map { $_->id => 1 }
                                                                    values %methods
                                                            } );

            my %templates   = (
                    'SMS Scheduled' => $CORRESPONDENCE_TEMPLATES__PREMIER__DASH__ORDER_FSLASH_EXCHANGE_DELIVERY_FSLASH_COLLECTION_SMS__3,
                    'EMAIL Scheduled' => $CORRESPONDENCE_TEMPLATES__PREMIER__DASH__ORDER_FSLASH_EXCHANGE_DELIVERY_FSLASH_COLLECTION_EMAIL_DASH_PLAIN__3,
                    'SMS Failed Attempts' => $CORRESPONDENCE_TEMPLATES__PREMIER__DASH__DELIVERY_FAILED_1ST_AND_2ND_ATTEMPT_SMS__3,
                    'EMAIL Failed Attempts' => $CORRESPONDENCE_TEMPLATES__PREMIER__DASH__DELIVERY_FAILED_1ST_AND_2ND_ATTEMPT_EMAIL_DASH_PLAIN__3,
                    'SMS Hold Delivery' => $CORRESPONDENCE_TEMPLATES__PREMIER__DASH__HOLD_ORDER_DELIVERY_SMS__3,
                    'EMAIL Hold Delivery' => $CORRESPONDENCE_TEMPLATES__PREMIER__DASH__HOLD_ORDER_DELIVERY_EMAIL_DASH_PLAIN__3,
                    'SMS Delivery Success' => $CORRESPONDENCE_TEMPLATES__PREMIER__DASH__DELIVERY_SUCCESS_SMS__3,
                    'EMAIL Delivery Success' => $CORRESPONDENCE_TEMPLATES__PREMIER__DASH__DELIVERY_SUCCESS_EMAIL_DASH_PLAIN__3,
                    'SMS Collection Failed' => $CORRESPONDENCE_TEMPLATES__PREMIER__DASH__COLLECTION_FAILED_SMS__3,
                    'EMAIL Collection Failed' => $CORRESPONDENCE_TEMPLATES__PREMIER__DASH__COLLECTION_FAILED_EMAIL_DASH_PLAIN__3,
                    'SMS Collection Success' => $CORRESPONDENCE_TEMPLATES__PREMIER__DASH__COLLECTION_SUCCESS_SMS__3,
                    'EMAIL Collection Success' => $CORRESPONDENCE_TEMPLATES__PREMIER__DASH__COLLECTION_SUCCESS_EMAIL_DASH_PLAIN__3,
                );

            my %tests   = (
                    'Delivery'  => {
                        base_rec=> $shipment,
                        labels  => [
                                'Scheduled',
                                'Re-Scheduled',
                                'Scheduled',
                                'Scheduled - Duplicate, should not be sent',
                                'Failed',
                                'Scheduled',
                                'Failed',
                                'Scheduled',
                                'Failed',
                                'Failed - Duplicate, should not be sent',
                                'Scheduled',
                                'Success',
                                'Success - Duplicate, should not be sent',
                            ],
                        create  =>  [
                                # clone each hash so it can be changed and re-used
                                map { { %{ $delv_scheds->{ $_ } } } } qw(
                                                                scheduled1
                                                                rescheduled1
                                                                scheduled2
                                                                scheduled2
                                                                failed2
                                                                scheduled3
                                                                failed3
                                                                scheduled4
                                                                failed4
                                                                failed4
                                                                scheduled5
                                                                success5
                                                                success5
                                                            )
                            ],
                        expected=> [
                                { 'SMS' => $templates{'SMS Scheduled'}, 'EMAIL-PLAIN' => $templates{'EMAIL Scheduled'} },
                                undef,
                                { 'SMS' => $templates{'SMS Scheduled'}, 'EMAIL-PLAIN' => $templates{'EMAIL Scheduled'} },
                                undef,
                                { 'SMS' => $templates{'SMS Failed Attempts'}, 'EMAIL-PLAIN' => $templates{'EMAIL Failed Attempts'} },
                                { 'SMS' => $templates{'SMS Scheduled'}, 'EMAIL-PLAIN' => $templates{'EMAIL Scheduled'} },
                                { 'SMS' => $templates{'SMS Failed Attempts'}, 'EMAIL-PLAIN' => $templates{'EMAIL Failed Attempts'} },
                                { 'SMS' => $templates{'SMS Scheduled'}, 'EMAIL-PLAIN' => $templates{'EMAIL Scheduled'} },
                                { 'SMS' => $templates{'SMS Hold Delivery'}, 'EMAIL-PLAIN' => $templates{'EMAIL Hold Delivery'} },
                                undef,
                                { 'SMS' => $templates{'SMS Scheduled'}, 'EMAIL-PLAIN' => $templates{'EMAIL Scheduled'} },
                                { 'SMS' => $templates{'SMS Delivery Success'}, 'EMAIL-PLAIN' => $templates{'EMAIL Delivery Success'} },
                            ],
                        email_subjects=> [
                                "Your $plain_name order is on its way",
                                undef,
                                "Your $plain_name order is on its way",
                                undef,
                                "Your $plain_name delivery",
                                "Your $plain_name order is on its way",
                                "Your $plain_name delivery",
                                "Your $plain_name order is on its way",
                                "Your $plain_name delivery",
                                undef,
                                "Your $plain_name order is on its way",
                                "Your $plain_name delivery",
                            ],
                    },
                'Collection'    => {
                        base_rec=> $return,
                        labels  => [
                                'Scheduled',
                                'Re-Scheduled',
                                'Scheduled',
                                'Scheduled - Duplicate, should not be sent',
                                'Failed',
                                'Scheduled',
                                'Failed',
                                'Failed - Duplicate, should not be sent',
                                'Scheduled',
                                'Success',
                                'Success, Duplicate, should not be sent',
                            ],
                        create  =>  [
                                # clone each hash so it can be changed and re-used
                                map { { %{ $coll_scheds->{ $_ } } } } qw(
                                                                scheduled1
                                                                rescheduled1
                                                                scheduled2
                                                                scheduled2
                                                                failed2
                                                                scheduled3
                                                                failed3
                                                                failed3
                                                                scheduled4
                                                                success4
                                                                success4
                                                            )
                            ],
                        expected=> [
                                { 'SMS' => $templates{'SMS Scheduled'}, 'EMAIL-PLAIN' => $templates{'EMAIL Scheduled'} },
                                undef,
                                { 'SMS' => $templates{'SMS Scheduled'}, 'EMAIL-PLAIN' => $templates{'EMAIL Scheduled'} },
                                undef,
                                { 'SMS' => $templates{'SMS Collection Failed'}, 'EMAIL-PLAIN' => $templates{'EMAIL Collection Failed'} },
                                { 'SMS' => $templates{'SMS Scheduled'}, 'EMAIL-PLAIN' => $templates{'EMAIL Scheduled'} },
                                { 'SMS' => $templates{'SMS Collection Failed'}, 'EMAIL-PLAIN' => $templates{'EMAIL Collection Failed'} },
                                undef,
                                { 'SMS' => $templates{'SMS Scheduled'}, 'EMAIL-PLAIN' => $templates{'EMAIL Scheduled'} },
                                { 'SMS' => $templates{'SMS Collection Success'}, 'EMAIL-PLAIN' => $templates{'EMAIL Collection Success'} },
                                undef,
                            ],
                        email_subjects=> [
                                "Your $plain_name collection",
                                undef,
                                "Your $plain_name collection",
                                undef,
                                "Your $plain_name collection",
                                "Your $plain_name collection",
                                "Your $plain_name collection",
                                undef,
                                "Your $plain_name collection",
                                "Your $plain_name collection",
                                undef,
                            ],
                    },
                );

            @recs   = ();
            foreach my $group ( keys %tests ) {
                note "TESTING: $group";
                my $group   = $tests{ $group };
                my $base_rec= $group->{base_rec};
                my $fail_count  = 0;

                foreach my $idx ( 0..$#{ $group->{labels} } ) {
                    note "action - " . $group->{labels}[ $idx ];

                    # create a schedule record
                    my $rec     = _create_rout_sched( $base_rec, $group->{create}[ $idx ] );
                    push @recs, $rec;

                    # get a list of schedules and then call '_rtschd_decide_what_to_send' method with it
                    my $list    = $base_rec->discard_changes->routing_schedules->list_schedules;
                    my $retval  = $base_rec->_rtschd_decide_what_to_send();

                    # test what we got back was correct
                    my $expected    = $group->{expected}[ $idx ];

                    my $sched_row   = { %{ $list->[0] } };      # clone the first row from the list
                    if ( $group->{labels}[ $idx ] eq 'Failed' ) {
                        # set-up number of expected failures for is_deeply test later on
                        $fail_count++;
                        $sched_row->{number_of_failures}    = $fail_count;
                    }

                    if ( $expected ) {
                        isa_ok( $retval, 'HASH', "got back as expected" );
                        foreach my $alert_type ( sort keys %{ $expected } ) {
                            ok( exists $retval->{ $alert_type }, "found alert '$alert_type' in HASH" );
                            my $alert   = $retval->{ $alert_type };
                            cmp_ok( $alert->{template}->id, '==', $expected->{ $alert_type }, "alert template id is as expected" );
                            cmp_ok( $alert->{schedule_record}->id, '==', $rec->id, "schedule record's id is as expected" );
                            cmp_ok( $alert->{corr_subject}->id, '==', $corr_subject->id, "correspondence subject used as expected" );
                            isa_ok( $alert->{csm_rec}, 'XTracker::Schema::Result::Public::CorrespondenceSubjectMethod', "'csm_rec' is present" );
                            is( $alert->{alert_method}->method, ( $alert_type eq 'SMS' ? 'SMS' : 'Email' ), "alert method as expected" );
                            is( $alert->{email_subject}, $group->{email_subjects}[ $idx ], "Email Subject as expected" );
                            is_deeply( $alert->{schedule}, $sched_row, "schedule row is as expected" );

                            # process the TT Template just to make sure it parses
                            my $tt_out  = $base_rec->_rtschd_build_alert_content( $template, $alert );
                            ok( defined $tt_out && $tt_out ne '', "Can Parse TT Template OK" );
                            like( $tt_out, ( $alert_type eq 'SMS' ? $sms_pattern : $email_pattern ), "Parsed TT Template text looks sane" );
                            if ( $ENV{HARNESS_VERBOSE} ) {
                                diag "------------------------------------------------------------------";
                                diag "TT Name  : (".$alert->{template}->id.") ".$alert->{template}->name;
                                diag "Subject  : ".$alert->{email_subject};
                                diag "TT Output: ".$tt_out;
                            }

                            # now clear the content of the Template and re-call method
                            my $saved_content   = $alert->{template}->content;
                            $alert->{template}->update( { content => "" } );
                            my $new = $base_rec->_rtschd_decide_what_to_send();
                            ok( !exists( $new->{ $alert_type } ), "didn't get back an alert for '$alert_type' when Template has NO Content" );
                            $alert->{template}->update( { content => $saved_content } );
                        }

                        # now set the 'notified' flag on the record to TRUE and re-call method
                        $rec->update( { notified => 1 } );
                        $retval = $base_rec->_rtschd_decide_what_to_send();
                        ok( !defined $retval, "got back 'undef' when row has already been notified" );
                    }
                    else {
                        ok( !defined $retval, "got back 'undef' as expected" );
                    }
                }
            }
            _delete_rout_sched( @recs );

            note "Testing when a Previous 'Success' Status Exists NO MORE Messages are EVER Sent for any Successive Statuses, using '_rtschd_decide_what_to_send' method";
            # also test '_rtschd_previous_successes' & '_rtschd_number_of_failures' methods
            # making sure they return the correct values based on what Statuses exist

            foreach my $rec ( $shipment, $return ) {
                my $class   = ref( $rec );
                $class      =~ s/.*::Public/Public/;
                my $scheds  = ( $class =~ m/::Shipment/ ? $delv_scheds : $coll_scheds );

                my $list    = $rec->discard_changes->routing_schedules->list_schedules;
                my $count   = $rec->_rtschd_previous_successes( $list );
                ok( defined $count && $count == 0, "$class: '_rtschd_previous_successes' method returns ZERO when NO records created - (got: $count)" );
                $count      = $rec->_rtschd_number_of_failures( $list );
                ok( defined $count && $count == 0, "$class: '_rtschd_number_of_failures' method returns ZERO when NO records created - (got: $count)" );

                my $status_so_far;
                @recs   = ();

                # just create Schedule Records required before testing '_rtschd_decide_what_to_send' method
                foreach my $sched_label ( qw( scheduled1 rescheduled1 scheduled2 success2 ) ) {
                    $status_so_far  .= ( $status_so_far ? ", $sched_label" : $sched_label );
                    push @recs, _create_rout_sched( $rec, $scheds->{ $sched_label } );
                    $list   = $rec->discard_changes->routing_schedules->list_schedules;
                    $count  = $rec->_rtschd_previous_successes( $list );
                    ok( defined $count && $count == 0, "$class: Statuses: '$status_so_far', '_rtschd_previous_successes' method returns ZERO - (got: $count)" );
                    $count  = $rec->_rtschd_number_of_failures( $list );
                    ok( defined $count && $count == 0, "$class: Statuses: '$status_so_far', '_rtschd_number_of_failures' method returns ZERO - (got: $count)" );
                }

                # test successive 'Success' Statuses
                my $sched   =  _create_rout_sched( $rec, $scheds->{success2} );
                $list       = $rec->discard_changes->routing_schedules->list_schedules;
                ok( !$rec->_rtschd_decide_what_to_send(),
                                "$class: '_rtschd_decide_what_to_send' returned 'undef', Successive 'Success' Status doesn't want to send a Message" );
                $count      = $rec->_rtschd_previous_successes( $list );
                ok( defined $count && $count == 1, "$class: '_rtschd_previous_successes' method returns 1: $count" );
                _delete_rout_sched( $sched );       # get rid of the Successive 'Success' Status

                # now test other Successive Messages
                my $expected_fails  = 0;
                my $expected_success= 1;
                foreach my $sched_label ( qw( failed2 rescheduled2 scheduled3 success3 failed3 success3 ) ) {
                    $expected_fails++   if ( $sched_label =~ /failed/ );
                    $status_so_far  .= ", $sched_label";
                    push @recs, _create_rout_sched( $rec, $scheds->{ $sched_label } );
                    $list   = $rec->discard_changes->routing_schedules->list_schedules;
                    ok( !$rec->_rtschd_decide_what_to_send(),
                                "$class: '_rtschd_decide_what_to_send' returned 'undef', Subsequent '$sched_label' Status doesn't want to send a Message" );
                    $count      = $rec->_rtschd_previous_successes( $list );
                    ok( defined $count && $count == $expected_success,
                                    "$class: Statuses: '$status_so_far', '_rtschd_previous_successes' method returns $expected_success - (got: $count)" );
                    $count  = $rec->_rtschd_number_of_failures( $list );
                    ok( defined $count && $count == $expected_fails,
                                    "$class: Statuses: '$status_so_far', '_rtschd_number_of_failures' method returns $expected_fails - (got: $count)" );
                    $expected_success++ if ( $sched_label =~ /success/ );
                }

                _delete_rout_sched( @recs );
            }

            note "Testing '_rtschd_build_tt_data_for_alert' method";
            @recs   = ();
            push @recs, _create_rout_sched( $return, $coll_scheds->{scheduled1} );
            my $alert   = $return->_rtschd_decide_what_to_send()->{'EMAIL-PLAIN'};
            my $tt_data = $return->_rtschd_build_tt_data_for_alert( $alert );
            isa_ok( $tt_data, 'HASH', "method returned as expected" );
            is_deeply( [ sort keys %{ $tt_data } ], [ sort qw(
                                                                template_type order_nr schedule schedule_record is_return is_shipment
                                                                base_obj shipment ship_addr items channel channel_info
                                                            ) ],
                                                "HASH has expected keys in it" );
            is_deeply( [ sort keys %{ $tt_data->{channel_info} } ], [ sort qw( branding salutation email_address company_detail ) ],
                                                "'channel_info' part of the HASH has expected keys" );
            isa_ok( $tt_data->{items}, 'ARRAY', "'items' part of HASH is as expected" );
            is_deeply( [ sort keys %{ $tt_data->{items}[0] } ], [ sort qw( is_voucher item_obj item_info ) ],
                                                "'items' first element has expected keys" );

            note "Testing '_rtschd_build_alert_content' method";
            my $tt_out  = $return->_rtschd_build_alert_content( $template, $alert );
            ok( defined $tt_out && $tt_out ne '', "method returned a defined non-empty string" );
            _delete_rout_sched( @recs );

            note "Testing '_rtschd_send_alert' method";

            # set-up for the re-defined 'send_email' function
            %redef_email_args   = ();
            $redef_email_todie  = 0;

            my $prem_email  = premier_email( $channel->business->config_section );
            my $ship_logs   = $shipment->shipment_email_logs->search( {}, { order_by => 'id DESC' } );
            my $ret_logs    = $return->return_email_logs->search( {}, { order_by => 'id DESC' } );

            @recs   = ();
            push @recs, _create_rout_sched( $shipment, $delv_scheds->{scheduled1} );
            push @recs, _create_rout_sched( $return, $coll_scheds->{scheduled1} );

            # remove any records from 'csm_exclusion_calendar' table for the
            # Correpondence Subject Method so a Method can be used at any time
            $corr_subject->discard_changes
                            ->correspondence_subject_methods
                                ->search_related('csm_exclusion_calendars')
                                    ->delete;

            %tests  = (
                    'Shipment'  => {
                            rec     => $shipment,
                            logs    => $ship_logs,
                            sched_rec => $recs[0],
                            sms_link => 'link_sms_correspondence__shipments',
                        },
                    'Return'    => {
                            rec     => $return,
                            logs    => $ret_logs,
                            sched_rec => $recs[1],
                            sms_link => 'link_sms_correspondence__returns',
                        },
                );

            foreach my $label ( sort keys %tests ) {
                note "For: $label";
                my $test        = $tests{ $label };
                my $base_rec    = $test->{rec};
                my $logs        = $test->{logs};
                my $sched_rec   = $test->{sched_rec};
                my $sms_link    = $test->{sms_link};

                my $alerts  = $base_rec->_rtschd_decide_what_to_send();

                foreach my $alert_type ( sort keys %{ $alerts } ) {
                    my $alert       = $alerts->{ $alert_type };
                    my $alert_conf  = ( $alert_type eq 'SMS' ? $prem_conf_sms : $prem_conf_email );

                    %redef_email_args   = ();
                    $logs->reset->delete;
                    $sched_rec->discard_changes->update( { notified => 0 } );
                    $base_rec->$sms_link->search_related('sms_correspondence')->delete;
                    $base_rec->$sms_link->delete;
                    $amq->clear_destination( $sms_proxy_queue );

                    cmp_ok( $base_rec->_rtschd_send_alert( $alert, "$alert_type message", ( $alert_type eq 'SMS' ? $msg_factory : undef ) ), '==', 1,
                                                                    "method returned TRUE for $alert_type" );
                    cmp_ok( $logs->reset->count(), '==', 1, "correspondence log created" );
                    cmp_ok( $logs->first->correspondence_templates_id, '==', $alert->{template}->id, "template logged is as expected" );
                    cmp_ok( $sched_rec->discard_changes->notified, '==', 1, "schedule record 'notified' column now TRUE" );

                    if ( $alert_type =~ /EMAIL/ ) {
                        # check out what got passed to the 'send_email' function
                        is( $redef_email_args{from}, $prem_email, "'send_email' got passed the expected 'From' Address" );
                        is( $redef_email_args{reply}, $prem_email, "'send_email' got passed the expected 'Reply To' Address" );
                        is( $redef_email_args{to}, $shipment->email, "'send_email' got passed the Shipment Email Address as the 'To' Address" );
                        is( $redef_email_args{subject}, $alert->{email_subject}, "'send_email' got passed the expected 'Subject'" );
                        is( $redef_email_args{message}, "$alert_type message", "'send_email' got passed the expected 'Message'" );

                        # send the Email again this time expecting the 'send_email' to die and the method returns FALSE
                        %redef_email_args   = ();
                        $redef_email_todie  = 1;
                        $logs->reset->delete;
                        $sched_rec->update( { notified => 0 } );
                        cmp_ok( $base_rec->_rtschd_send_alert( $alert, "$alert_type message" ), '==', 0,
                                                                "method returned FALSE for $alert_type when expecting 'send_email' to FAIL" );
                        is( $redef_email_args{subject}, 'TEST DIED', "and it was because 'send_email' DIEd" );
                        cmp_ok( $logs->reset->count(), '==', 0, "correspondence log NOT created" );
                        cmp_ok( $sched_rec->discard_changes->notified, '==', 0, "schedule record 'notified' column still FALSE" );
                        $redef_email_todie  = 0;
                    }
                    else {  # SMS
                        my $sms_rec = $base_rec->$sms_link->search_related('sms_correspondence')->first;
                        isa_ok( $sms_rec, 'XTracker::Schema::Result::Public::SmsCorrespondence', "Found SMS Correspondence Record" );
                        $amq->assert_messages( {
                            destination => $sms_proxy_queue,
                            assert_header => superhashof({
                                type => 'SMSMessage',
                            }),
                            assert_body => {
                                '@type' => 'SMSMessage',
                                id      => 'CSM-' . $sms_rec->id,
                                salesChannel => ignore(),
                                message => {
                                    body        => "$alert_type message",
                                    from        => $sms_sender_id,
                                    phoneNumber => $shipment->mobile_telephone,
                                }
                            },
                        }, "AMQ Message to SMS Proxy Sent" );

                        # send the SMS again but make the Producer Fail so that the method returns FALSE
                        no warnings 'redefine';
                        local *XT::DC::Messaging::Producer::Correspondence::SMS::transform=sub{die}; # this will cause the Producer to fail
                        $base_rec->$sms_link->delete;
                        $sms_rec->delete;
                        $logs->reset->delete;
                        $sched_rec->update( { notified => 0 } );
                        $amq->clear_destination( $sms_proxy_queue );
                        cmp_ok( $base_rec->_rtschd_send_alert( $alert, "$alert_type message", $msg_factory ), '==', 0,
                                                                    "method returned FALSE for $alert_type when expecting the SMS Producer to FAIL" );
                        $amq->assert_messages({
                            destination => $sms_proxy_queue,
                            assert_count => 0,
                        }, "and NO AMQ Messages Sent" );
                        $sms_rec    = $base_rec->$sms_link->search_related('sms_correspondence')->first;
                        cmp_ok( $sms_rec->is_not_sent, '==', 1, "SMS Correspondence Created but Marked as Not Sent" );
                        cmp_ok( $logs->reset->count(), '==', 0, "correspondence log NOT created" );
                        cmp_ok( $sched_rec->discard_changes->notified, '==', 0, "schedule record 'notified' column still FALSE" );
                    }

                    # now turn off sending the alert and try again
                    $alert_conf->update( { value => 'Off' } );
                    $logs->reset->delete;
                    $sched_rec->update( { notified => 0 } );
                    cmp_ok( $base_rec->_rtschd_send_alert( $alert, "$alert_type message", $msg_factory ), '==', 0,
                                                                    "method returned FALSE for $alert_type when Sending for Premier turned OFF" );
                    cmp_ok( $logs->reset->count(), '==', 0, "correspondence log NOT created" );
                    cmp_ok( $sched_rec->discard_changes->notified, '==', 0, "schedule record 'notified' column still FALSE" );
                    $alert_conf->update( { value => 'On' } );      # turn back on again

                    # now make the Customer Opt Out of receiving the
                    # Method of Alert and check that it doesn't get sent
                    my $method  = ( $alert_type eq 'SMS' ? $methods{'SMS'} : $methods{'Email'} );
                    $order->change_csm_preference( $corr_subject->id, { $method->id => 0 } );
                    cmp_ok( $base_rec->_rtschd_send_alert( $alert, "$alert_type message", $msg_factory ), '==', 0,
                                            "method returned FALSE for $alert_type when Sending with Customer Opted Out of '".$method->method."' Alerts" );
                    cmp_ok( $logs->reset->count(), '==', 0, "correspondence log NOT created" );
                    cmp_ok( $sched_rec->discard_changes->notified, '==', 0, "schedule record 'notified' column still FALSE" );
                    $order->change_csm_preference( $corr_subject->id, { $method->id => 1 } );

                    if ( $alert_type eq 'SMS' ) {
                        # send an sms without a Message Factory passed
                        cmp_ok( $base_rec->_rtschd_send_alert( $alert, "$alert_type message" ), '==', 0,
                                                                    "method returned FALSE for $alert_type when calling without a Message Factory passed" );
                        cmp_ok( $logs->reset->count(), '==', 0, "correspondence log NOT created" );
                        cmp_ok( $sched_rec->discard_changes->notified, '==', 0, "schedule record 'notified' column still FALSE" );
                    }
                }
            }


            note "Testing 'send_routing_schedule_notification' method in normal use that should send an Email & SMS alert";
            _delete_rout_sched( @recs );
            _discard_changes( $shipment, $return );
            $ship_logs->reset->delete;
            $ret_logs->reset->delete;
            @recs   = ();
            push @recs, _create_rout_sched( $shipment, $delv_scheds->{scheduled1} );
            push @recs, _create_rout_sched( $return, $coll_scheds->{scheduled1} );

            cmp_ok( $shipment->send_routing_schedule_notification( $msg_factory ), '==', 1, "Shipment: method returned TRUE" );
            cmp_ok( $ship_logs->reset->count(), '==', 2, "there were 2 correspondence logs created" );
            cmp_ok( $recs[0]->discard_changes->notified, '==', 1, "schedule record 'notified' column is TRUE" );
            cmp_ok( $shipment->send_routing_schedule_notification( $msg_factory ), '==', 0, "method returns FALSE when sending same alert again" );

            cmp_ok( $return->send_routing_schedule_notification( $msg_factory ), '==', 1, "Return: method returned TRUE" );
            cmp_ok( $ret_logs->reset->count(), '==', 2, "there were 2 correspondence logs created" );
            cmp_ok( $recs[1]->discard_changes->notified, '==', 1, "schedule record 'notified' column is TRUE" );
            cmp_ok( $return->send_routing_schedule_notification( $msg_factory ), '==', 0, "method returns FALSE when sending same alert again" );


            # rollback changes
            $schema->txn_rollback();
        } );
    };

    return;
}

#-------------------------------------------------------------------------------------

# helper method to '->discard_changes' on a list of DBIC objects
sub _discard_changes {
    my @list    = @_;
    foreach my $obj ( @list ) {
        $obj->discard_changes;
    }
    return;
}

# this builds up a list ofr Routing Schedules
# that can be created and used in tests
sub _build_list_of_schedules {
    my ( $date, $args )     = @_;

    my $ext_id  = 1;

    my $type_id     = ( $args->{delivery} ? $ROUTING_SCHEDULE_TYPE__DELIVERY : $ROUTING_SCHEDULE_TYPE__COLLECTION );
    my %status_id   = (
            scheduled   => $ROUTING_SCHEDULE_STATUS__SCHEDULED,
            re_scheduled=> $ROUTING_SCHEDULE_STATUS__RE_DASH_SCHEDULED,
            failed      => ( $args->{delivery} ? $ROUTING_SCHEDULE_STATUS__SHIPMENT_UNDELIVERED : $ROUTING_SCHEDULE_STATUS__SHIPMENT_UNCOLLECTED ),
            success     => ( $args->{delivery} ? $ROUTING_SCHEDULE_STATUS__SHIPMENT_DELIVERED : $ROUTING_SCHEDULE_STATUS__SHIPMENT_COLLECTED ),
        );

    # list of arguments used to create 'routing_schedule'
    # records that will be used in the tests
    my %sched_args;
    $sched_args{base}   = {             # create the first one which will be the basis for all the others
                        routing_schedule_type_id    => $type_id,
                        routing_schedule_status_id  => $status_id{scheduled},
                        external_id                 => $ext_id++,
                        task_window_date            => $date->ymd('/'),
                        task_window                 => "15:30 to 18:00",
                        formatted_task_window       => "3:30pm-6pm",
                        driver                      => 'Dave',
                        run_number                  => 1,
                        run_order_number            => 34,
                        notified                    => 1,
                    };

    $sched_args{scheduled1} = {
                        %{ $sched_args{base} },
                        notified    => 1,
                    };
    $sched_args{rescheduled1}= {
                        %{ $sched_args{scheduled1} },
                        routing_schedule_status_id  => $status_id{re_scheduled},
                        # this should be turned into 'TBC' because the status is 'Re-scheduled'
                        task_window                 => "14:35 to 18:45",
                        formatted_task_window       => undef,
                        run_number                  => 4,
                        run_order_number            => 7,
                        notified                    => 0,
                    };
    $sched_args{success1}    = {
                        %{ $sched_args{scheduled1} },
                        routing_schedule_status_id  => $status_id{success},
                        signatory                   => 'billy',
                        signature_time              => $date,
                        notified                    => 0,
                    };
    $sched_args{failed1} = {
                        %{ $sched_args{scheduled1} },
                        routing_schedule_status_id  => $status_id{failed},
                        undelivered_notes           => 'no answer',
                        notified                    => 1,
                    };

    $sched_args{scheduled2} = {
                        %{ $sched_args{base} },
                        external_id                 => $ext_id++,
                        routing_schedule_status_id  => $status_id{scheduled},
                        task_window_date            => $date->clone->add( days => 1 )->ymd('/'),
                        task_window                 => "14:00 to 16:30",
                        formatted_task_window       => "2pm-4:30pm",
                        run_number                  => 6,
                        run_order_number            => 9,
                        notified                    => 1,
                    };
    $sched_args{rescheduled2}   = {
                        %{ $sched_args{scheduled2} },
                        routing_schedule_status_id  => $status_id{re_scheduled},
                        task_window                 => undef,
                        formatted_task_window       => undef,
                        run_number                  => 6,
                        run_order_number            => 9,
                        notified                    => 0,
                    };
    $sched_args{success2} = {
                        %{ $sched_args{scheduled2} },
                        routing_schedule_status_id  => $status_id{success},
                        signatory                   => 'billy',
                        signature_time              => $date,
                        notified                    => 1,
                    };
    $sched_args{failed2}= {
                        %{ $sched_args{scheduled2} },
                        routing_schedule_status_id  => $status_id{failed},
                        undelivered_notes           => 'no answer',
                        notified                    => 0,
                    };

    $sched_args{scheduled3} = {
                        %{ $sched_args{base} },
                        external_id                 => $ext_id++,
                        task_window_date            => $date->clone->add( days => 2 )->ymd('/'),
                        task_window                 => "10:00 to 12:00",
                        formatted_task_window       => "10am-12pm",
                        driver                      => 'Bob',
                        run_number                  => 7,
                        run_order_number            => 3,
                        notified                    => 0,
                    };
    $sched_args{rescheduled3}= {
                        %{ $sched_args{scheduled3} },
                        routing_schedule_status_id  => $status_id{re_scheduled},
                        task_window                 => undef,
                        formatted_task_window       => undef,
                        run_number                  => 7,
                        run_order_number            => 3,
                        notified                    => 0,
                    };
    $sched_args{success3}   = {
                        %{ $sched_args{scheduled3} },
                        routing_schedule_status_id  => $status_id{success},
                        signatory                   => 'sally',
                        signature_time              => $date,
                        notified                    => 1,
                    };
    $sched_args{failed3}    = {
                        %{ $sched_args{scheduled3} },
                        routing_schedule_status_id  => $status_id{failed},
                        undelivered_notes           => 'no answer',
                        notified                    => 1,
                    };
    $sched_args{scheduled4} = {
                        %{ $sched_args{base} },
                        external_id                 => $ext_id++,
                        task_window_date            => $date->clone->add( days => 3 )->ymd('/'),
                        task_window                 => "10:30 to 12:00",
                        formatted_task_window       => "10:30am-12pm",
                        driver                      => 'Eliza',
                        run_number                  => 9,
                        run_order_number            => 2,
                        notified                    => 0,
                    };
    $sched_args{rescheduled4}= {
                        %{ $sched_args{scheduled4} },
                        routing_schedule_status_id  => $status_id{re_scheduled},
                        task_window                 => undef,
                        formatted_task_window       => undef,
                        run_number                  => 9,
                        run_order_number            => 2,
                        notified                    => 0,
                    };
    $sched_args{success4}   = {
                        %{ $sched_args{scheduled4} },
                        routing_schedule_status_id  => $status_id{success},
                        signatory                   => 'liz',
                        signature_time              => $date,
                        notified                    => 1,
                    };
    $sched_args{failed4}    = {
                        %{ $sched_args{scheduled4} },
                        routing_schedule_status_id  => $status_id{failed},
                        undelivered_notes           => 'no answer',
                        notified                    => 1,
                    };
    $sched_args{scheduled5} = {
                        %{ $sched_args{base} },
                        external_id                 => $ext_id++,
                        task_window_date            => $date->clone->add( days => 4 )->ymd('/'),
                        task_window                 => "10:00 to 12:45",
                        formatted_task_window       => "10am-12:45pm",
                        driver                      => 'Jack',
                        run_number                  => 10,
                        run_order_number            => 7,
                        notified                    => 0,
                    };
    $sched_args{rescheduled5}= {
                        %{ $sched_args{scheduled5} },
                        routing_schedule_status_id  => $status_id{re_scheduled},
                        task_window                 => undef,
                        formatted_task_window       => undef,
                        run_number                  => 10,
                        run_order_number            => 14,
                        notified                    => 0,
                    };
    $sched_args{success5}   = {
                        %{ $sched_args{scheduled5} },
                        routing_schedule_status_id  => $status_id{success},
                        signatory                   => 'Jill',
                        signature_time              => $date,
                        notified                    => 1,
                    };
    $sched_args{failed5}    = {
                        %{ $sched_args{scheduled5} },
                        routing_schedule_status_id  => $status_id{failed},
                        undelivered_notes           => 'no answer',
                        notified                    => 1,
                    };

    # get rid of any setting of the 'notified' column
    if ( $args->{default_notified_columns} ) {
        foreach my $args ( values %sched_args ) {
            delete $args->{notified};
        }
    }

    return \%sched_args;
}

# this will run the actual tests in the %tests hash
# for the '_test_schedule_list' test function
sub _run_the_tests {
    my ( $base_rec, $tests )    = @_;

    foreach my $test_label ( keys %{ $tests } ) {
        note "TESTING: $test_label";
        my $test    = $tests->{ $test_label };

        # create the required records
        my @recs;
        foreach my $args ( @{ $test->{create} } ) {
            push @recs, _create_rout_sched( $base_rec, $args );
        }

        # get the list
        my $list    = $base_rec->routing_schedules->list_schedules;
        isa_ok( $list, 'ARRAY', "'list' method returned correctly" );
        cmp_ok( @{ $list }, '==', $test->{expected_elems}, "expected array length: $$test{expected_elems}" );

        # now test each element is as expected
        foreach my $idx ( 0..$#{ $test->{expected} } ) {
            my %expected    = %{ $test->{expected}[ $idx ] };
            my $sig_date_cmp= delete( $expected{sig_date_cmp} );
            my $fmt_twin    = delete( $expected{formatted_task_window} );
            $expected{task_window}  = $fmt_twin     if ( $expected{task_window} && $fmt_twin );

            # just want to look at the keys we're interested in
            my %got = map { $_ => $list->[ $idx ]{$_} } keys %expected;
            $got{task_window_date}  = $got{task_window_date}->ymd('/');
            is_deeply( \%got, \%expected, "element '$idx' is as expected" );
            if ( $sig_date_cmp ) {
                ok( !DateTime->compare( $list->[ $idx ]{signature_time}, $sig_date_cmp ), "'signature_time' is as expected also" );
            }
            else {
                ok( !defined $list->[ $idx ]{signature_time}, "'signature_time' is undef" );
            }
        }

        # set-up for the next test
        _delete_rout_sched( @recs );
    }

    return;
}

# this will run the actual tests in the %sequence_tests hash
# for the '_test_schedule_list' test function
sub _run_sequence_tests {
    my ( $base_rec, $tests )    = @_;

    foreach my $test_label ( keys %{ $tests } ) {
        note "TESTING: $test_label";
        my $test    = $tests->{ $test_label };

        # create the required records
        my @recs;
        foreach my $args ( @{ $test->{create} } ) {
            push @recs, _create_rout_sched( $base_rec, $args );
        }

        # get the list
        my $list    = $base_rec->routing_schedules->in_correct_sequence;
        isa_ok( $list, 'ARRAY', "'in_correct_sequence' method returned correctly" );
        cmp_ok( @{ $list }, '==', @{ $test->{expected} }, "expected array length: " . @{ $test->{expected} } );

        # now test each element is as expected
        foreach my $idx ( 0..$#{ $test->{expected} } ) {
            my %expected    = %{ $test->{expected}[ $idx ] };
            delete( $expected{formatted_task_window} );     # not required for this test

            # just want to look at the keys we're interested in
            my %got     = map { $_ => $list->[ $idx ]->$_ } keys %expected;
            $got{task_window_date}  = $got{task_window_date}->ymd('/');
            is_deeply( \%got, \%expected, "element '$idx' is as expected" );
        }

        # set-up for the next test
        _delete_rout_sched( @recs );
    }

    return;
}

# this will convert tests to be for Collections from Deliveries
sub _convert_tests_for_collections {
    my ( $tests, $sched_args )  = @_;

    # change what is expected for Collections
    foreach my $key ( keys %{ $tests } ) {
        my $test    = $tests->{ $key };
        foreach my $exp ( @{ $test->{expected} } ) {
            $exp->{routing_schedule_type_id}    = $ROUTING_SCHEDULE_TYPE__COLLECTION;
            $exp->{routing_schedule_status_id}  = $ROUTING_SCHEDULE_STATUS__SHIPMENT_COLLECTED
                                    if ( $exp->{routing_schedule_status_id} == $ROUTING_SCHEDULE_STATUS__SHIPMENT_DELIVERED );
            $exp->{routing_schedule_status_id}  = $ROUTING_SCHEDULE_STATUS__SHIPMENT_UNCOLLECTED
                                    if ( $exp->{routing_schedule_status_id} == $ROUTING_SCHEDULE_STATUS__SHIPMENT_UNDELIVERED );
        }
    }

    # change how the records are to be created
    foreach my $key ( keys %{ $sched_args } ) {
        my $arg = $sched_args->{ $key };
        $arg->{routing_schedule_type_id}    = $ROUTING_SCHEDULE_TYPE__COLLECTION;
        $arg->{routing_schedule_status_id}  = $ROUTING_SCHEDULE_STATUS__SHIPMENT_COLLECTED
                                if ( $arg->{routing_schedule_status_id} == $ROUTING_SCHEDULE_STATUS__SHIPMENT_DELIVERED );
        $arg->{routing_schedule_status_id}  = $ROUTING_SCHEDULE_STATUS__SHIPMENT_UNCOLLECTED
                                if ( $arg->{routing_schedule_status_id} == $ROUTING_SCHEDULE_STATUS__SHIPMENT_UNDELIVERED );
    }

    return;
}

# create a 'routing_schedule' record
sub _create_rout_sched {
    my ( $base_rec, $args )     = @_;

    my $sched_rs= $base_rec->result_source->schema->resultset('Public::RoutingSchedule');
    my %clone   = %{ $args };
    delete $clone{formatted_task_window};
    my $rec     = $sched_rs->create( \%clone );
    my $link_tab= ( ref( $base_rec ) =~ m/::Shipment/ ? 'link_routing_schedule__shipments' : 'link_routing_schedule__returns' );
    $base_rec->create_related( $link_tab, { routing_schedule_id => $rec->id } );

    return $rec->discard_changes;
}

# deletes a 'routing_schedule' record
sub _delete_rout_sched {
    my ( @recs )    = @_;

    foreach my $rec ( @recs ) {
        $rec->search_related( 'link_routing_schedule__shipment' )->delete;
        $rec->search_related( 'link_routing_schedule__return' )->delete;
        $rec->delete;
    }

    return;
}

# create a Return for a Shipment
sub _create_return {
    my ( $domain, $shipment )   = @_;

    my $return      = $domain->create( {
                        operator_id => $APPLICATION_OPERATOR_ID,
                        shipment_id => $shipment->id,
                        pickup => 0,
                        refund_type_id => 0,
                        return_items => {
                                map {
                                        $_->id => {
                                            type        => 'Return',
                                            reason_id   => $CUSTOMER_ISSUE_TYPE__7__TOO_SMALL,
                                        }
                                    } $shipment->shipment_items->all
                            }
                    } );

    return $return->discard_changes;
}

# use this to Redefine the 'XTracker::EmailFunctions::send_email' function
sub _redefined_send_email {
    note "============= IN REDEFINED 'send_email' =============";

    if ( $redef_email_todie ) {
        $redef_email_args{subject}  = 'TEST DIED';
        die "TEST TOLD ME TO DIE";
    }

    $redef_email_args{from}     = $_[0];
    $redef_email_args{reply}    = $_[1];
    $redef_email_args{to}       = $_[2];
    $redef_email_args{subject}  = $_[3];
    $redef_email_args{message}  = $_[4];
    $redef_email_args{type}     = $_[5];

    return 1;
}
