#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

order_view_page.t - Tests various elements of the Order View page

=head1 DESCRIPTION

It currently tests:
    * Personal Shopper & Fashion Advisors Left Hand Menu Options
    * Premier Routing Schedule's are shown on the Order View Page
    * Orderview page has PreOrder Data (preorder number and preorder notes)
    * Create new shipment populates link_shipment_item__reservation/link_shipment_item__reservation_by_pids row
    * That In The Box Marketing Promotions are shown if linked to an Order
    * The App Source & Version are Shown for an Order
    * The Customer's Language Preference is shown
    * Access to the 'Release Exchange' button on the Order View page is restricted
    * Tests the 'Check Pricing' Left Hand Menu option
    * Tests whether a Third Party Payment Method message is shown
      if the Order was paid using one such as PayPal.

Please use this test for general Order View page operations and add to the above list if you add more tests.

Left Hand Menu options used for these Tests:
    * Check Pricing
    * Create Shipment

#TAGS orderview toobig xpath premier preorder createnewshipment checkpricing customercare cando

=cut

use DateTime;

use Test::XTracker::Data;
use Test::XTracker::Data::PreOrder;
use Test::XTracker::Data::MarketingPromotion;
use Test::XTracker::RunCondition
    export => [ qw( $distribution_centre ) ];
use Test::XT::Flow;
use Test::XTracker::MessageQueue;

use XTracker::Utilities                 qw( number_in_list );
use XT::Domain::Returns;
use XTracker::Config::Local             qw(
                                            config_var
                                            customercare_email
                                        );
use XTracker::Constants                 qw( :application );
use XTracker::Constants::FromDB         qw(
                                            :authorisation_level
                                            :correspondence_templates
                                            :department
                                            :shipment_status
                                            :shipment_type
                                            :customer_issue_type
                                            :routing_schedule_type
                                            :routing_schedule_status
                                            :shipment_status
                                            :shipment_class
                                            :shipment_item_status
                                            :note_type
                                            :pre_order_note_type
                                            :shipment_item_returnable_state
                                        );
use Test::XTracker::Data::Shipping;

my $schema  = Test::XTracker::Data->get_schema;
isa_ok( $schema, "XTracker::Schema" );

# need AMQ in order for 'XT::Domain::Return' to work
my $amq = Test::XTracker::MessageQueue->new( { schema => $schema } );

# get a new instance of 'XT::Domain::Return'
my $domain  = XT::Domain::Returns->new(
                        schema => $schema,
                        msg_factory => $amq,
                    );


#--------- Tests ----------------------------------------------

_test_order_view_page_does_not_crash_with_invalid_order_id( 1 );
_test_inthebox_marketing_promotion( $schema, 1);
_test_pre_order_data_on_order_view_page( $schema, 1 );
_test_shipment_item_link_with_reservation ( $schema, 1 );
_test_order_view_page_menu_access( $schema, 1 );
_test_release_exchange_button( $schema, $domain, 1 );
_test_language_preference( $schema, 1 );
_test_app_source( $schema, 1 );
_test_check_pricing( 1 );
_test_returnable_icon( 1 );
_test_shows_third_party_payment( 1 );
_test_shows_amq_order_status_button( $amq, 1 );

# FIXME TODO remove this condition when postcode date is available
if ($schema->resultset('Public::PostcodeShippingCharge')->count() > 1) {
    _test_routing_schedule_on_order_view_page( $schema, $domain, 1 );
}
else {
    note 'Skipping _test_routing_schedule_on_order_view_page because no postcode data available';
}
#--------------------------------------------------------------

done_testing;


=head1 METHODS

=head2 _test_shipment_item_link_with_reservation

    _test_shipment_item_link_with_reservation( $schema, $ok_to_do_flag );

Tests that when creating a Re-Shipment for a Shipment where item(s) are linked to
Reservations that those links remain.

Uses the 'Create Shipment' Left Hand Menu option on the Order View page.

=cut

sub _test_shipment_item_link_with_reservation {
    my ( $schema, $oktodo )     = @_;

    SKIP: {
        skip "_test_shipment_item_link_with_reservation", 1       if ( !$oktodo );

        note "TESTING Create Shipment functionality";

        my $framework   = _setup_framework_and_login();
        my $mech        = $framework->mech;

        # Create a order
        my $orddetails  = $framework->flow_db__fulfilment__create_order(
                                        channel => $framework->channel,
                                        products => 3,
                                    );
        my $order       = $orddetails->{order_object};
        my $customer    = $orddetails->{customer_object};
        my $shipment    = $orddetails->{shipment_object};

        Test::XTracker::Data->set_department( 'it.god', 'Distribution Management' );

        $framework->login_with_permissions( {
            perms => {
                $AUTHORISATION_LEVEL__OPERATOR => [
                    'Customer Care/Customer Search',
                    'Customer Care/Order Search',
                ]
            }
        } );


        note " Order Created : ". $order->id;

        #update shipment and shipment items status to be dispatched
        $shipment->update( { shipment_status_id => $SHIPMENT_STATUS__DISPATCHED } );
        $shipment->shipment_items->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__DISPATCHED } );

        my @shipment_items = $shipment->shipment_items->search( {}, { order_by => 'id' } )->all;
        my @shipment_item_ids= map { $_->id } @shipment_items;


        #create a reservation for one of the shipment item
        my $shipment_item_to_be_reserved = pop(@shipment_items);
        my $variant = $shipment_item_to_be_reserved->variant;
        my $reservation = _create_reservations( $framework->channel, $shipment_item_to_be_reserved->variant, $customer );

        #update link table for that shipment item
        $shipment_item_to_be_reserved->link_with_reservation($reservation);
        #link with reservation by pid
        $shipment_items[1]->link_with_reservation_by_pid($reservation);

        #got to order view page
        $framework->flow_mech__customercare__orderview( $order->id );

        my $data    = $framework->mech->as_data->{meta_data};

        #3) Follow link Create shipment & create a re-shipment
        $framework->flow_mech__customercare__orderview( $order->id )
                    ->flow_mech__customercare__create_shipment
                     ->flow_mech__customercare__create_shipment_submit()
                       ->flow_mech__customercare__create_shipment_item_submit( [ map { $_->id } $shipment->shipment_items->all ] )
                         ->flow_mech__customercare__create_shipment_final_submit;

        #4) check link_shipment_item__reservation table is populate correctly
        my $new_shipment    = _get_recent_shipment( $order,'Re-Shipment' );
        cmp_ok($shipment_item_to_be_reserved->link_shipment_item__reservations, '==', 1, 'Shipment item has link to reservation');
        # check link_shipment_item_reservation_by_pids is populated correctly
        cmp_ok($shipment_item_to_be_reserved->link_shipment_item__reservation_by_pids, '==', 0, 'Shipment item has No link to reservation by pid');

        # for other 2 shipment_items check link table is not populated as expected
        cmp_ok($shipment_items[0]->link_shipment_item__reservations, '==', 0, 'First - Shipment item has No link to reservation');
        cmp_ok($shipment_items[1]->link_shipment_item__reservations, '==', 0, 'Second - Shipment item has No link to reservation');
        # check link_shipment_item__reservation_by_pids table is populated correctly
        cmp_ok($shipment_items[0]->link_shipment_item__reservation_by_pids, '==', 0, 'Shipment item has No link to reservation');
        cmp_ok($shipment_items[1]->link_shipment_item__reservation_by_pids, '==', 1, 'Shipment item has link to reservation');
    };
}

=head2 _test_pre_order_data_on_order_view_page

    _test_pre_order_data_on_order_view_page( $schema, $ok_to_do_flag );

Tests that Pre-Order data about an Order is shown on the Order View page.

Also tests that when creating a Re-Shipment or Replacement Shipment that the
links between the Shipment Item's and their Pre-Order Reservations are
maintained.

Uses the 'Create Shipment' Left Hand Menu option on the Order View page.

=cut

