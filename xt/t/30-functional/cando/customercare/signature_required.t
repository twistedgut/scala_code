#!/usr/bin/env perl

use NAP::policy "tt", 'test';

use FindBin::libs;

=head1 NAME

signature_required.t - Tests the Delivery Signature Opt Out Flag for an Order

=head1 DESCRIPTION

This tests the Order View page to make sure it displays the 'Delivery Signature'
flag and also tests editing it. Also tests the Order Status Log page to make
sure the Signature Change Logs are displayed.

Although this is a DC2 feature it tests DC1 & DC3 that it is NOT being supported.

NOTE: Setting the Flag to TRUE means the Order requires signing for which is how
it's always been, setting the Flag to FALSE means NO Signature is required and
is the new functionality.

Tests:

    * Re-Shipment - Signature Flag FALSE should be Copied
    * Re-Shipment - Signature Flag TRUE should be Copied
    * Re-Shipment - Signature Flag NULL should be Copied
    * Replacement - Signature Flag should be TRUE regardless

#TAGS orderview loops checkruncondition fulfilment cando

=cut



use Data::Dump  qw( pp );

use Test::XTracker::Data;
use Test::XTracker::RunCondition export => [ qw( $distribution_centre ) ];
use Test::XT::Flow;

use XTracker::Config::Local             qw( config_var sys_config_var has_delivery_signature_optout );
use XTracker::Constants::FromDB         qw(
                                            :authorisation_level
                                            :customer_category
                                            :department
                                            :order_status
                                            :shipment_item_status
                                            :shipment_class
                                            :shipment_status
                                        );
use XTracker::Database::Department      qw( customer_care_department_group );


my $schema  = Test::XTracker::Data->get_schema;
isa_ok( $schema, "XTracker::Schema" );

#--------- Tests ----------------------------------------------
test_order_view( $schema, 1 );
test_re_or_replacement_shipments( $schema, 1 );
#--------------------------------------------------------------

done_testing;

#-----------------------------------------------------------------

=head1 METHODS

=head2 test_order_view

    test_order_view( $schema, $ok_to_do_flag );

This tests to make sure the 'Order View' page displays the
Signature Required flag and can edit it.

Does:
    * Turn the Flag On/off
    * Makes sure only certain Departments can Edit the flag and that
      the rest can not
    * The flag can't be edited once the Shipment has been Packed
    * When setting the Flag to FALSE check Order goes on Credit Hold
      if its value is over a threshold
    * When setting the Flag to FALSE when already FALSE won't do
      anything including putting the Order on Credit Hold
    * Check Signature Change Logs are updated

=cut

