#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

=head2 Tests the Routing Schedule script

This will test the (Premier) Routing Schedule scirpt and the 'XT::Routing::Schedule' class which is used by the script to import the data gathered from 'RouteMonkey'.


First done for CANDO-373.

=cut


use Test::Exception;

use Test::XTracker::Data;
use Test::XTracker::MessageQueue;
use Test::XTracker::RunCondition    dc => [ qw( DC1 DC2 ) ], export => [ qw( $distribution_centre ) ];

use Data::Dump      qw( pp );
use DateTime;

use XTracker::Config::Local         qw( config_var );
use XTracker::Constants             qw( :application );
use XTracker::Constants::FromDB     qw(
                                        :customer_category
                                        :customer_issue_type
                                        :routing_schedule_status
                                        :routing_schedule_type
                                        :shipment_item_status
                                    );

use_ok( 'XT::Routing::Schedule' );

my $schema  = Test::XTracker::Data->get_schema();
isa_ok( $schema, 'XTracker::Schema', "sanity check: got a schema" );

# get a new instance of 'XT::Domain::Return'
my $domain  = Test::XTracker::Data->returns_domain_using_dump_dir();

#----------------------------------------------------------
_test_routing_schedule_class( $schema, $domain, 1 );
_test_process_schedule_script( $schema, $domain, 1 );
#----------------------------------------------------------

done_testing();