sub _test_pre_order_data_on_order_view_page {
    my ( $schema, $oktodo )     = @_;

    SKIP: {
        skip "_test_pre_order_data_on_order_view_page", 1       if ( !$oktodo );

        note "TESTING Pre-Order data appers on order view page";


        # Create order for a pre-order
        my $order       = Test::XTracker::Data::PreOrder->create_order_linked_to_pre_order();
        my $preorder   = $order->get_preorder;


        # create some pre-order notes
        foreach my $type ($PRE_ORDER_NOTE_TYPE__SHIPMENT_ADDRESS_CHANGE ,
                          $PRE_ORDER_NOTE_TYPE__PRE_DASH_ORDER_ITEM,
                          $PRE_ORDER_NOTE_TYPE__MISC,
                          $PRE_ORDER_NOTE_TYPE__ONLINE_FRAUD_FSLASH_FINANCE
                         ) {
            $preorder->pre_order_notes->create(
                                        {
                                          note_type_id => $type,
                                          note         => 'testing',
                                          operator_id  => $APPLICATION_OPERATOR_ID
                                        } );
        }

        my $framework   = Test::XT::Flow->new_with_traits(
                          traits => [
                            'Test::XT::Flow::CustomerCare',
                             'Test::XT::Data::Channel',
                          ],
                        );
        Test::XTracker::Data->set_department( 'it.god', 'Distribution Management' );

        $framework->login_with_permissions( {
            perms => {
                $AUTHORISATION_LEVEL__OPERATOR => [
                    'Customer Care/Customer Search',
                    'Customer Care/Order Search',
                ]
            }
        } );

        #got to order view page
        $framework->flow_mech__customercare__orderview( $order->id );

        my $data    = $framework->mech->as_data->{meta_data};

        #1) Test PreOrder number is displayed
        cmp_ok( $data->{'Order Details'}->{'Pre-Order Number'}->{value}, 'eq', $preorder->pre_order_number, "PreOrder Number is displayed");

        #2) Test PreOrder Notes are displayed
        my $size = @{ $data->{preorder_notes} };
        cmp_ok ( $size,'==', 4 , "PreOrder notes are displayed");

        #update shipment and shipment items status to be dispatched
        my $shipment = $order->shipments->first;
        $shipment->update( { shipment_status_id => $SHIPMENT_STATUS__DISPATCHED } );
        $shipment->shipment_items->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__DISPATCHED } );

        #create a reservation for all shipments
        my @shipment_items = $shipment->shipment_items->search( {}, { order_by => 'id' } )->all;
        foreach my $item ( @shipment_items ) {
            my $reservation = _create_reservations( $framework->channel, $item->variant, $order->customer );
            #update the link table
            $item->link_with_reservation($reservation);
        }

        #3) Follow link Create shipment & create a re-shipment
        $framework->flow_mech__customercare__orderview( $order->id )
                    ->flow_mech__customercare__create_shipment
                     ->flow_mech__customercare__create_shipment_submit()
                       ->flow_mech__customercare__create_shipment_item_submit( [ map { $_->id } $shipment->shipment_items->all ] )
                         ->flow_mech__customercare__create_shipment_final_submit;

        #4) check link_shipment_item__reservation table
        my $new_shipment    = _get_recent_shipment( $order,'Re-Shipment' );
        foreach my $item ( $new_shipment->shipment_items->all) {
             cmp_ok($item->link_shipment_item__reservations, '==', 1, 'Shipment item has link to reservation');
        }


        #5) use type = replacement to create new shipment
        $framework->flow_mech__customercare__orderview( $order->id )
                    ->flow_mech__customercare__create_shipment
                        ->flow_mech__customercare__create_shipment_select_shipment( $new_shipment->id )
                            ->flow_mech__customercare__create_shipment_submit( 'Replacement' )
                                ->flow_mech__customercare__create_shipment_item_submit( [ map { $_->id } $new_shipment->shipment_items->all ] )
                                    ->flow_mech__customercare__create_shipment_final_submit;

         my $last_shipment    = _get_recent_shipment( $order,'Replacement' );
         foreach my $item ( $last_shipment->shipment_items->all) {
             cmp_ok($item->link_shipment_item__reservations, '==', 1, 'Shipment item has link to reservation');
        }

    };

    return;
}

=head2 _test_routing_schedule_on_order_view_page

    _test_routing_schedule_on_order_view_page( $schema, $xt_domain_returns_object, $ok_to_do_flag );

This tests the Routing Schedule tables (that Route Monkey produce) for Premier Orders are shown for
both Shipments and Returns. Also makes sure that Shipment & Returns Email logs are displayed in the
appropriate sections on the Order View page.

=cut