sub test_order_view {
    my ( $schema, $oktodo )     = @_;

    SKIP: {
        skip "test_order_view", 1      if ( !$oktodo );

        note "TESTING Order View Page - with Signature Required";

        # this is what appears in the Page Data HASH for the Signature Required field
        my $label       = 'Signature upon Delivery Required';
        # get local currency
        my $currency    = $schema->resultset('Public::Currency')
                                    ->search( { currency => config_var('Currency', 'local_currency_code') } )
                                        ->first;

        my $framework   = Test::XT::Flow->new_with_traits(
            traits => [
                'Test::XT::Flow::Fulfilment',
                'Test::XT::Flow::CustomerCare',
                'Test::XT::Data::Channel',
            ],
        );

        my %departments = map { $_->id => $_ } $schema->resultset('Public::Department')->all;

        my $orddetails  = $framework->flow_db__fulfilment__create_order(
                                                channel => $framework->channel,
                                                products => 1,
                                            );
        my $order       = $orddetails->{order_object};
        my $shipment    = $orddetails->{shipment_object};
        my $shipment_id = $shipment->id;
        $order->update( { currency_id => $currency->id } );
        $order->customer->update( { category_id => $CUSTOMER_CATEGORY__NONE } );
        $shipment->update( { signature_required => 1 } );   # turn the flag on

        # get the threshold
        my $threshold   = sys_config_var( $schema, 'No_Delivery_Signature_Credit_Hold_Threshold', $order->currency->currency, $order->channel_id ) //100000;
        $shipment->shipment_items->update( {
                                            unit_price  => ( $threshold / 4 ),      # set the shipment value to be
                                            tax         => 0,                       # a lot lower than the threshold
                                            duty        => 0,
                                        } );


        Test::XTracker::Data->set_department( 'it.god', 'Finance' );
        $framework->login_with_permissions( {
            perms => {
                $AUTHORISATION_LEVEL__READ_ONLY => [
                    'Customer Care/Customer Search',
                ]
            }
        } );
        $framework->flow_mech__customercare__orderview( $order->id );
        my $details = $framework->mech->as_data->{meta_data}{'Shipment Details'};
        ok( exists( $details->{ $label } ), "Delivery Field is present in the Page" );
        cmp_ok( $details->{ $label }{value}, '==', 1, "Value shown is TRUE" );
        cmp_ok( $details->{ $label }{editable}, '==', 1, "Read-Only Auth Level and above allows it to be Editable" );

        note "test different Departments Can & Can't edit the Field";
        my @cc_depts    = customer_care_department_group();     # get those Departments in the Customer Care Group
        my @can_edit    = map { delete $departments{ $_ } } ( $DEPARTMENT__FINANCE,
                                                              $DEPARTMENT__SHIPPING,
                                                              $DEPARTMENT__SHIPPING_MANAGER,
                                                              @cc_depts,
                                                          );
        my @cant_edit   = values %departments;

        # can't edit field
        foreach my $dept ( @cant_edit ) {
            Test::XTracker::Data->set_department( 'it.god', $dept->department );
            $framework->flow_mech__customercare__orderview( $order->id );
            $details    = $framework->mech->as_data->{meta_data}{'Shipment Details'}{ $label };
            cmp_ok( $details->{editable}, '==', 0, "Department: '".$dept->department."' CAN'T Edit Flag" );
        }
        # can edit field
        foreach my $dept ( @can_edit ) {
            Test::XTracker::Data->set_department( 'it.god', $dept->department );
            $framework->flow_mech__customercare__orderview( $order->id );
            $details    = $framework->mech->as_data->{meta_data}{'Shipment Details'}{ $label };
            cmp_ok( $details->{editable}, '==', 1, "Department: '".$dept->department."' CAN Edit Flag" );
        }



        if( $distribution_centre eq 'DC2' ) {
            note "turn the Flag Off & On";

            # turn off the flag
            $framework->flow_mech__customercare_orderview_delivery_signature_submit( $shipment->id, 'no' );
            $framework->mech->has_feedback_success_ok( qr{Shipment: $shipment_id, 'Signature upon Delivery' flag has been Updated to: No},
                                                                "Got Success Message for 'No'" );
            cmp_ok( $shipment->discard_changes->signature_required, '==', 0, "Turn Off - Signature Required Flag is now FALSE" );
            cmp_ok( $shipment->shipment_status_id, '==', $SHIPMENT_STATUS__PROCESSING, "Shipment Status is Still 'Processing'" );
            cmp_ok( $order->discard_changes->order_status_id, '==', $ORDER_STATUS__ACCEPTED, "Order Status is Still 'Accepted'" );

            # turn on the flag
            $framework->flow_mech__customercare_orderview_delivery_signature_submit( $shipment->id, 'yes' );
            $framework->mech->has_feedback_success_ok( qr{Shipment: $shipment_id, 'Signature upon Delivery' flag has been Updated to: Yes},
                                                                "Got Success Message for 'Yes'" );
            cmp_ok( $shipment->discard_changes->signature_required, '==', 1, "Turn On - Signature Required Flag is now TRUE" );

            # update the Shipment Item Status Log so the flag shouldn't be editatable
            $shipment->shipment_items->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PACKED } );
            $framework->errors_are_fatal(0);
            $framework->flow_mech__customercare_orderview_delivery_signature_submit( $shipment->id, 'no' );
            $framework->errors_are_fatal(1);
            $framework->mech->has_feedback_error_ok( qr{Couldn't update 'Signature upon Delivery' flag because the flag can't be updated any more},
                                                                "Got 'Couldnt Update' Error Message" );
            cmp_ok( $shipment->discard_changes->signature_required, '==', 1, "Turn On - Signature Required Flag is STILL TRUE" );

            note "now test the Shipment will be placed on Hold when editing the Field to be FALSE";
            # set-up the correct conditions

            $shipment->shipment_items->update( { unit_price => $threshold + 10, shipment_item_status_id => $SHIPMENT_ITEM_STATUS__NEW } );
            $framework->flow_mech__customercare__orderview( $order->id )        # re-fresh the page effectively
                        ->flow_mech__customercare_orderview_delivery_signature_submit( $shipment->id, 'no' );
            cmp_ok( $shipment->discard_changes->signature_required, '==', 0, "Signature Required Flag is now FALSE" );
            cmp_ok( $shipment->shipment_status_id, '==', $SHIPMENT_STATUS__FINANCE_HOLD, "Shipment Status is now 'Finance Hold'" );
            cmp_ok( $order->discard_changes->order_status_id, '==', $ORDER_STATUS__CREDIT_HOLD, "Order Status is now 'Credit Hold'" );

            note "test that Setting the Signature to FALSE when it already is won't put it on Credit Hold - or do anything";
            # switch back to being a ok
            $shipment->update( { shipment_status_id => $SHIPMENT_STATUS__PROCESSING } );
            $order->update( { order_status_id => $ORDER_STATUS__ACCEPTED } );
            $framework->flow_mech__customercare__orderview( $order->id )        # re-fresh the page effectively
                        ->flow_mech__customercare_orderview_delivery_signature_submit( $shipment->id, 'no' );
            $framework->mech->_test_feedback_element( 'display_msg', 1, '', "No Success Message Given" );
            cmp_ok( $shipment->discard_changes->signature_required, '==', 0, "Signature Required Flag is Still FALSE" );
            cmp_ok( $shipment->shipment_status_id, '==', $SHIPMENT_STATUS__PROCESSING, "Shipment Status is Still 'Processing'" );
            cmp_ok( $order->discard_changes->order_status_id, '==', $ORDER_STATUS__ACCEPTED, "Order Status is Still 'Accepted'" );


            note "check the Signature Change logs";

            $framework->flow_mech__customercare__view_status_log;
            my $page_data   = $framework->mech->as_data()->{page_data};
            ok( exists( $page_data->{ $shipment_id } ), "Shipment Id Found on Status Log Page" );
            ok( exists( $page_data->{ $shipment_id }{delivery_signature_log} ), "Delivery Signature Log Found for Shipment" );
            my $log = $page_data->{ $shipment_id }{delivery_signature_log};
            cmp_ok( @{ $log }, '==', 3, "There are 3 Signature Logs" );
            is( $log->[0]{'New State'}, 'No', "First Log is for change to 'No'" );
            is( $log->[1]{'New State'}, 'Yes', "Second Log is for change to 'Yes'" );
            is( $log->[2]{'New State'}, 'No', "Third Log is for change to 'No'" );

            note "check the other logs";
            $log    = $page_data->{order_status_log};
            cmp_ok( grep( { $_->{Status} eq 'Credit Hold' } @{ $log } ), '==', 1, "Found one 'Credit Hold' Log in 'Order Status Log'" );
            $log    = $page_data->{ $shipment_id }{shipment_status_log};
            cmp_ok( grep( { $_->{Status} eq 'Finance Hold' } @{ $log } ), '==', 1, "Found one 'Finance Hold' Log in 'Shipment Status Log'" );
         } else {
            $shipment->update({ signature_required => 'f'});
            $framework->flow_mech__customercare__orderview( $order->id )        # re-fresh the page effectively
                      ->flow_mech__customercare_orderview_delivery_signature_submit( $shipment->id, 'yes' );
            cmp_ok( $shipment->discard_changes->signature_required, '==', 1, "Signature Required Flag is now TRUE" );

            $framework->errors_are_fatal(0);
            $framework->flow_mech__customercare_orderview_delivery_signature_submit( $shipment->id, 'no' );
            $framework->errors_are_fatal(1);
            $framework->mech->has_feedback_error_ok( qr{Couldn't update 'Signature upon Delivery' flag because the 'NO' option is not allowed},
                                                                "Got 'Couldnt Update' Error Message" );
         }
    };
}