# tests the 'XT::Routing::Schedule' class methods used by the script
# 'parse_file_content' & 'process_content'
sub _test_routing_schedule_class {
    my ( $schema, $domain, $oktodo )    = @_;

    SKIP: {
        skip "_test_routing_schedule_class", 1      if ( !$oktodo );

        note "in '_test_routing_schedule_class'";

        # get a new object
        my $schedule    = XT::Routing::Schedule->new();
        isa_ok( $schedule, 'XT::Routing::Schedule' );

        # set-up the config to allow Numeric & Alphanumeric Order Numbers through
        my %config = %XTracker::Config::Local::config;
        # store current setting so it can be restored later
        my $original_regex_config = $config{OrderNumber_RegEx}{regex};
        # now set-up the pattern that allows Jimmy Choo
        # Order Numbers as that is a real world scenario
        $config{OrderNumber_RegEx}{regex} = [ 'JC[A-Z]+\d+', '\d+' ];


        note "check the 'parse_file_content' method";

        # first set what is expected to be
        # returned by the method
        my %expected= (
                external_id         => '1234ABC',
                nap_ref             => 456554,
                shipment_id         => 123456,
                driver              => 'Fred Driver',
                delivery_window_date=> '2011/01/14',
                delivery_window     => '16:00 to 18:00',
                run_number          => 45,
                run_order_number    => 2,
                status              => 'Status',
                signatory           => 'billy',
                sig_date            => '2011/01/13',
                sig_time            => '17:54:34',
                undelivered_notes   => 'notes',
            );

        # mocked up content to pass to the method,
        # the method should work in a case insensitive way
        # so create the keys in a mixture of ways
        my %content = (
                OrderId             => $expected{external_id},
                OrderRef            => $expected{nap_ref},
                SHIPMENTNO          => $expected{shipment_id},
                DRIver              => $expected{driver},
                coldeLDate          => $expected{delivery_window_date},
                coldelTime          => $expected{delivery_window},
                runNo               => $expected{run_number},
                RunordeRno          => $expected{run_order_number},
                status              => $expected{status},
                Sig                 => $expected{signatory},
                sigDate             => $expected{sig_date},
                sigtime             => $expected{sig_time},
                UndeliveredNotes    => $expected{undelivered_notes},
                ExtraField          => 'should be ignored',
            );

        my $retval  = $schedule->parse_file_content( \%content );
        isa_ok( $retval, 'HASH', "'parse_file_content' returned correctly" );
        is_deeply( $retval, \%expected, "and returned the correct data as well" );

        # try with an Alphanumeric Order Number
        $content{OrderRef} = 'JCHGB0000123334';
        # change what's expected
        $expected{nap_ref} = $content{OrderRef};
        $retval = $schedule->parse_file_content( \%content );
        is_deeply( $retval, \%expected, "called with Alphanumeric Order Number values still returns as expected" );

        # put back the Numeric Order Number
        $content{OrderRef} = 456554;
        $expected{nap_ref} = $content{OrderRef};

        # try again but this time with content with
        # empty values in it.
        $content{SHIPMENTNO}        = {};       # the 'XML::Simple::XMLin()' function uses
        $content{UndeliveredNotes}  = {};       # empty hash ref's when there is no value
        $content{Sig}               = {};
        $content{status}            = {};
        # change what's expected
        $expected{shipment_id}      = undef;
        $expected{undelivered_notes}= undef;
        $expected{signatory}        = undef;
        $expected{status}           = undef;

        $retval = $schedule->parse_file_content( \%content );
        is_deeply( $retval, \%expected, "called with empty values still returns as expected" );

        # delete an expected key and it shouldn't be returned
        delete( $content{SHIPMENTNO} );
        delete( $expected{shipment_id} );
        $retval = $schedule->parse_file_content( \%content );
        is_deeply( $retval, \%expected, "deleting an expected value still returs as expected" );

        # pass in nothing get nothing back
        $retval = $schedule->parse_file_content( {} );
        ok( !defined $retval, "when passed nothing returns 'undef'" );

        $schema->txn_do( sub {

            note "check the 'process_content' method for a Delivery";

            # assign the Schema to the 'XT::Routing::Schedule' object
            $schedule->schema( $schema );

            # create an order
            my ( $channel, $pids )  = Test::XTracker::Data->grab_products( { channel => Test::XTracker::Data->channel_for_nap } );
            my ( $order, undef )    = Test::XTracker::Data->create_db_order( { pids => $pids } );
            my ( $alt_order, undef )= Test::XTracker::Data->create_db_order( { pids => $pids } );
            my $shipment    = $order->get_standard_class_shipment;
            my $alt_shipment= $alt_order->get_standard_class_shipment;

            note "Order Nr/Shipment Id     : " . $order->order_nr."/".$shipment->id;
            note "Alt. Order Nr/Shipment Id: " . $alt_order->order_nr."/".$alt_shipment->id;

            # set-up Order Numbers to be used in this test
            my $numeric_order_nr = $order->order_nr;
            my $alpha_order_nr   = 'JCHGB0000' . $order->order_nr;

            # used by tests later on
            my $rout_sched_rs   = $schema->resultset('Public::RoutingSchedule');
            my $signatory_size  = $rout_sched_rs->result_source->column_info( 'signatory' )->{size};
            my $undelnotes_size = $rout_sched_rs->result_source->column_info( 'undelivered_notes' )->{size};

            my $ship_sched_rs   = $shipment->routing_schedules->search( {}, { order_by => 'id DESC' } );
            my @statuses        = $schema->resultset('Public::RoutingScheduleStatus')->all;

            # set-up some expected dates
            my $date1   = DateTime->new( time_zone => 'local', day => '13', month => '01', year => '2011' );
            my $date2   = $date1->clone->set( hour => '17', minute => '54', second => '34' );
            my $date3   = DateTime->new( year => '2011', month => '01', day => '14' );

            my $date_with_zero_second = $date1->clone->set( hour => '17', minute => '54', second => '00' );
            my $date_with_zero_time   = $date1->clone->set( hour => '00', minute => '00', second => '00' );

            # mock up some parsed content
            %content    = (
                    external_id         => '1234567',
                    nap_ref             => $order->order_nr,
                    shipment_id         => $shipment->id,
                    driver              => 'Fred Driver',
                    delivery_window_date=> '2011/01/14',
                    delivery_window     => '16:00 to 18:00',
                    run_number          => 45,
                    run_order_number    => 2,
                    status              => undef,       # pass in no status which should get set to 'Scheduled'
                    signatory           => 'billy',
                    sig_date            => '2011/01/13',
                    sig_time            => undef,       # will test with only half the Signature date completed
                    undelivered_notes   => 'notes',
                );

            # set what's expected
            %expected   = (
                    routing_schedule_type_id    => $ROUTING_SCHEDULE_TYPE__DELIVERY,
                    routing_schedule_status_id  => $ROUTING_SCHEDULE_STATUS__SCHEDULED,
                    external_id                 => $content{external_id},
                    driver                      => $content{driver},
                    task_window                 => $content{delivery_window},
                    run_number                  => $content{run_number},
                    run_order_number            => $content{run_order_number},
                    signatory                   => $content{signatory},
                    undelivered_notes           => $content{undelivered_notes},
                );

            $retval = $schedule->process_content( \%content );
            isa_ok( $retval, 'XTracker::Schema::Result::Public::RoutingSchedule', "'process_content' returned a correct record" );
            cmp_ok( $retval->id, '==', $ship_sched_rs->reset->first->id, "Routing Schedule record returned is attached to the correct Shipment" );
            my %got = map { $_ => $retval->$_ } keys %expected;
            is_deeply( \%got, \%expected, "'routing_schedule' record has the correct values" );
            isa_ok( $retval->date_imported, 'DateTime', "'date_imported' has a value" );
            cmp_ok( length( $retval->signatory ), '==', length( $expected{signatory} ), "length of Signatory value as expected" );
            cmp_ok( length( $retval->undelivered_notes ), '==', length( $expected{undelivered_notes} ), "length of Undeliv Notes value as expected" );
            ok( !DateTime->compare( $retval->signature_time, $date1 ), "'signature_time' is as expected" );
            ok( !DateTime->compare( $retval->task_window_date, $date3 ), "'task_window_date' is as expected" );

            note "test alternative sig date format and also a sig time without seconds, should be fine";
            $content{sig_date}  = '13/01/2011';
            $content{sig_time}  = '17:54';
            $retval = $schedule->process_content( \%content );
            cmp_ok( $retval->id, '==', $ship_sched_rs->reset->first->id, "Routing Schedule record returned is the last record attached to the Shipment" );
            ok( !DateTime->compare( $retval->signature_time, $date_with_zero_second ), "'signature_time' is as expected and now complete" );

            note "test with a sig time without minutes, should still go through with '00:00:00' as the time";
            $content{sig_time}  = '17';
            $retval = $schedule->process_content( \%content );
            cmp_ok( $retval->id, '==', $ship_sched_rs->reset->first->id, "Routing Schedule record returned is the last record attached to the Shipment" );
            ok( !DateTime->compare( $retval->signature_time, $date_with_zero_time ), "'signature_time' is as expected and now complete" );

            note "test with a sig time which is nonsense, should still go through with '00:00:00' as the time";
            $content{sig_time}  = ':17:';
            $retval = $schedule->process_content( \%content );
            cmp_ok( $retval->id, '==', $ship_sched_rs->reset->first->id, "Routing Schedule record returned is the last record attached to the Shipment" );
            ok( !DateTime->compare( $retval->signature_time, $date_with_zero_time ), "'signature_time' is as expected and now complete" );

            note "test using Alphanumeric Order Number";
            $content{nap_ref} = $alpha_order_nr;
            $order->update( { order_nr => $alpha_order_nr } );
            $retval = $schedule->process_content( \%content );
            cmp_ok( $retval->id, '==', $ship_sched_rs->reset->first->id, "Routing Schedule record returned is the last record attached to the Shipment" );

            # put back the Numeric Order Number
            $content{nap_ref} = $numeric_order_nr;
            $order->update( { order_nr => $numeric_order_nr } );

            note "test using no delivery_window_date an alternative sig date format and also a sig time with seconds, and also a signatory of > 100 chars & undeliv notes > 1000 chars";
            delete $content{delivery_window_date};
            $content{sig_date}  = '13/01/2011';
            $content{sig_time}  = '17:54:34';
            $content{signatory} = 'A' x ( $signatory_size + 1 );
            $content{undelivered_notes} = 'B' x ( $undelnotes_size + 1 );
            $retval = $schedule->process_content( \%content );
            cmp_ok( $retval->id, '==', $ship_sched_rs->reset->first->id, "Routing Schedule record returned is the last record attached to the Shipment" );
            ok( !DateTime->compare( $retval->signature_time, $date2 ), "'signature_time' is as expected and now complete" );
            ok( !$retval->task_window_date, "'task_window_date' is undef" );
            cmp_ok( length( $retval->signatory ), '==', $signatory_size, "length of Signatory value is at maximum" );
            cmp_ok( length( $retval->undelivered_notes ), '==', $undelnotes_size, "length of Undeliv Notes value is at maximum" );

            note "test using all Statuses";
            $content{delivery_window_date}  = '2011/01/14';     # put this back in
            foreach my $status ( @statuses ) {
                $content{status}    = uc( $status->name );          # uppercase it so the case insensitive search still finds it
                $retval = $schedule->process_content( \%content );
                cmp_ok( $retval->routing_schedule_status_id, '==', $status->id, "with Status: '".$status->name."' got expected Status Id" );
                cmp_ok( $retval->id, '==', $ship_sched_rs->reset->first->id, "Routing Schedule record returned is the last record attached to the Shipment" );
            }
            my $ship_rout_sched = $retval;      # store this for a later test


            note "check the 'process_content' method for a Collection";

            # create a Return
            my $return      = _create_return( $domain, $shipment );
            my $ret_sched_rs= $return->routing_schedules->search( {}, { order_by => 'id DESC' } );

            # set-up the data to be processed
            $content{shipment_id}   = undef;              # no 'shipment_id' for collections
            $content{nap_ref}       = $return->rma_number;
            $content{status}        = 'Shipment collected';
            $content{signatory}     = 'billy';
            $content{undelivered_notes} = 'notes';

            # and what's to be expected
            $expected{routing_schedule_type_id}     = $ROUTING_SCHEDULE_TYPE__COLLECTION;
            $expected{routing_schedule_status_id}   = $ROUTING_SCHEDULE_STATUS__SHIPMENT_COLLECTED;

            $retval = $schedule->process_content( \%content );
            isa_ok( $retval, 'XTracker::Schema::Result::Public::RoutingSchedule', "'process_content' returned a correct record" );
            cmp_ok( $retval->id, '==', $ret_sched_rs->reset->first->id, "Routing Schedule record returned is attached to the correct Return" );
            %got    = map { $_ => $retval->$_ } keys %expected;
            is_deeply( \%got, \%expected, "'routing_schedule' record has the correct values" );
            isa_ok( $retval->date_imported, 'DateTime', "'date_imported' has a value" );
            ok( !DateTime->compare( $retval->signature_time, $date2 ), "'signature_time' is as expected" );

            note "test with not much data just like an initial data file would have";
            %content    = (
                    external_id         => '4567890',
                    nap_ref             => $return->rma_number,
                    shipment_id         => undef,
                    driver              => 'Fred Driver',
                    delivery_window_date=> '2011/01/14',
                    delivery_window     => '16:00 to 18:00',
                    run_number          => 45,
                    run_order_number    => undef,
                    status              => undef,       # pass in no status which should get set to 'Scheduled'
                    signatory           => undef,
                    sig_date            => undef,
                    sig_time            => undef,
                    undelivered_notes   => undef,
                );
            %expected   = (
                    routing_schedule_type_id    => $ROUTING_SCHEDULE_TYPE__COLLECTION,
                    routing_schedule_status_id  => $ROUTING_SCHEDULE_STATUS__SCHEDULED,
                    external_id                 => $content{external_id},
                    driver                      => $content{driver},
                    task_window                 => $content{delivery_window},
                    run_number                  => $content{run_number},
                    run_order_number            => undef,
                    signatory                   => undef,
                    signature_time              => undef,
                    undelivered_notes           => undef,
                );

            $retval = $schedule->process_content( \%content );
            isa_ok( $retval, 'XTracker::Schema::Result::Public::RoutingSchedule', "'process_content' returned a correct record" );
            cmp_ok( $retval->id, '==', $ret_sched_rs->reset->first->id, "Routing Schedule record returned is the last record attached to the Return" );
            %got    = map { $_ => $retval->$_ } keys %expected;
            is_deeply( \%got, \%expected, "'routing_schedule' record has the correct values" );


            note "test the methods 'shipment' & 'return' on the 'Public::RoutingSchedule' class";
            cmp_ok( $ship_rout_sched->shipment_rec->id, '==', $shipment->id, "'shipment' method used for a Delivery returns correct Shipment Id" );
            cmp_ok( $retval->return_rec->id, '==', $return->id, "'return' method used for a Collection returns correct Return Id" );
            ok( !defined $ship_rout_sched->return_rec, "'return' method used for a Delivery returns 'undef'" );
            ok( !defined $retval->shipment_rec, "'shipment' method used for a Collection returns 'undef'" );


            note "test that the 'process_content' method dies when it should";

            $content{nap_ref}   = undef;
            dies_ok( sub {
                    $retval = $schedule->process_content( \%content );
                }, "method died with undef 'nap_ref'" );
            like( $@, qr/Empty 'nap_ref' can't continue/, "got 'empty nap_ref' message" );

            $content{nap_ref}   = '';
            dies_ok( sub {
                    $retval = $schedule->process_content( \%content );
                }, "method died with empty 'nap_ref'" );
            like( $@, qr/Empty 'nap_ref' can't continue/, "got 'empty nap_ref' message" );

            $content{nap_ref}   = 0;
            dies_ok( sub {
                    $retval = $schedule->process_content( \%content );
                }, "method died with zero 'nap_ref'" );
            like( $@, qr/Empty 'nap_ref' can't continue/, "got 'empty nap_ref' message" );

            $content{nap_ref}   = 'Should be rubbish RMA';
            dies_ok( sub {
                    $retval = $schedule->process_content( \%content );
                }, "method died with rubbish RMA reference" );
            like( $@, qr/Couldn't find Return Record for RMA/, "got 'couldn't find return rec' message" );

            $content{nap_ref}   = '12192192192';
            dies_ok( sub {
                    $retval = $schedule->process_content( \%content );
                }, "method died with rubbish Order Nr" );
            like( $@, qr/Couldn't find Shipment Record for Id/, "got 'couldn't find shipment rec' message" );

            $content{nap_ref}       = $order->order_nr;
            $content{shipment_id}   = '-1';
            dies_ok( sub {
                    $retval = $schedule->process_content( \%content );
                }, "method died with Correct Order Nr but rubbish Shipment Id" );
            like( $@, qr/Couldn't find Shipment Record for Id/, "got 'couldn't find shipment rec' message" );

            $content{nap_ref}       = $order->order_nr;
            $content{shipment_id}   = undef;
            dies_ok( sub {
                    $retval = $schedule->process_content( \%content );
                }, "method died with Correct Order Nr but undef Shipment Id" );
            like( $@, qr/Couldn't find Shipment Record for Id/, "got 'couldn't find shipment rec' message" );

            $content{shipment_id}   = $alt_shipment->id;
            dies_ok( sub {
                    $retval = $schedule->process_content( \%content );
                }, "method died with a Correct Shipment Id but for a different Order Nr" );
            like( $@, qr/Shipment '$content{shipment_id}' is not for Order '$content{nap_ref}'/, "got 'shipment not for order' message" );

            $alt_order->link_orders__shipments->delete;
            $content{nap_ref}       = $alt_order->order_nr;
            dies_ok( sub {
                    $retval = $schedule->process_content( \%content );
                }, "method died with a valid Shipment Id but for a Shipment without an Order" );
            like( $@, qr/Shipment '$content{shipment_id}' is not for Order '$content{nap_ref}'/, "got 'shipment not for order' message" );

            $content{nap_ref}       = $order->order_nr;
            $content{shipment_id}   = $shipment->id;
            $content{sig_date}      = '2011/01-13';
            dies_ok( sub {
                    $retval = $schedule->process_content( \%content );
                }, "method died with incorrect Signature Date format" );
            like( $@, qr/Can't parse the Signature Date/, "got 'can't parse date' message" );

            $content{nap_ref}       = $order->order_nr;
            $content{shipment_id}   = $shipment->id;
            $content{sig_date}      = '2011/01/13';
            $content{delivery_window_date} = '2011/01-13';
            dies_ok( sub {
                    $retval = $schedule->process_content( \%content );
                }, "method died with incorrect Delivery Window Date format" );
            like( $@, qr/Can't parse the Delivery Window Date/, "got 'can't parse date' message" );

            $content{nap_ref}       = $order->order_nr;
            $content{shipment_id}   = $shipment->id;
            $content{sig_date}      = '2011-01-13';     # should also prove this date format works
            $content{delivery_window_date} = '2011/01/14';
            $content{status}        = 'garbage should fail',
            dies_ok( sub {
                    $retval = $schedule->process_content( \%content );
                }, "method died with unknown Status" );
            like( $@, qr/Couldn't find a Status for/, "got 'couldn't find status' message" );


            # this tests that a batch of Schedules processed for the same Shipments/Returns
            # doesn't result in multiple Alerts being sent to the Customers, but only ONE each
            note "check 'send_alerts' method";

            # Enable The Subject
            my $corr_subject    = $channel->get_correspondence_subject( 'Premier Delivery' );
            $corr_subject->update( { enabled => 1 } );

            # turn ON the abilty to send 'SMS' and 'Emails', so that Email Logs will have some records
            Test::XTracker::Data->remove_config_group( 'Premier_Delivery', $channel );
            my $prem_conf_grp   = Test::XTracker::Data->create_config_group( 'Premier_Delivery', {
                                                                    channel => $channel,
                                                                    settings => [
                                                                            { setting => 'Email Alert', value => 'On' },
                                                                            { setting => 'SMS Alert', value => 'On' },
                                                                            { setting => 'send_hold_alert_threshold', value => '1' },
                                                                        ],
                                                                } );
            # set-up the data so Alerts can be sent
            $order->customer->update( { category_id => $CUSTOMER_CATEGORY__NONE } );
            $alt_order->customer->update( { category_id => $CUSTOMER_CATEGORY__NONE } );
            $shipment->shipment_items->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PACKED } );
            $alt_shipment->shipment_items->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PACKED } );
            $shipment->update( { mobile_telephone => '+447234567890' } );
            $alt_shipment->update( { mobile_telephone => '+447234567890' } );

            my $ship_email_logs = $shipment->shipment_email_logs->search( {}, { order_by => 'id DESC' } );
            my $alt_email_logs  = $alt_shipment->shipment_email_logs->search( {}, { order_by => 'id DESC' } );
            my $ret_email_logs  = $return->return_email_logs->search( {}, { order_by => 'id DESC' } );

            # start with a clean set of data
            $alt_order->link_orders__shipments->create( { shipment_id => $alt_shipment->id } );     # removed by a previous test
            $ship_email_logs->delete;
            $alt_email_logs->delete;
            $ret_email_logs->delete;
            $shipment->link_routing_schedule__shipments->delete;
            $alt_shipment->link_routing_schedule__shipments->delete;
            $return->link_routing_schedule__returns->delete;

            # clear out the 'alerts_to_send' array on $schedule
            $schedule->alerts_to_send( [] );
            cmp_ok( $schedule->number_of_alerts, '==', 0, "Sanity Check 'number_of_alerts' method returns ZERO" );

            # process some Routing Schedules
            my %delv_content = (
                        external_id         => '1001',
                        nap_ref             => $order->order_nr,
                        shipment_id         => $shipment->id,
                        driver              => 'Fred Driver',
                        delivery_window_date=> '2011/01/14',
                        delivery_window     => '16:00 to 18:00',
                        run_number          => 45,
                        run_order_number    => 2,
                        status              => 'Scheduled',
                    );
            my %coll_content = (
                        external_id         => '1002',
                        nap_ref             => $return->rma_number,
                        shipment_id         => undef,
                        driver              => 'Fred Driver',
                        delivery_window_date=> '2011/01/14',
                        delivery_window     => '16:00 to 18:00',
                        run_number          => 45,
                        run_order_number    => 4,
                        status              => 'Scheduled',
                    );

            # set-up data, so that only 1 alert is sent per Shipment/Return:
            #       * Alt. Shipment has 2 records, so should be sent 1 alert
            #       * Normal Shipment has 1 record, should be sent 1 alert
            #       * Return has 3 records, should still only be sent 1 alert
            my @contents    = (
                        {
                            %delv_content,
                            external_id => '1003',
                            nap_ref => $alt_order->order_nr,
                            shipment_id => $alt_shipment->id,
                            run_order_number => 3,
                            status => 'Re-scheduled',
                        },
                        { %delv_content },
                        {
                            %coll_content,
                            external_id => '1000',
                            run_number  => 40,
                            status => 'Re-scheduled',
                        },
                        {
                            %delv_content,
                            external_id => '1003',
                            nap_ref => $alt_order->order_nr,
                            shipment_id => $alt_shipment->id,
                            run_order_number => 3,
                        },
                        { %coll_content },
                        {
                            %coll_content,
                            status      => 'Shipment collected',
                            signatory   => 'billy',
                            sig_date    => '2011/01/14',
                            sig_time    => '17:35:00',
                        },
                    );
            my @expected    = (
                        { rec_class => ref( $alt_shipment ), id => $alt_shipment->id },
                        { rec_class => ref( $shipment ), id => $shipment->id },
                        { rec_class => ref( $return ), id => $return->id },
                        { rec_class => ref( $alt_shipment ), id => $alt_shipment->id },
                        { rec_class => ref( $return ), id => $return->id },
                        { rec_class => ref( $return ), id => $return->id },
                    );

            foreach my $content ( @contents ) {
                $schedule->process_content( $content );
            }

            # check no Alerts were sent by 'process_content' method
            cmp_ok( $ship_email_logs->count, '==', 0, "Shipment Email Log has ZERO Alerts Sent after call to 'process_content' method" );
            cmp_ok( $alt_email_logs->count, '==', 0, "Alt. Shipment Email Log has ZERO Alerts Sent after call to 'process_content' method" );
            cmp_ok( $ret_email_logs->count, '==', 0, "Return Email Log has ZERO Alerts Sent after call to 'process_content' method" );

            is_deeply( $schedule->alerts_to_send, \@expected, "'alerts_to_send' Array as Expected after 'process_content' method" );
            cmp_ok( $schedule->number_of_alerts, '==', @contents, "After Processing ".@contents." Schedules 'number_of_alerts' method returns: ".@contents );
            my $num_sent    = $schedule->send_alerts();
            ok( defined $num_sent, "'send_alerts' method returned a defined value" );
            cmp_ok( $num_sent, '==', 3, "'send_alerts' method returned: 3 calls to send an alert" );
            cmp_ok( $ship_email_logs->reset->count, '>', 0, "Shipment Email Log has Alerts Sent" );
            cmp_ok( $alt_email_logs->reset->count, '==', 0, "Alt. Shipment Email Log has ZERO Alerts Sent as its last record is a 'Re-Schedule'" );
            cmp_ok( $ret_email_logs->reset->count, '>', 0, "Return Email Log has Alerts Sent" );
            # array should now be empty
            cmp_ok( $schedule->number_of_alerts, '==', 0, "'number_of_alerts' method returns ZERO after sending Alerts" );


            # rollback changes
            $schema->txn_rollback();
        } );

        # restore the Order Number RegEx config
        $config{OrderNumber_RegEx}{regex} = $original_regex_config;
    };

    return;
}

# this test the 'script/routing/process_schedule.pl' script to make
# sure it imports the XML files correctly
sub _test_process_schedule_script {
    my ( $schema, $domain, $oktodo )    = @_;

    # name of the script to import the XML files
    my $script  = 'script/routing/import_routing_files.pl';

    my $date_dir    = DateTime->now( time_zone => 'local' )->ymd('');
    my $ready_dir   = Test::XTracker::Data->routing_schedule_ready_dir;
    my $proc_dir    = Test::XTracker::Data->routing_schedule_processed_dir . "/$date_dir";
    my $fail_dir    = Test::XTracker::Data->routing_schedule_fail_dir . "/$date_dir";

    SKIP: {
        skip "_test_process_schedule_script", 1         if ( !$oktodo );

        note "in '_test_process_schedule_script'";

        # create an order
        my ( $channel, $pids )  = Test::XTracker::Data->grab_products( { channel => Test::XTracker::Data->channel_for_nap } );
        my ( $order, undef )    = Test::XTracker::Data->create_db_order( { pids => $pids } );
        my $shipment    = $order->get_standard_class_shipment;
        my $return      = _create_return( $domain, $shipment );

        # set-up the data so Alerts can be sent
        $order->customer->update( { category_id => $CUSTOMER_CATEGORY__NONE } );
        $shipment->shipment_items->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PACKED } );
        $shipment->update( { mobile_telephone => '+447234567890' } );

        note "Order Nr/Id:   ".$order->order_nr."/".$order->id;
        note "Shipment Id:   ".$shipment->id;
        note "Return RMA/Id: ".$return->rma_number."/".$return->id;

        # to be used in later tests
        my $date1           = DateTime->new( time_zone => 'local', day => 20, month => 1, year => 2011, hour => 14, minute => 34, second => 56 );
        my $date2           = DateTime->new( year => '2011', month => '01', day => '21' );
        my $sched_rs        = $schema->resultset('Public::RoutingSchedule');
        my $ship_sched_rs   = $shipment->routing_schedules->search( {}, { order_by => 'id DESC' } );
        my $ret_sched_rs    = $return->routing_schedules->search( {}, { order_by => 'id DESC' } );

        # get the Email Logs for the Shipment & Return
        my $ship_email_logs = $shipment->shipment_email_logs->search( {}, { order_by => 'id DESC' } );
        my $ret_email_logs  = $return->return_email_logs->search( {}, { order_by => 'id DESC' } );

        # get the exepcted number of email log entries
        # per communication when importing a schedule
        my $expected_logs   = 0;
        $expected_logs++            if ( Test::XTracker::Data->is_method_enabled_for_subject( $channel, 'Premier Delivery', 'SMS' ) );
        $expected_logs++            if ( Test::XTracker::Data->is_method_enabled_for_subject( $channel, 'Premier Delivery', 'Email' ) );

        note "test when there are no files to process";
        Test::XTracker::Data->purge_routing_schedule_directories;
        cmp_ok( _execute_script( $script ), '==', 0, "Script Ran OK" );


        note "test processing a file for a Delivery";
        my $file_content    = {
                    nap_ref             => $order->order_nr,
                    shipment_id         => $shipment->id,
                    type                => 'Delivery',
                    task_window_date    => '2011/01/21',
                    task_window         => '15:00 to 18:00',
                    driver              => 'Max',
                    run_number          => 34,
                    run_order_number    => 5,
                    status              => 'Shipment delivered',
                    signatory           => 'billy',
                    sig_date            => '2011/01/20',
                    sig_time            => '14:34:56',
                    undelivered_notes   => 'notes for undelivery',
                };
        my %expected        = (
                    routing_schedule_type_id    => $ROUTING_SCHEDULE_TYPE__DELIVERY,
                    routing_schedule_status_id  => $ROUTING_SCHEDULE_STATUS__SHIPMENT_DELIVERED,
                    driver                      => $file_content->{driver},
                    task_window                 => $file_content->{task_window},
                    run_number                  => $file_content->{run_number},
                    run_order_number            => $file_content->{run_order_number},
                    signatory                   => $file_content->{signatory},
                    undelivered_notes           => $file_content->{undelivered_notes},
                );

        my $external_id = Test::XTracker::Data->create_xml_routing_schedule_file( 'routing_schedule.xml.tt', $file_content );

        $ship_email_logs->delete;           # make sure the email logs are empty
        cmp_ok( _execute_script( $script ), '==', 0, "Script Ran OK" );
        my $routshed_rec    = $ship_sched_rs->reset->first;
        isa_ok( $routshed_rec, 'XTracker::Schema::Result::Public::RoutingSchedule', "Found a 'routing_schedule' record for the correct Shipment" );
        is( $routshed_rec->external_id, $external_id, "and 'external_id' value is correct" );
        my %got = map { $_ => $routshed_rec->$_ } keys %expected;
        is_deeply( \%got, \%expected, "'routing_schedule' record has the correct values" );
        ok( !DateTime->compare( $routshed_rec->signature_time, $date1 ), "'signature_time' is as expected" );
        ok( !DateTime->compare( $routshed_rec->task_window_date, $date2 ), "'task_window_date' is as expected" );
        ok( !-f "$ready_dir/${external_id}.xml", "File no longer in the Ready Dir" );
        ok( -s "$proc_dir/${external_id}.xml", "File now in the Processed Dir & not Zero length" );
        cmp_ok( $ship_email_logs->count(), '==', $expected_logs, "Got the expected number of entries in the 'shipment_email_log' table: $expected_logs" );
        cmp_ok( $routshed_rec->notified, '==', 1, "'routing_schedule' record's 'notified' flag is TRUE" )       if ( $expected_logs );

        note "test processing files in Date Order (earliest first)";
        $file_content->{external_id} = 101;
        Test::XTracker::Data->create_xml_routing_schedule_file( 'routing_schedule.xml.tt', $file_content );
        sleep(2);       # sleep for a bit to build a gap between files being created;
        $file_content->{external_id} = 100;
        Test::XTracker::Data->create_xml_routing_schedule_file( 'routing_schedule.xml.tt', $file_content );
        cmp_ok( _execute_script( $script ), '==', 0, "Script Ran OK" );
        my @logs    = $ship_sched_rs->reset->all;
        is( $logs[1]->external_id, '101', "First File Processed was for External Id 101" );
        is( $logs[0]->external_id, '100', "Second File (and most recent) Processed was for External Id 100" );
        delete $file_content->{external_id};       # clear the External Id for rest of tests

        note "test processing a file for a Collection";
        $file_content->{nap_ref}    = $return->rma_number;
        delete $file_content->{shipment_id};
        $file_content->{type}       = 'Collection';
        $file_content->{status}     = 'Shipment Collected';     # case insensitive Status search will mean this should be ok
        $expected{routing_schedule_type_id}     = $ROUTING_SCHEDULE_TYPE__COLLECTION;
        $expected{routing_schedule_status_id}   = $ROUTING_SCHEDULE_STATUS__SHIPMENT_COLLECTED;
        $external_id    = Test::XTracker::Data->create_xml_routing_schedule_file( 'routing_schedule.xml.tt', $file_content );
        $ret_email_logs->delete;            # make sure the email logs are empty

        cmp_ok( _execute_script( $script ), '==', 0, "Script Ran OK" );
        $routshed_rec   = $ret_sched_rs->reset->first;
        isa_ok( $routshed_rec, 'XTracker::Schema::Result::Public::RoutingSchedule', "Found a 'routing_schedule' record for the correct Return" );
        is( $routshed_rec->external_id, $external_id, "and 'external_id' value is correct" );
        %got    = map { $_ => $routshed_rec->$_ } keys %expected;
        is_deeply( \%got, \%expected, "'routing_schedule' record has the correct values" );
        ok( !DateTime->compare( $routshed_rec->signature_time, $date1 ), "'signature_time' is as expected" );
        ok( !DateTime->compare( $routshed_rec->task_window_date, $date2 ), "'task_window_date' is as expected" );
        ok( !-f "$ready_dir/${external_id}.xml", "File no longer in the Ready Dir" );
        ok( -s "$proc_dir/${external_id}.xml", "File now in the Processed Dir & not Zero length" );
        cmp_ok( $ret_email_logs->count(), '==', $expected_logs, "Got the expected number of entries in the 'return_email_log' table: $expected_logs" );
        cmp_ok( $routshed_rec->notified, '==', 1, "'routing_schedule' record's 'notified' flag is TRUE" )       if ( $expected_logs );


        note "test when a file fails to be processed";
        $file_content->{status} = 'invalid status - should fail';
        $external_id    = Test::XTracker::Data->create_xml_routing_schedule_file( 'routing_schedule.xml.tt', $file_content );
        cmp_ok( _execute_script( $script ), '==', 0, "Script Ran OK" );
        cmp_ok( $ret_sched_rs->reset->first->id, '==', $routshed_rec->id, "No new 'routing_schedule' record created" );
        ok( !-f "$ready_dir/${external_id}.xml", "File no longer in the Ready Dir" );
        ok( -s "$fail_dir/${external_id}.xml", "File now in the Failed Dir & not Zero length" );


        note "test importing multiple files";
        # set-up an array of files that will be created
        # for both Deliveries and Collections
        my %file_contents;
        my $key = 1;
        # Deliveries
        foreach my $status ( 'Scheduled', 'Shipment undelivered', 'garbage should fail', 'Re-scheduled', 'Shipment delivered' ) {
            $file_contents{ $key++ }    = {
                                %{ $file_content },
                                type => 'Delivery',
                                nap_ref => $order->order_nr,
                                shipment_id => $shipment->id,
                                run_order_number => $key,
                                status => $status,
                            };
        }
        # Collections
        foreach my $status ( 'Scheduled', 'Shipment uncollected', 'Re-scheduled', 'garbage should fail', 'Shipment collected' ) {
            $file_contents{ $key++ }    = {
                                %{ $file_content },
                                type => 'Collection',
                                nap_ref => $return->rma_number,
                                shipment_id => '',
                                run_order_number => $key,
                                status => $status,
                            };
        }

        my @files;
        foreach my $key ( keys %file_contents ) {
            my $content = $file_contents{ $key };
            $external_id    = Test::XTracker::Data->create_xml_routing_schedule_file( 'routing_schedule.xml.tt', $content );
            # build up a list of the files and what is expected of them
            push @files, {
                        external_id => $external_id,
                        status      => $content->{status},
                        base_rec    => ( $content->{type} eq 'Delivery' ? $shipment : $return ),
                        type_id     => ( $content->{type} eq 'Delivery' ? $ROUTING_SCHEDULE_TYPE__DELIVERY : $ROUTING_SCHEDULE_TYPE__COLLECTION ),
                        run_ord_num => $key,
                    };
        }

        cmp_ok( _execute_script( $script ), '==', 0, "Script Ran OK" );

        # now check everyhthing was ok
        foreach my $file ( @files ) {
            my $external_id = $file->{external_id};
            note "External Id: $external_id - Status of '$$file{status}'";
            if ( $file->{status} ne 'garbage should fail' ) {
                # file should have been processed correctly
                my $rec = $file->{base_rec}->routing_schedules->search( { external_id => $external_id } )->first;
                isa_ok( $rec, 'XTracker::Schema::Result::Public::RoutingSchedule', "Found 'routing_schedule' record for External Id" );
                cmp_ok( $rec->routing_schedule_type_id, '==', $file->{type_id}, "record has correct Type Id" );
                is( $rec->routing_schedule_status->name, $file->{status}, "record has correct Status" );
                cmp_ok( $rec->run_order_number, '==', $file->{run_ord_num}, "record has expected Run Order Number" );
                ok( -s "$proc_dir/${external_id}.xml", "file now in the Processed Dir & not Zero length" );
            }
            else {
                # file should have failed
                my $rec = $sched_rs->search( { external_id => $external_id } )->first;
                ok( !$rec, "Couldn't find record in 'routing_schedule' table" );
                ok( -s "$fail_dir/${external_id}.xml", "file now in the Failed Dir & not Zero length" );
            }
            ok( !-f "$ready_dir/${external_id}.xml", "file no longer in the Ready Dir" );
        }
    };

    return;
}

#-------------------------------------------------------------------------------------

# create a Return for a Shipment
sub _create_return {
    my ( $domain, $shipment )   = @_;

    my $ship_item   = $shipment->shipment_items->first;
    my $return      = $domain->create( {
                        operator_id => $APPLICATION_OPERATOR_ID,
                        shipment_id => $shipment->id,
                        pickup => 0,
                        refund_type_id => 0,
                        return_items => {
                                $ship_item->id => {
                                    type        => 'Return',
                                    reason_id   => $CUSTOMER_ISSUE_TYPE__7__TOO_SMALL,
                                },
                            }
                    } );

    return $return->discard_changes;
}

# execute a script
sub _execute_script {
    my $script  = shift;

    note "executing Script: $script";
    system( $script );
    my $retval  = $? & 127;

    return $retval;
}