sub _test_routing_schedule_on_order_view_page {
    my ( $schema, $domain, $oktodo )     = @_;

    SKIP: {
        skip "_test_routing_schedule_on_order_view_page", 1       if ( !$oktodo );

        note "TESTING Premier Routing Schedules on Order View Page";

        # date used in tests
        my $date    = DateTime->new( time_zone => config_var('DistributionCentre', 'timezone'), day => 20, month => 1, year => 2011, hour => 14, minute => 34, second => 56 );

        my $framework   = _setup_framework_and_login();
        my $channel     = $framework->channel;

        my $orddetails  = _create_premier_order( $framework );
        my $order       = $orddetails->{order_object};
        my $shipment    = $orddetails->{shipment_object};
        my $app_operator= $schema->resultset('Public::Operator')->find( $APPLICATION_OPERATOR_ID );

        # with no Schedules Created
        $framework->flow_mech__customercare__orderview( $order->id );
        my $data    = $framework->mech->as_data->{meta_data};
        like( $data->{routing_information}{'s'.$shipment->id}, qr{Premier delivery/collection details are currently not available},
                                    "When there is no Routing Schedules then 'not available' message is shown" );

        # set-up the shipment for a Return and an Exchange
        $shipment->update( { shipment_status_id => $SHIPMENT_STATUS__DISPATCHED } );
        $shipment->shipment_items->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__DISPATCHED } );
        my $return  = _create_return( $domain, $shipment, 'Exchange' );

        my $day1    = $channel->business->branded_date( $date );
        my $day2    = $channel->business->branded_date( $date->clone->add( days => 1 ) );

        # what is expected to be displayed
        my @expected    = (
                    {
                        'Date' => $day2,
                        'Task Window' => '10am-12pm',
                        'Driver' => '<b>Sally&Bob</b>',
                        'Run Number' => qr/\Q42 (7)\E/,
                        'Outcome' => 'Success',
                        'Signatory' => '<b>Claire</b>' . $day2 . ' @ 14:34',
                        'Undelivered Notes' => "",
                    },
                    {
                        'Date' => $day1,
                        'Task Window' => '6pm-8:30pm',
                        'Driver' => 'Bill',
                        'Run Number' => qr/\Q37 (3)\E/,
                        'Outcome' => 'Failed',
                        'Signatory' => "",
                        'Undelivered Notes' => "There was no <b>Answer</b>",
                    },
                    {
                        'Date' => $day1,
                        'Task Window' => '3:30pm-5pm',
                        'Driver' => 'Bill',
                        'Run Number' => qr/\Q34 (5)\E/,
                        'Outcome' => 'Re-Scheduled',
                        'Signatory' => "",
                        'Undelivered Notes' => "",
                    },
                ),

        # add 'routing_schedule' records to the Shipment
        _add_schedule_records( $shipment, $date, 'Shipment' );
        $framework->flow_mech__customercare__orderview( $order->id );
        $data   = $framework->mech->as_data->{meta_data}{routing_information};

        my $info;
        note "Test Shipment Routing Information";
        _check_routing_infomation_table( $data->{ 's'.$shipment->id }, \@expected, 'Shipment' );

        like( $data->{'r'.$return->id}, qr{Premier delivery/collection details are currently not available},
                                    "When there is no Routing Schedules for Return then 'not available' message is shown" );
        like( $data->{'s'.$return->exchange_shipment->id}, qr{Premier delivery/collection details are currently not available},
                                    "When there is no Routing Schedules for Exchange Shipment then 'not available' message is shown" );

        # add 'routing_schedule' records to
        # to Return and Exchange Shipment
        _add_schedule_records( $return, $date, 'Return' );
        _add_schedule_records( $return->exchange_shipment, $date, 'Exchange', "reschedule" );
        $framework->flow_mech__customercare__orderview( $order->id );
        $data   = $framework->mech->as_data->{meta_data}{routing_information};

        note "Test Shipment Routing Information - Again";
        _check_routing_infomation_table( $data->{ 's'.$shipment->id }, \@expected, 'Shipment' );

        note "Test Return Routing Information";
        _check_routing_infomation_table( $data->{ 'r'.$return->id }, \@expected, 'Return' );

        note "Test Exchange Shipment Routing Information";
        # change the first row to be 'TBC'
        $expected[0]{'Task Window'} = 'TBC';
        $expected[0]{'Outcome'}     = 'Pending';
        $expected[0]{'Signatory'}   = "";
        # both 'Driver' & 'Run Number' should be Empty for 'TBC' rows
        $expected[0]{'Driver'}      = undef;        # indicate that it should not be Prefixed with 'Exchange'
        $expected[0]{'Run Number'}  = "";
        _check_routing_infomation_table( $data->{ 's'.$return->exchange_shipment_id }, \@expected, 'Exchange' );

        note "check without any Email Logs, both Return and Shipment Email Logs are not shown";
        $info   = $framework->mech->as_data->{meta_data};
        ok( !exists( $info->{shipment_email_log}{ $shipment->id } ), "NOT Found Shipment Email Log for Shipment: " . $shipment->id );
        ok( !exists( $info->{return_email_log}{ $shipment->id } ), "NOT Found Return Email Log for Shipment: " . $shipment->id );
        # go to the RMA page and test that
        $framework->flow_mech__customercare__click_on_rma( $return->rma_number )
                        ->mech->test_rma_page( $return );

        # create some Correspondence Log entries for both the
        # Shipment and Return to test the Log tables are shown
        my @templates   = $schema->resultset('Public::CorrespondenceTemplate')->search( {}, { rows => 2 } )->all;  # any templates will do
        $shipment->log_correspondence( $templates[0]->id, $APPLICATION_OPERATOR_ID );
        $return->log_correspondence( $templates[1]->id, $APPLICATION_OPERATOR_ID );

        # this scenario shouldn't happen but as we are
        # dealing with a third party just check it any way
        note "Test when there is a 'Signatory' but NO 'Signature Time'";
        # get the last schedule and clear-out the Signature Time
        my $rec = $shipment->discard_changes->routing_schedules
                                                ->search( {}, { order_by => 'id DESC' } )
                                                    ->first;
        $rec->update( { signature_time => undef } );
        $framework->flow_mech__customercare__orderview( $order->id );
        $info   = $framework->mech->as_data->{meta_data}{routing_information}{ 's' . $shipment->id };
        is( $info->[0]{Signatory}, '<b>Claire</b>', "Only Signatory Shown when NO Signature Time" );

        note "Test Shipment/Return Email Logs";
        $info   = $framework->mech->as_data->{meta_data};
        ok( exists( $info->{shipment_email_log}{ $shipment->id } ), "Found Shipment Email Log for Shipment: " . $shipment->id );
        my $log = $info->{shipment_email_log}{ $shipment->id };
        cmp_ok( @{ $log }, '==', 1, "Found ONE Log entry in the Shipment Email Log" );
        is( $log->[0]{'Type'}, $templates[0]->name, "Log 'Type' as Expected: " . $templates[0]->name );
        is( $log->[0]{'Sent By'}, $app_operator->name, "Log 'Sent By' as Expected: " . $app_operator->name );

        ok( exists( $info->{return_email_log}{ $shipment->id } ), "Found Return Email Log for Shipment: " . $shipment->id );
        $log    = $info->{return_email_log}{ $shipment->id };
        cmp_ok( @{ $log }, '==', 1, "Found ONE Log entry in the Return Email Log" );
        is( $log->[0]{'RMA'}, $return->rma_number, "Log 'RMA' as Expected: " . $return->rma_number );
        is( $log->[0]{'Type'}, $templates[1]->name, "Log 'Type' as Expected: " . $templates[1]->name );
        is( $log->[0]{'Sent By'}, $app_operator->name, "Log 'Sent By' as Expected: " . $app_operator->name );

        # go to the RMA page and test that

        # create a Note for the Return so it appears
        # on the next page and can be tested for
        $return->create_related( 'return_notes', {
                                            note        => "Test Note",
                                            note_type_id=> $NOTE_TYPE__RETURNS,
                                            operator_id => $app_operator->id,
                                            date        => \"current_timestamp",
                                        } );

        $framework->flow_mech__customercare__click_on_rma( $return->rma_number )
                        ->mech->test_rma_page( $return );
    };

    return;
}

=head2 _test_order_view_page_menu_access

    _test_order_view_page_menu_access( $schema, $ok_to_do_flag );

This tests the options on the left hand menu that should be there for in
particular Personal Shopper & Fashion Adivsor departments.

=cut