=head2 test_re_or_replacement_shipments

    test_re_or_replacement_shipments( $schema, $ok_to_do_flag );

This tests that 'Re-Shipment' & 'Replacement' shipments
set-up the 'signature_flag' for the new shipment correctly
by making sure it sets the flag on the new Shipment to the
same as the Old except for Replacement Shipments which should
always be set to TRUE.

=cut

sub test_re_or_replacement_shipments {
    my ( $schema, $oktodo )     = @_;

    SKIP: {
        skip "test_re_or_replacement_shipments", 1      if ( !$oktodo );

        note "TESTING Replacement or Re-Shipment";

        # get local currency - to update the Order with to keep things proper
        my $currency    = $schema->resultset('Public::Currency')
                                    ->search( { currency => config_var('Currency', 'local_currency_code') } )
                                        ->first;

        my $framework   = Test::XT::Flow->new_with_traits(
            traits => [
                'Test::XT::Flow::Fulfilment',
                'Test::XT::Flow::CustomerCare',
                'Test::XT::Data::Channel',
            ],
        );

        Test::XTracker::Data->set_department( 'it.god', 'Distribution Management' );
        $framework->login_with_permissions( {
            perms => {
                $AUTHORISATION_LEVEL__OPERATOR => [
                    'Customer Care/Customer Search',
                ]
            }
        } );

        # set-up tests that shall be done
        my %tests   = (
                'Re-Shipment - Signature Flag FALSE should be Copied'   => {
                        shipment_type   => 'Re-Shipment',
                        expected_flag   => 0,
                        starting_value  => 0,
                    },
                'Re-Shipment - Signature Flag TRUE should be Copied'    => {
                        shipment_type   => 'Re-Shipment',
                        expected_flag   => 1,
                        starting_value  => 1,
                    },
                'Re-Shipment - Signature Flag NULL should be Copied'    => {
                        shipment_type   => 'Re-Shipment',
                        expected_flag   => undef,
                        starting_value  => undef,
                    },
                'Replacement - Signature Flag should be TRUE regardless'=> {
                        shipment_type   => 'Replacement',
                        expected_flag   => 1,
                        starting_value  => 0,
                    },
            );

        my $last_order;
        my $last_orig_shipment;
        my $last_new_shipment;

        foreach my $test_label ( sort keys %tests ) {
            note $test_label;
            my $test    = $tests{ $test_label };
            my $type    = $test->{shipment_type};

            my $orddetails  = $framework->flow_db__fulfilment__create_order(
                                                    channel => $framework->channel,
                                                    products => 1,
                                                );
            my $order       = $orddetails->{order_object};
            my $shipment    = $orddetails->{shipment_object};
            $order->update( { currency_id => $currency->id } );

            # set the Shipment & Shipment Items up for the test
            $shipment->update( { shipment_status_id => $SHIPMENT_STATUS__DISPATCHED, signature_required => $test->{starting_value} } );
            $shipment->shipment_items->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__DISPATCHED } );

            $framework->flow_mech__customercare__orderview( $order->id )
                        ->flow_mech__customercare__create_shipment
                            ->flow_mech__customercare__create_shipment_submit( $type )
                                ->flow_mech__customercare__create_shipment_item_submit( [ map { $_->id } $shipment->shipment_items->all ] )
                                    ->flow_mech__customercare__create_shipment_final_submit;

            # get the new shipment created
            my $new_shipment    = get_resent_shipment_of_type( $order, $type );
            isa_ok( $new_shipment, 'XTracker::Schema::Result::Public::Shipment', "New '$type' Shipment Created" );
            if ( defined $test->{expected_flag} ) {
                cmp_ok( $new_shipment->signature_required, '==', $test->{expected_flag},
                                                                    "New Shipment's 'signature_flag' as expected: $$test{expected_flag}" );
            }
            else {
                ok( !defined $new_shipment->signature_required, "New Shipment's 'signature_flag' as expected: undef" );
            }

            # use these for the next tests
            $last_order         = $order->discard_changes;
            $last_orig_shipment = $shipment->discard_changes;
            $last_new_shipment  = $new_shipment->discard_changes;
        }

        note "check that it's the Original Shipment's flag that's copied and not the most resent Shipment";
        # set the original shipment to be false
        $last_orig_shipment->update( { signature_required => 0 } );
        # set the latest shipment to be true and Dispatch it
        $last_new_shipment->update( { signature_required => 1, shipment_status_id => $SHIPMENT_STATUS__DISPATCHED } );
        $last_new_shipment->shipment_items->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__DISPATCHED } );

        # now create a 'Re-Shipment' for the Order and check the Original Signature Flag is used
        $framework->flow_mech__customercare__orderview( $last_order->id )
                    ->flow_mech__customercare__create_shipment
                        ->flow_mech__customercare__create_shipment_select_shipment( $last_new_shipment->id )
                            ->flow_mech__customercare__create_shipment_submit( 'Re-Shipment' )
                                ->flow_mech__customercare__create_shipment_item_submit( [ map { $_->id } $last_new_shipment->shipment_items->all ] )
                                    ->flow_mech__customercare__create_shipment_final_submit;
        # get the new Shipment record created
        my $latest_shipment = get_resent_shipment_of_type( $last_order->discard_changes, 'Re-Shipment' );
        cmp_ok( $latest_shipment->id, '>', $last_new_shipment->id, "A new Shipment record has been created" );
        cmp_ok( $latest_shipment->signature_required, '==', 0, "Latest Shipment's 'signature_flag' is as the Original and FALSE" );
    };

    return;
}