sub _test_order_view_page_menu_access {
    ## no critic(ProhibitDeepNests)
    my ( $schema, $oktodo )     = @_;

    SKIP: {
        skip "_test_order_view_page", 1       if ( !$oktodo );

        note "TESTING Order View Left Hand Menu Options";

        my $framework   = _setup_framework_and_login();
        my $mech        = $framework->mech;

        my $orddetails  = $framework->flow_db__fulfilment__create_order(
                                        channel => $framework->channel,
                                        products => 1,
                                    );
        my $order       = $orddetails->{order_object};
        my $shipment    = $orddetails->{shipment_object};

        my %depts   = map { $_->id => $_ } $schema->resultset('Public::Department')->all;
        my %statuses= map { $_->id => $_ } $schema->resultset('Public::ShipmentStatus')->all;

        # specify the Departments along with different Shipment Statuses
        # and what links should or shouldn't be shown on the left hand menu
        my %tests   = (
                'Personal Shopping/Fashion Advisor' => {
                        depts   => [ grep { number_in_list( $_->id, $DEPARTMENT__PERSONAL_SHOPPING, $DEPARTMENT__FASHION_ADVISOR ) }
                                                    values %depts ],
                        statuses=> {
                                $SHIPMENT_STATUS__PROCESSING    => {
                                            can     => [
                                                    'Edit Order',
                                                    'Edit Shipping Address',
                                                    'Check Pricing',
                                                    'Hold Shipment',
                                                    'Edit Shipment',
                                                    'Cancel Shipment',
                                                    'Size Change',
                                                    'Cancel Order',
                                                    'Cancel Shipment Item',
                                                ],
                                            can_not => [
                                                    'Edit Billing Address',
                                                    'Send Email',
                                                    'Create Credit/Debit',
                                                    'Amend Pricing',
                                                    'Dispatch/Return',
                                                    'Create Shipment',
                                                    'Lost Shipment',
                                                    'Cancel Re-Shipment',
                                                    'Returns',
                                                ],
                                        },
                                $SHIPMENT_STATUS__DISPATCHED    => {
                                            can     => [ 'Returns' ],
                                        },
                            },
                    },
                'Customer Care/Shipping/Stock Control/Distribution' => {
                        depts   => [ grep { number_in_list( $_->id,
                                                                $DEPARTMENT__SHIPPING,
                                                                $DEPARTMENT__SHIPPING_MANAGER,
                                                                $DEPARTMENT__CUSTOMER_CARE,
                                                                $DEPARTMENT__CUSTOMER_CARE_MANAGER,
                                                                $DEPARTMENT__DISTRIBUTION_MANAGEMENT,
                                                                $DEPARTMENT__STOCK_CONTROL,
                                                           ) }
                                                    values %depts ],
                        statuses=> {
                                $SHIPMENT_STATUS__PROCESSING    => {
                                            can     => [
                                                    'Edit Order',
                                                    'Edit Billing Address',
                                                    'Cancel Order',
                                                    'Send Email',
                                                    'Edit Shipment',
                                                    'Edit Shipping Address',
                                                    'Check Pricing',
                                                    'Hold Shipment',
                                                    'Cancel Shipment Item',
                                                    'Size Change',
                                                ],
                                            can_not => [
                                                    'Returns',
                                                    'Lost Shipment',
                                                    'Dispatch/Return',
                                                    'Create Shipment',
                                                    'Create Credit/Debit',
                                                    'Cancel Re-Shipment',
                                                ],
                                        },
                            },
                    },
                'Customer Care/Shipping' => {
                        depts   => [ grep { number_in_list( $_->id,
                                                                $DEPARTMENT__SHIPPING,
                                                                $DEPARTMENT__SHIPPING_MANAGER,
                                                                $DEPARTMENT__CUSTOMER_CARE,
                                                                $DEPARTMENT__CUSTOMER_CARE_MANAGER,
                                                           ) }
                                                    values %depts ],
                        statuses=> {
                                $SHIPMENT_STATUS__DISPATCHED    => {
                                            can     => [ 'Returns', 'Lost Shipment' ],
                                        },
                            },
                    },
                'Stock Control'    => {
                        depts   => [ grep { number_in_list( $_->id, $DEPARTMENT__STOCK_CONTROL ) } values %depts ],
                        statuses=> {
                                $SHIPMENT_STATUS__DISPATCHED    => {
                                            can_not => [ 'Returns', 'Lost Shipment' ],
                                        },
                            },
                    },
                'Distribution'  => {
                        depts   => [ grep { number_in_list( $_->id, $DEPARTMENT__DISTRIBUTION_MANAGEMENT ) } values %depts ],
                        statuses=> {
                                $SHIPMENT_STATUS__DISPATCHED    => {
                                            can     => [ 'Returns' ],
                                            can_not => [ 'Lost Shipment' ],
                                        },
                            },
                    },

                'Customer Care Manager' => {
                        depts   => [ grep { number_in_list( $_->id, $DEPARTMENT__CUSTOMER_CARE_MANAGER ) } values %depts ],
                        statuses=> {
                                $SHIPMENT_STATUS__PROCESSING    => {
                                            can     => [ 'Amend Pricing' ],
                                        },
                                $SHIPMENT_STATUS__DISPATCHED    => {
                                            can     => [ 'Create Credit/Debit' ],
                                        },
                            },
                    },
                'Shipping Manager' => {
                        depts   => [ grep { number_in_list( $_->id, $DEPARTMENT__SHIPPING_MANAGER ) } values %depts ],
                        statuses=> {
                                $SHIPMENT_STATUS__DISPATCHED    => {
                                            can     => [ 'Create Credit/Debit' ],
                                        },
                            },
                    },
                'Distribution Manager' => {
                        depts   => [ grep { number_in_list( $_->id, $DEPARTMENT__DISTRIBUTION_MANAGEMENT, ) } values %depts ],
                        statuses=> {
                                $SHIPMENT_STATUS__DISPATCHED    => {
                                            can     => [ 'Create Shipment' ],
                                        },
                            },
                    },
            );

        foreach my $label ( sort keys %tests ) {
            note "TESTING: $label";

            my $test    = $tests{ $label };

            foreach my $dept ( @{ $test->{depts} } ) {
                note "Department: ".$dept->department;

                $framework->login_with_permissions( {
                    perms => {
                        # always have these
                        $AUTHORISATION_LEVEL__OPERATOR => [
                            'Customer Care/Customer Search',
                            'Customer Care/Order Search',
                        ],
                        ( $test->{permisions} ? %{ $test->{permisions} } : () ),
                    },
                    dept => $dept->department,
                } );

                foreach my $status_id ( sort keys %{ $test->{statuses} } ) {
                    my $status      = $statuses{ $status_id };
                    my $status_tests= $test->{statuses}{ $status_id };

                    note "with Shipment Status: ".$status->status;
                    $shipment->update_status( $status_id, $APPLICATION_OPERATOR_ID );

                    # get the Order View page
                    $framework->flow_mech__customercare__orderview( $order->id );

                    if ( exists $status_tests->{can} ) {
                        foreach my $link ( @{ $status_tests->{can} } ) {
                            ok( $mech->find_link( text_regex => qr/$link/ ), "Found menu option: $link" );
                        }
                    }
                    if ( exists $status_tests->{can_not} ) {
                        foreach my $link ( @{ $status_tests->{can_not} } ) {
                            ok( !$mech->find_link( text_regex => qr/$link/ ), "NOT Found menu option: $link" );
                        }
                    }
                    if ( exists $status_tests->{follow_links} ) {
                        foreach my $link ( @{ $status_tests->{follow_links} } ) {
                            $mech->get_ok( $link, "Followed '${link}'" );
                            $mech->no_feedback_error_ok();
                            $framework->flow_mech__customercare__orderview( $order->id );
                        }
                    }
                }
            }
        }

    };

    return;
}

=head2 _test_release_exchange_button

    _test_release_exchange_button( $schema, $xt_domain_returns_object, $ok_to_do_flag );

Will test that the 'Release Exchange' button can be seen by the Relevant Departments &
that it works when clicked on.

=cut

sub _test_release_exchange_button {
    my ( $schema, $domain, $oktodo )     = @_;

    SKIP: {
        skip "_test_release_exchange_button", 1         if ( !$oktodo );

        note "TESTING Release Exchange Button";

        my $framework   = _setup_framework_and_login();

        my $orddetails  = $framework->flow_db__fulfilment__create_order(
                                        channel => $framework->channel,
                                        products => 1,
                                    );
        my $order       = $orddetails->{order_object};
        my $shipment    = $orddetails->{shipment_object};

        # the xPath to find the Release Button
        my $button_xpath    = '//form[starts-with(@id,"releaseExchange")]';

        # check when in the correct Department but with no Exchange
        # Shipment, then you can't see the Release Button
        Test::XTracker::Data->set_department( 'it.god', 'Distribution Management' );
        $framework->flow_mech__customercare__orderview( $order->id );
        my $node = $framework->mech->find_xpath( $button_xpath )->get_node;
        ok( !$node, "When in Correct Department but no Exchange Shipment, NO Release Button Shown" );

        # set-up the shipment for a Return and an Exchange
        $shipment->update( { shipment_status_id => $SHIPMENT_STATUS__DISPATCHED } );
        $shipment->shipment_items->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__DISPATCHED } );
        my $return          = _create_return( $domain, $shipment, 'Exchange' );
        my $exch_shipment   = $return->exchange_shipment;

        # get a list of departments which can and can't see the button
        my %depts       = map { $_->id => $_ } $schema->resultset('Public::Department')->all;
        # delete out the Allowed Departments from the hash
        my @depts_allow = map { delete $depts{ $_ } } (
                                                    $DEPARTMENT__CUSTOMER_CARE_MANAGER,
                                                    $DEPARTMENT__DISTRIBUTION_MANAGEMENT,
                                                );

        note "check Departments NOT Allowed to see the Button";
        foreach my $dept ( values %depts ) {
            note "Department: " . $dept->department;
            Test::XTracker::Data->set_department( 'it.god', $dept->department );
            $framework->flow_mech__customercare__orderview( $order->id );
            $node   = $framework->mech->find_xpath( $button_xpath )->get_node;
            ok( !$node, "CAN'T See Button" );
        }

        note "check every Departments ALLOWED to see the Button";
        foreach my $dept ( @depts_allow ) {
            note "Department: ". $dept->department;
            my $ship_status = $exch_shipment->shipment_status_id;
            Test::XTracker::Data->set_department( 'it.god', $dept->department );
            $framework->flow_mech__customercare__orderview( $order->id );
            $node   = $framework->mech->find_xpath( $button_xpath )->get_node;
            ok( ref( $node ), "CAN See Button" );
            # now check that the Release Button works
            $framework->flow_mech__customercare__release_exchange_shipment( $exch_shipment->id );
            like( $framework->mech->app_status_message(), qr/Exchange shipment released for processing/i,
                                        "Release Success Message Shown" );
            cmp_ok( $exch_shipment->discard_changes->shipment_status_id, '==', $SHIPMENT_STATUS__PROCESSING,
                                        "Exchange Shipment Status is now 'Processing'" );
            # Restore 'Hold' Status for next Iteration
            $exch_shipment->update( { shipment_status_id => $ship_status } );
        }
    };

    return;
}


=head2 _test_inthebox_marketing_promotion

    _test_inthebox_marketing_promotion( $schema, $ok_to_do_flag );

Tests that any In The Box Marketing Promotions linked to an Order are
shown in the 'Marketing Promotion' section of the Order View page.

=cut

sub _test_inthebox_marketing_promotion {
    my ( $schema, $oktodo )     = @_;

    SKIP: {
        skip "_test_inthebox_marketing_promotion", 1       if ( !$oktodo );

        note "TESTING Order View Page list Marketing Promotions";
        my $framework   = _setup_framework_and_login();
        my $now         = $schema->db_now;

        my $orddetails  = $framework->flow_db__fulfilment__create_order(
                                        channel => $framework->channel,
                                        products => 1,
                                    );
        my $order       = $orddetails->{order_object};

        my $promotion   = Test::XTracker::Data::MarketingPromotion->create_marketing_promotion( {
                                                title       => "TEST Promotion Title " . $$,
                                                channel_id  => $framework->channel->id,
                                                start_date  => $now,
                                                end_date    => $now,
                                                message     => "Instruction message - test",
                                        } )->[0];

        $order->create_related( 'link_orders__marketing_promotions', {
            marketing_promotion_id =>  $promotion->id,
        } );

        #check order view page for promotion listing
        $framework->flow_mech__customercare__orderview( $order->id );
        my $data    = $framework->mech->as_data->{meta_data};

        my $expected = {
            'Promotion Title'   => "TEST Promotion Title " . $$,
            'End Date'          => $now->dmy,
            'Start Date'        => $now->dmy,
        };
        is_deeply($data->{'marketing_promotion'}[0], $expected, ' Marketing Promotion is listed');

        # unlink the promotion and check order view page does not list this promotion
        $promotion->link_orders__marketing_promotions->delete;

        $framework->flow_mech__customercare__orderview( $order->id );
        $data    = $framework->mech->as_data->{meta_data};
        ok( !defined $data->{'marketing_promotion'}, 'Marketing Promotion is NOT listed' );



    };

    return;
}

=head2 _test_language_preference

    _test_language_preference( $schema, $ok_to_do_flag );

Tests that the Customer's Language Preference is shown on the Order View page.

=cut

sub _test_language_preference {
    my ( $schema, $oktodo )     = @_;

    SKIP: {
        skip "_test_language_preference", 1       if ( !$oktodo );

        note "TESTING Order View Page with language preference";

        my $framework  = _setup_framework_and_login();

        my $orddetails = $framework->flow_db__fulfilment__create_order(
                                        channel => $framework->channel,
                                        products => 1,
                                    );
        my $order      = $orddetails->{order_object};
        my $customer   = $order->customer;

        if ($customer->customer_attribute) {
            $customer->customer_attribute->update({
                language_preference_id => undef
            });
            $customer->customer_attribute->discard_changes;
        }

        $framework->flow_mech__customercare__orderview( $order->id );
        my $data    = $framework->mech->as_data->{meta_data};

        # Check for default
        my $default_language  = $schema->resultset('Public::Language')->get_default_language_preference;
        isa_ok($default_language, 'XTracker::Schema::Result::Public::Language');
        is($data->{'Order Details'}{'Language Preference'}, $default_language->description.' (default)', 'default is displayed correctly');

        # Check all languages
        my @languages = $schema->resultset('Public::Language')->search()->all;

        foreach my $language (@languages) {
            isa_ok($language, 'XTracker::Schema::Result::Public::Language');

            $customer->set_language_preference($language->code);

            $framework->flow_mech__customercare__orderview( $order->id );
            my $data    = $framework->mech->as_data->{meta_data};
            is($data->{'Order Details'}{'Language Preference'}, $language->description, $language->description.' is displayed correctly');
        }

    }

    return;
}

=head2 _test_app_source

    _test_app_source( $schema, $ok_to_do_flag );

Tests the App Source & Version used for an Order are shown on the Order View page.

=cut

sub _test_app_source {
    my ( $schema, $oktodo )     = @_;

    my $app_name   = "App";
    my $app_ver    = "1.0";
    my $app_string = $app_name.' '.$app_ver;

    SKIP: {
        skip "_test_language_preference", 1       if ( !$oktodo );

        note "TESTING Order View Page with App Source";

        my $framework  = _setup_framework_and_login();

        my $orddetails = $framework->flow_db__fulfilment__create_order(
                                        channel => $framework->channel,
                                        products => 1,
                                    );
        my $order      = $orddetails->{order_object};

        $schema->resultset('Public::OrderAttribute')->create({
            orders_id           => $order->id,
            source_app_name    => $app_name,
            source_app_version => $app_ver
        });
        $order->discard_changes;

        $framework->flow_mech__customercare__orderview( $order->id );
        my $data    = $framework->mech->as_data->{meta_data};

        # Check for default
        is($data->{'Order Details'}{'App Source'}, $app_string, 'App string is correct');


    }

    return;
}

#-----------------------------------------------------------------

=head2 _check_routing_infomation_table

    _check_routing_infomation_table(
        $table_on_page,
        $expected_table,
        $return_or_shipment_prefix
    );

Test Helper that tests that what is in the 'Routing Information'
tables is what is expected, row by row.

=cut

sub _check_routing_infomation_table {
    my ( $table, $expected, $prefix )   = @_;

    cmp_ok( @{ $table }, '==', @{ $expected }, "Correct number for Rows: ".scalar @{ $expected } );
    foreach my $idx ( 0..$#{ $expected } ) {
        foreach my $column ( sort keys %{ $expected->[ $idx ] } ) {
            my $value   = $expected->[ $idx ]{ $column };
            if ( $column eq 'Driver' ) {
                $value  = (
                            # 'undef' means completely empty - no prefix
                            defined $value
                            # make it specific by adding the Prefix to it so that
                            # it can be differentiated from other tables on the page
                            ?  $value  = $prefix . $value
                            # if it was 'undef' make it an empty string
                            # to prevent warnings from being thrown
                            : ""
                          );
            }
            # check the column
            (
                ref( $value )       # assume 'Regex'
                ? like( $table->[ $idx ]{ $column }, qr/$value/, "Row ".($idx+1).", Column '$column' as expected: $value" )
                : is( $table->[ $idx ]{ $column }, $value, "Row ".($idx+1).", Column '$column' as expected: $value" )
            );
        }
        _check_row_attributes( $expected->[ $idx ], $table->[ $idx ] );
    }
}

=head2 _add_schedule_records

    _add_schedule_records(
        $dbic_shipment_or_return,
        $date_to_use,
        $shipment_or_return_prefix,
        $which_route_monkey_process_to_stop_at,
    );

Helper for creating 'routing_schedule' records for either a Shipment or a Return.
Used to generate records that would be created by importing Route Monkey files.

=cut