=head2 test_order_view_dc1

    test_order_view_dc1( $schema, $ok_to_do_flag );

Test that DC1 & DC3 doesn't show the Delivery Signature flag

=cut

sub test_order_view_dc1 {
    my ( $schema, $oktodo )     = @_;

    SKIP: {
        skip "test_order_view_dc1", 1      if ( !$oktodo );

        note "TESTING Order View Page For DC1";

        # this is what appears in the Page Data HASH for the Signature Required field
        my $label       = 'Signature upon Delivery Required';

        my $framework   = Test::XT::Flow->new_with_traits(
            traits => [
                'Test::XT::Flow::Fulfilment',
                'Test::XT::Flow::CustomerCare',
                'Test::XT::Data::Channel',
            ],
        );

        my $orddetails  = $framework->flow_db__fulfilment__create_order(
                                                channel => $framework->channel,
                                                products => 1,
                                            );
        my $order       = $orddetails->{order_object};
        my $shipment    = $orddetails->{shipment_object};
        my $shipment_id = $shipment->id;

        Test::XTracker::Data->set_department( 'it.god', 'Finance' );
        $framework->login_with_permissions( {
            perms => {
                $AUTHORISATION_LEVEL__OPERATOR => [
                    'Customer Care/Customer Search',
                ]
            }
        } );
        $framework->flow_mech__customercare__orderview( $order->id );
        my $details = $framework->mech->as_data->{meta_data}{'Shipment Details'};
        ok( !exists( $details->{ $label } ), "Delivery Field is NOT present in the Page" );

        $framework->flow_mech__customercare__view_status_log;
        my $page_data   = $framework->mech->as_data()->{page_data};
        ok( exists( $page_data->{ $shipment_id } ), "Shipment Id Found on Status Log Page" );
        ok( !exists( $page_data->{ $shipment_id }{delivery_signature_log} ), "NO Delivery Signature Log Found for Shipment" );
    };
}

#-----------------------------------------------------------------

=head2 get_resent_shipment_of_type

    $dbic_shipment = get_resent_shipment_of_type( $order, $type );

Helper to get the most resent shipment for an order for
a specific Type.

$type can be:
    'Re-Shipment'
    'Replacement'

=cut

sub get_resent_shipment_of_type {
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