sub _add_schedule_records {
    my ( $base_rec, $date, $prefix, $stopat )   = @_;

    my $nextday = $date->clone->add( days => 1 );

    my $link_tab;
    my $type_id;
    my %status_ids;
    if ( ref( $base_rec ) =~ m/Public::Shipment/ ) {
        $type_id    = $ROUTING_SCHEDULE_TYPE__DELIVERY;
        %status_ids = (
                success => $ROUTING_SCHEDULE_STATUS__SHIPMENT_DELIVERED,
                failed  => $ROUTING_SCHEDULE_STATUS__SHIPMENT_UNDELIVERED,
            );
        $link_tab   = 'link_routing_schedule__shipments';
    }
    else {
        $type_id    = $ROUTING_SCHEDULE_TYPE__COLLECTION;
        %status_ids = (
                success => $ROUTING_SCHEDULE_STATUS__SHIPMENT_COLLECTED,
                failed  => $ROUTING_SCHEDULE_STATUS__SHIPMENT_UNCOLLECTED,
            );
        $link_tab   = 'link_routing_schedule__returns';
    }

    my $extid   = 0;

    my $routshed_rs = $base_rec->result_source->schema->resultset('Public::RoutingSchedule');
    my @rout_sheds;

    # this sets up the scenario of:
    #   Scheduled, Re-Schedule, Failed, Scheduled, Success
    #   it adds the $prefix to each Driver so as to make it specific to the context
    push @rout_sheds, $routshed_rs->create( {
                                    routing_schedule_type_id    => $type_id,
                                    routing_schedule_status_id  => $ROUTING_SCHEDULE_STATUS__SCHEDULED,
                                    external_id                 => ++$extid,
                                    task_window_date            => $date->ymd,
                                    task_window                 => '15:30 to 17:00',
                                    driver                      => "${prefix}Bill",
                                    run_number                  => 34,
                                    run_order_number            => 5,
                                    signatory                   => 'should not see Signature',
                                    undelivered_notes           => 'should not see Undelivered Notes',
                            } );
    push @rout_sheds, $routshed_rs->create( {
                                    routing_schedule_type_id    => $type_id,
                                    routing_schedule_status_id  => $ROUTING_SCHEDULE_STATUS__RE_DASH_SCHEDULED,
                                    external_id                 => $extid,
                                    task_window_date            => $date->ymd,
                                    driver                      => $prefix,
                                    run_number                  => 34,
                                    run_order_number            => 5,
                                    signatory                   => 'should not see Signature',
                                    undelivered_notes           => 'should not see Undelivered Notes',
                            } );
    push @rout_sheds, $routshed_rs->create( {
                                    routing_schedule_type_id    => $type_id,
                                    routing_schedule_status_id  => $ROUTING_SCHEDULE_STATUS__SCHEDULED,
                                    external_id                 => ++$extid,
                                    task_window_date            => $date->ymd,
                                    task_window                 => '18:00 to 20:30',
                                    driver                      => "${prefix}Bill",
                                    run_number                  => 37,
                                    run_order_number            => 3,
                                    signatory                   => 'should not see Signature',
                                    undelivered_notes           => 'should not see Undelivered Notes',
                            } );
    push @rout_sheds, $routshed_rs->create( {
                                    routing_schedule_type_id    => $type_id,
                                    routing_schedule_status_id  => $status_ids{failed},
                                    external_id                 => $extid,
                                    undelivered_notes           => 'There was no <b>Answer</b>',
                                    signatory                   => 'should not see Signature',
                            } );
    push @rout_sheds, $routshed_rs->create( {
                                    routing_schedule_type_id    => $type_id,
                                    routing_schedule_status_id  => $ROUTING_SCHEDULE_STATUS__RE_DASH_SCHEDULED,
                                    external_id                 => $extid,
                                    task_window_date            => $nextday->ymd,
                                    run_number                  => 37,
                                    run_order_number            => 3,
                                    driver                      => $prefix,
                                    signatory                   => 'should not see Signature',
                                    undelivered_notes           => 'should not see Undelivered Notes',
                            } );
    if ( !$stopat || $stopat ne 'reschedule' ) {
        push @rout_sheds, $routshed_rs->create( {
                                        routing_schedule_type_id    => $type_id,
                                        routing_schedule_status_id  => $ROUTING_SCHEDULE_STATUS__SCHEDULED,
                                        external_id                 => ++$extid,
                                        task_window_date            => $nextday->ymd,
                                        task_window                 => '10:00 to 12:00',
                                        driver                      => "${prefix}<b>Sally&Bob</b>",
                                        run_number                  => 42,
                                        run_order_number            => 7,
                                        signatory                   => 'should not see Signature',
                                        undelivered_notes           => 'should not see Undelivered Notes',
                                } );
        push @rout_sheds, $routshed_rs->create( {
                                        routing_schedule_type_id    => $type_id,
                                        routing_schedule_status_id  => $status_ids{success},
                                        external_id                 => $extid,
                                        signatory                   => '<b>Claire</b>',
                                        signature_time              => $nextday,
                                        undelivered_notes           => 'should not see Undelivered Notes',
                                } );
    }

    # now assign them to the base record
    foreach my $rec ( @rout_sheds ) {
        $base_rec->create_related( $link_tab, { routing_schedule_id => $rec->id } );
    }

    return;
}

=head2 _create_premier_order

    $hash_ref = _create_premier_order( $framework );

Helper to create a Premier Order.

=cut

sub _create_premier_order {
    my $framework   = shift;

    my $orddetails  = $framework->flow_db__fulfilment__create_order(
                                            channel => $framework->channel,
                                            products => 1,
                                        );
    my $shipment    = $orddetails->{shipment_object};

    my $ship_acc_rs = $schema->resultset('Public::ShippingAccount');
    my $prem_route  = $schema->resultset('Public::PremierRouting')
                                ->search( { description => 'Within business hours' } )
                                    ->first;

    # make it a Premier Shipment
    $shipment->update( {
                        shipment_type_id        => $SHIPMENT_TYPE__PREMIER,
                        shipping_account_id     => $ship_acc_rs->find_premier( { channel => $framework->channel } )->id,
                        premier_routing_id      => $prem_route->id,
                    } );
    $shipment->shipment_address->update( {
                                        postcode    => Test::XTracker::Data->find_prem_postcode( $framework->channel->id )->postcode,
                                        country     => config_var( 'DistributionCentre', 'country' ),
                                    } );

    $orddetails->{order_object}->discard_changes;
    $orddetails->{shipment_object}->discard_changes;

    note "Order Nr/Id: " . $orddetails->{order_object}->order_nr."/".$orddetails->{order_object}->id;
    note "Shipment Id: " . $orddetails->{shipment_object}->id;

    return $orddetails;
}

=head2 _create_return

    $dbic_return = _create_return( $xt_return_domain, $dbic_shipment, $return_or_exchange_type );

Helper to create a return for a Shipment.

=cut

sub _create_return {
    my ( $domain, $shipment, $type )    = @_;

    $type   ||= 'Return';

    my $ship_item   = $shipment->shipment_items->first;
    my $return      = $domain->create( {
                        operator_id => $APPLICATION_OPERATOR_ID,
                        shipment_id => $shipment->id,
                        pickup => 0,
                        refund_type_id => 0,
                        return_items => {
                                $ship_item->id => {
                                    type        => $type,
                                    reason_id   => $CUSTOMER_ISSUE_TYPE__7__TOO_SMALL,
                                    ( $type eq 'Exchange' ? ( exchange_variant => $ship_item->variant_id ) : () ),
                                },
                            }
                    } );

    return $return->discard_changes;
}

=head2 _check_row_attributes

    _check_row_attributes( $test_options, $table_row );

Test Helper that checks the Row attributes such as the 'class' for a
given Node.

=cut

sub _check_row_attributes {
    my ( $test, $row )  = @_;

    # get the xpath node for the row
    my $row_node    = $row->{raw};
    # check row highlighting, just use the first column should be fine
    my $td  = $row_node->find_xpath('td')->get_node(1);
    if ( $test->{Outcome} eq 'Success' ) {
        like( $td->attr('class'), qr/highlight/, "Found Highlighting for 'Success' Row" );
    }
    else {
        is( $td->attr('class'), undef, "Found NO Highlighting for Row, Outcome: " . $test->{Outcome} );
    }

    return;
}

=head2 _setup_framework_and_login

    $framework = _setup_framework_and_login();

Helper to set up the Framework required and Log In.

=cut

sub _setup_framework_and_login {

    my $framework   = Test::XT::Flow->new_with_traits(
        traits => [
            'Test::XT::Flow::Fulfilment',
            'Test::XT::Flow::CustomerCare',
            'Test::XT::Data::Channel',
        ],
    );
    my $channel = $framework->channel( Test::XTracker::Data->channel_for_nap );
    $framework->mech->channel( $channel );

    Test::XTracker::Data->set_department( 'it.god', 'Customer Care' );
    $framework->login_with_permissions( {
        perms => {
            $AUTHORISATION_LEVEL__OPERATOR => [
                'Customer Care/Customer Search',
                'Customer Care/Order Search',
            ],
        }
    } );

    return $framework;
}


=head2 _get_recent_shipment

    $dbic_shipment = _get_recent_shipment( $dbic_order, 'Re-Shipment' or 'Replacement' );

Helper that returns the most recent 'Re-Shipment' or 'Replacement' shipment for an Order.

=cut

sub _get_recent_shipment{
    my ( $order, $type )    = @_;

    my %type_to_class   = (
            'Re-Shipment'   => $SHIPMENT_CLASS__RE_DASH_SHIPMENT,
            'Replacement'   => $SHIPMENT_CLASS__REPLACEMENT,
        );

    return $order->shipments
                    ->search( {
                                shipment_class_id => $type_to_class{ $type },
                            },
                            {
                                order_by => 'id DESC',
                            } )->first;
}

=head2 _create_reservations

    $dbic_reservation = _create_reservations( $dbic_channel, $dbic_variant, $dbic_customer );

Helper to create a Reservation for a Customer.

=cut

sub _create_reservations {
    my ($channel, $variant, $customer )   = @_;

    my @reservations;

    # get the Current Max Ordering Id for this Variant's Reservations
    my $current_max_ordering    = $variant->reservations->get_column('ordering_id')->max() || 0;

     my $data = Test::XT::Flow->new_with_traits(
                      traits => [
                            'Test::XT::Data::ReservationSimple',
                        ],
                  );

      $data->customer( $customer )        if ( defined $customer );       # use the same Customer if asked to
      $data->channel( $channel );
      $data->variant( $variant );                             # make sure all reservations are for the same SKU

      my $reservation = $data->reservation;
      $reservation->update( { ordering_id => $current_max_ordering + 1 } );

      note "Customer Id/Nr: ".$reservation->customer->id."/".$reservation->customer->is_customer_number;


    return $reservation;
}


=head2 _test_check_pricing

    _test_check_pricing( $ok_to_do_flag );

Tests the 'Check Pricing' Left Hand Menu option on the Order View page.

Checks that Shipping Restrictions are shown when appropriate. Also checks
that the Email to the Customer at the bottom of the page has the right
Email Addresses and that there is a Subject & Content shown (doesn't check
what the Subject & Content is just that something is there) and that an
Email is logged when sent.

=cut

sub _test_check_pricing {
    my ( $oktodo ) = @_;

    SKIP: {

        skip "_test_check_pricing", 1 unless $oktodo;

        note "TESTING Check Pricing";

        my $framework = _setup_framework_and_login();
        my $mech      = $framework->mech;

        my $order_details = $framework->flow_db__fulfilment__create_order(
            channel => $framework->channel,
            products => 1,
        );
        my $order   = $order_details->{order_object};
        my $shipment= $order->get_standard_class_shipment;
        my $product = $order_details->{product_objects}->[0]->{product};
        my $sku     = $order_details->{product_objects}->[0]->{sku};

        $shipment->shipment_email_logs->delete;
        # update Shipping Charge to be ZERO so that there will be
        # a difference in price when a new destination is chosen
        # which will mean the Email Form is then shown
        $shipment->update( { shipping_charge => 0 } );

        isa_ok( $product, 'XTracker::Schema::Result::Public::Product' );
        isa_ok( $order, 'XTracker::Schema::Result::Public::Orders' );
        note 'Order Number: ' . $order->order_nr;

        my ( $country_pass, $country_fail ) = Test::XTracker::Data::Shipping
            ->get_restriction_countries_and_update_product( $product );

        # Get the order view page for this order.
        $mech->order_nr( $order->order_nr );
        $mech->order_view_url;

        # Get the pricing check page.
        $framework->flow_mech__customercare__check_pricing;

        # Test for failure.
        note 'Submitting edit address form with invalid country';
        $framework->flow_mech__customercare__check_pricing_submit_new_destination( {
            country => $country_fail->country,
        } );
        my $items   = $mech->as_data()->{item_list}{items};
        like( $items->[0]{restriction}, qr/Chinese origin product/i, 'Got correct restriction' );

        # Test for success.
        note 'Submitting edit address form with valid country';
        $framework->flow_mech__customercare__check_pricing_submit_new_destination( {
            country => $country_pass->country,
        } );
        my $pg_data = $mech->as_data();
        $items  = $pg_data->{item_list}{items};
        ok( !$items->[0]{restriction}, 'Got no restrictions' );


        note "check the Email Form";

        # the expected Email 'From' address
        my $from_address = customercare_email( $order->channel->business->config_section, {
            schema  => $framework->schema,
            locale  => $order->customer->locale,
        } );

        my $email_form  = $pg_data->{email_form};
        is( $email_form->{To}{input_value}, $order->email,
                                    "Order's Email address is used in the 'To' address: '" . $order->email . "'" );
        is( $email_form->{From}{input_value}, $from_address,
                                    "From address as Expected: '${from_address}'" );
        is( $email_form->{'Reply-To'}{input_value}, $from_address,
                                    "Reply-To address as Expected: '${from_address}'" );
        cmp_ok( length( $email_form->{'Subject'}{input_value} ), '>', 5,
                                    "Subject has a value in the form: '" . $email_form->{'Subject'}{input_value} . "'" );
        cmp_ok( length( $email_form->{'Email Text'}{value} ), '>', 5,
                                    "Email Text has a value in the form: '" . $email_form->{'Email Text'}{value} . "'" );
        is( $email_form->{'Email Text'}{input_name}, 'email_content_type',
                                    "Email Content Type hidden field is in the form" );
        cmp_ok( length( $email_form->{'Email Text'}{input_value} ), '>', 2,
                                    "Email Content Type has a value in the form: '" . $email_form->{'Email Text'}{input_value} . "'" );

        $framework->flow_mech__customercare__check_pricing_send_email();
        cmp_ok( $shipment->discard_changes->shipment_email_logs->count, '==', 1,
                                    "Shipment now has ONE Email Log record" );
        my $log = $shipment->shipment_email_logs->first;
        cmp_ok( $log->correspondence_templates_id, '==', $CORRESPONDENCE_TEMPLATES__REQUEST_PRICE_CHANGE_CONFIRMATION__1,
                                    "and the 'Request Price Change Confirmation' email has been Logged" );
    }

    return;

}

=head2 _test_returnable_icon

Tests that the correct Returnable Items are shown for the Shipment Items.

=cut

sub _test_returnable_icon {
    my ( $oktodo ) = @_;

    SKIP: {

        skip "_test_returnable_icon", 1 unless $oktodo;

        note "TESTING Returnable Icon for Shipment Items";

        # what 'alt' attribute should be for each state
        my %img_alt_mapping = (
            $SHIPMENT_ITEM_RETURNABLE_STATE__YES     => qr/Can Return this Item/i,
            $SHIPMENT_ITEM_RETURNABLE_STATE__NO      => qr/Can't Return this Item$/i,
            $SHIPMENT_ITEM_RETURNABLE_STATE__CC_ONLY => qr/Can't Return this Item using the Website only via CC/i,
        );

        my $framework = _setup_framework_and_login();
        my $mech      = $framework->mech;

        my $order_details = $framework->flow_db__fulfilment__create_order(
            channel => $framework->channel,
            products => 3,
        );
        my $order   = $order_details->{order_object};
        my $shipment= $order->get_standard_class_shipment;
        my @items   = $shipment->shipment_items->all;

        # update the Shipment Items with each Returnable State
        $items[0]->update( { returnable_state_id => $SHIPMENT_ITEM_RETURNABLE_STATE__YES } );
        $items[1]->update( { returnable_state_id => $SHIPMENT_ITEM_RETURNABLE_STATE__NO } );
        $items[2]->update( { returnable_state_id => $SHIPMENT_ITEM_RETURNABLE_STATE__CC_ONLY } );

        # Get the order view page for this order.
        $mech->order_nr( $order->order_nr );
        $mech->order_view_url;
        $mech->client_with_raw_rows(1);
        my $pg_ship_items = $mech->as_data()->{shipment_items};
        $mech->client_with_raw_rows(0);

        # check each item has the correct icon
        foreach my $item ( @items ) {
            my $returnable_state = $item->returnable_state->state;
            note "Checking SKU: '" . $item->get_sku . "' with Returnable State: '${returnable_state}'";

            # get the correct row on the page for this Item's SKU
            my ( $row ) = grep { $_->{SKU} eq $item->get_sku } @{ $pg_ship_items };

            # get the Returnable Icon which is the first IMG in the first Column
            my $icon = $row->{raw}->find_xpath('td[1]/div[@class="returnable_state_icon"]/img')->get_node(1);
            ok( defined $icon, "found a Returnable Icon" );

            # check it's the expected Icon
            my $got_alt    = $icon->attr('alt');
            my $expect_alt = $img_alt_mapping{ $item->returnable_state_id };
            like( $got_alt, qr/${expect_alt}/, "and is for the expected Returnable State" );
        }
    }

    return;

}

=head2 _test_shows_third_party_payment

If the Order was paid using a Third Party Payment Method such as PayPal
this test will check that a message saying that appears on the Order
View page.

=cut

sub _test_shows_third_party_payment {
    my ( $oktodo ) = @_;

    SKIP: {
        skip "_test_shows_third_party_payment", 1 unless $oktodo;

        note "TESTING Third Party Payment is Shown";

        my $framework = _setup_framework_and_login();
        my $mech      = $framework->mech;

        my $order_details = $framework->flow_db__fulfilment__create_order(
            channel  => $framework->channel,
            products => 1,
            create_renumerations => 1,
        );
        my $order = $order_details->{order_object};

        my $payment_methods     = Test::XTracker::Data->get_cc_and_third_party_payment_methods();
        my $credit_card_payment = $payment_methods->{credit_card};
        my $third_party_payment = $payment_methods->{third_party};

        my %tests = (
            "Paid using a Credit Card" => {
                setup => {
                    payment_method  => $credit_card_payment,
                },
                expect => {
                    no_message => 1,
                },
            },
            "Paid using a Third Party Payment" => {
                setup => {
                    payment_method  => $third_party_payment,
                },
                expect => {
                    message_shown => $third_party_payment->payment_method,
                },
            },
            "Paid using Store Credit with NO Payment" => {
                setup => {
                    no_payment => 1,
                },
                expect => {
                    no_message => 1,
                },
            },
        );

        # need these to create 'orders.payment' records
        my $psp_refs = Test::XTracker::Data->get_new_psp_refs();

        foreach my $label ( keys %tests ) {
            note "Testing: ${label}";
            my $test    = $tests{ $label };
            my $setup   = $test->{setup};
            my $expect  = $test->{expect};

            $order->discard_changes->payments->delete;
            Test::XTracker::Data->create_payment_for_order( $order, {
                %{ $psp_refs },
                payment_method => $setup->{payment_method},
            } ) unless ( $setup->{no_payment} );

            $framework->flow_mech__customercare__orderview( $order->id );
            my $pg_data = $mech->as_data()->{meta_data};

            if ( $expect->{no_message} ) {
                ok( !exists( $pg_data->{third_party_payment_message__for_order} ),
                            "NO Third Party Payment message shown in the Order Details section" );
                ok( !exists( $pg_data->{third_party_payment_message__for_payment} ),
                            "NO Third Party Payment message shown in the Payments section" );
            }
            else {
                like(
                    $pg_data->{third_party_payment_message__for_order},
                    qr/paid.*using.*$expect->{message_shown}/i,
                    "Third Party Payment message shown in Order Details section"
                );
                like(
                    $pg_data->{third_party_payment_message__for_payment},
                    qr/paid.*using.*$expect->{message_shown}/i,
                    "Third Party Payment message shown in the Payments section"
                );
            }
        }
    }

    return;
}

=head2 _test_shows_amq_order_status_button

Tests whether a button on the Order View page is shown and works that
can just send the general Order Status message for an Order over AMQ
to the Frontend.

=cut

sub _test_shows_amq_order_status_button {
    my ( $amq, $oktodo ) = @_;

    SKIP: {
        skip "_test_shows_amq_order_status_button", 1 unless $oktodo;

        note "TESTING AMQ Order Status Button";

        my $producer_config = config_var('Producer::Orders::Update', 'routes_map');

        my $framework = _setup_framework_and_login();
        my $mech      = $framework->mech;

        my $order_details = $framework->flow_db__fulfilment__create_order(
            channel  => $framework->channel,
            products => 1,
            create_renumerations => 1,
        );
        my $order = $order_details->{order_object};


        note "without the appropriate Role shouldn't be-able to see the Button";
        $mech->get_ok('/Logout');
        $mech->clear_session;
        $framework->login_with_permissions( {
            roles => {
                names => [ qw(
                    app_canSearchCustomers
                ) ],
            },
        } );
        my $session = $mech->session->get_session;

        $framework->flow_mech__customercare__orderview( $order->id );
        my $pg_data = $mech->as_data->{meta_data};
        ok( !exists( $pg_data->{order_status_message_button} ),
                            "Order Update Status Button not Found on Page" );


        note "now give the appropriate Role and the Button should be shown";
        $mech->session->replace_acl_roles( [ qw(
            app_canSearchCustomers
            app_canSendOrderStatusMessage
        ) ] );

        $framework->flow_mech__customercare__orderview( $order->id );
        $pg_data = $mech->as_data->{meta_data};
        ok( exists( $pg_data->{order_status_message_button} ),
                            "Order Update Status Button Shown on Page" );

        # now click the button and check the message queue
        my $queue_name = $producer_config->{ $order->channel->web_name };
        $amq->clear_destination( $queue_name );

        $framework->flow_mech__customercare__orderview__send_order_status_submit();
        $amq->assert_messages( {
            destination   => $queue_name,
            filter_header => superhashof( {
                type        => 'OrderMessage',
                JMSXGroupID => $order->channel->lc_web_name,
            } ),
            assert_body   => superhashof( {
                orderNumber => $order->order_nr,
            } ),
        }, "Found Order Status Message on Queue: '${queue_name}'" );

        $amq->clear_destination( $queue_name );
    }

    return;
}

=head2 _test_order_view_page_does_not_crash_with_invalid_order_id

    _test_order_view_page_does_not_crash_with_invalid_order_id( $ok_to_do_flag );

Tests that the Order View page doesn't crash when an Invalid Order Id is used.

=cut

sub _test_order_view_page_does_not_crash_with_invalid_order_id {
    my ( $oktodo )     = @_;

    SKIP: {
        skip "_test_order_view_page_does_not_crash_with_invalid_order_id", 1 if ( !$oktodo );

        my $framework   = Test::XT::Flow->new_with_traits(
                          traits => [
                            'Test::XT::Flow::CustomerCare',
                             'Test::XT::Data::Channel',
                          ],
                        );
        Test::XTracker::Data->set_department( 'it.god', 'Distribution Management' );

        $framework->login_with_permissions( {
            perms => {
                $AUTHORISATION_LEVEL__OPERATOR => [
                    'Customer Care/Customer Search',
                    'Customer Care/Order Search',
                ]
            }
        } );

        #got to order view page
        lives_ok( sub {
            $framework->flow_mech__customercare__orderview( '0' );
        }, "Calling OrderView without a valid order_id does not crash app" );
    }
}
