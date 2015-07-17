#!/usr/bin/env perl
# vim: set ts=4 sw=4 sts=4:

=head1 NAME

fulfilment_ddu.t - DDU page tests

=head1 DESCRIPTION

DDU = Delivered Duty Unpaid

=head2 Check the Fulfilment -> DDU page

Tests the functionality of the Fulfilment DDU page which is used to send
Notifications to Customers requesting permission to accept DDU charges and
also send a Follow Up request. The page is also where the user can set the
Customer's answer to the Emails by specifying Charges have been Refused or
Accepted and also if they have been Accpeted for all subsequent Orders.

Currently this tests that the following 2 emails can be sent for Shipments
which are placed on 'DDU Hold' by checking that the emails have been logged
against the Shipment records:

=over

=item DDU Order - Request accept shipping terms

=item DDU Order - Follow Up

=back

Also checks that DDU Charges can be Refused, Accepted and Accepted for all
Subsequent Orders, it then checks that the following email has been sent:

=over

=item DDU Order - Set Up Permanent DDU Terms And Conditions

=back

#TAGS shouldbecando ddu finance whm

=head1 METHODS

=cut

use NAP::policy "tt", 'test';

use Test::XTracker::Data;
use Test::XT::Flow;

use XTracker::Constants::FromDB         qw (
                                            :authorisation_level
                                            :correspondence_templates
                                            :shipment_status
                                            :shipment_hold_reason
                                            :flag
                                            :flag_type
                                        );


my $schema  = Test::XTracker::Data->get_schema;
isa_ok( $schema, "XTracker::Schema" );


my $framework   = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::Fulfilment',
    ],
);

$framework->login_with_permissions( {
    perms => {
        $AUTHORISATION_LEVEL__OPERATOR => [
            'Fulfilment/DDU',
        ]
    }
} );


#----------------------- Tests -----------------------
_test_send_email_notifications( $framework, 1 );
_test_displaying_langauge_preference( $framework, 1 );
#-----------------------------------------------------

done_testing();

=head2 _test_send_email_notifications

Login with operator permissions for Fulfilment/DDU.

Create selected order on NAP.

Place Shipment on DDU Hold

Add DDU Flags

Set the customer's default to not accept DDU Charges by Default

Hit the Fulfilment/DDU page and send a request email for the shipment, check
that we received an email sent success response.

Check that we logged a DDU Order - Request accept shipping terms email.

Send a followup email and check that we logged it too.

Follow the link to accept DDU charges, and unauthorise. Check we get a charges
were refused message, that the shipment is on I<Hold>, and the customer's flag is
set to not accept DDU charges. Check the shipment hold reason is I<Other> and
there's a comment saying the customer refused DDU charges. Check customer's
I<Accept Subsequent DDU> flag is false, and that no I<Set up permanent DDU
terms and conditions> email was sent.

This time select authorise_all and send no email. Check we get the appropriate
success message. Check the shipment is I<Processing>, the flag is I<DDU
Accepted>, no shipment hold logs have been written and the customer's flag is
set to I<Accept Subsequent DDU> charges. Check that the I<Set up Permanent DDU
Terms and Conditions> email was sent.

=cut

sub _test_send_email_notifications {
    my ( $framework, $oktodo )      = @_;

    my $mech    = $framework->mech;

    SKIP: {
        skip '_test_send_email_notifications', 1        if ( !$oktodo );

        note "TESTING: '_test_send_email_notifications'";

        # create an Order
        my $orddetails  = $framework->flow_db__fulfilment__create_order_selected(
                                channel     => Test::XTracker::Data->channel_for_nap,
                                products    => 2,
                            );
        my $customer    = $orddetails->{customer_object};
        my $shipment    = $orddetails->{shipment_object};
        my $channel     = $shipment->get_channel;
        my $conf_section= $channel->business->config_section;
        my $shipment_id = $shipment->id;        # need it in a seperate variable to use in pattern matching

        # get rid of any Email Logs
        $shipment->shipment_email_logs->delete;
        my $log_rs  = $shipment->shipment_email_logs( {}, { order_by => 'id DESC' } );

        # set-up a resultset to find DDU flags
        my $flag_rs = $shipment->shipment_flags->search( {}, { order_by => 'id DESC' } );
        # set-up a resultset to find Shipment Hold status
        my $hold_rs = $shipment->shipment_holds->search( {}, { order_by => 'id DESC' } );

        _setup_shipment_for_ddu( $shipment );


        note "Send 'DDU Order - Request accept shipping terms' email";
        $framework->flow_mech__fulfilment__ddu
                    ->flow_mech__fulfilment__ddu_send_request_email( $conf_section, [ $shipment->id ] );
        like( $mech->app_status_message(), qr/Email Sent/i, "Got 'Email Sent' Success message" );
        my $log = $log_rs->reset->first;
        isa_ok( $log, 'XTracker::Schema::Result::Public::ShipmentEmailLog', "got a Shipment Email Log record" );
        cmp_ok( $log->correspondence_templates_id, '==', $CORRESPONDENCE_TEMPLATES__DDU_ORDER__DASH__REQUEST_ACCEPT_SHIPPING_TERMS,
                                    "and is for the correct Email Template" );


        note "Send 'DDU Order - Follow Up' email";
        $framework->flow_mech__fulfilment__ddu_send_request_followup_email( $conf_section, [ $shipment->id ] );
        like( $mech->app_status_message(), qr/Email Sent/i, "Got 'Email Sent' Success message" );
        $log    = $log_rs->reset->first;
        isa_ok( $log, 'XTracker::Schema::Result::Public::ShipmentEmailLog', "got a Shipment Email Log record" );
        cmp_ok( $log->correspondence_templates_id, '==', $CORRESPONDENCE_TEMPLATES__DDU_ORDER__DASH__FOLLOW_UP,
                                    "and is for the correct Email Template" );


        # test Refusing/Accepting and Accepting all Subsequent DDU Charges

        note "Refuse Charges";
        $framework->flow_mech__fulfilment__ddu_set_ddu_status_link( $shipment->id )
                    ->flow_mech__fulfilment__ddu_set_ddu_status_submit( { authorise => 'no' } );

        like( $mech->app_status_message(), qr/DDU Charges Refused for Shipment: ${shipment_id}/i,
                        "Got Success message saying that 'Charges were Refused'" );
        cmp_ok( $shipment->discard_changes->shipment_status_id, '==', $SHIPMENT_STATUS__HOLD,
                        "Shipment Status now on 'Hold'" );
        cmp_ok( $flag_rs->reset->first->flag_id, '==', $FLAG__DDU_REFUSED,
                        "Shipment now has flag: 'DDU Refused'" );
        cmp_ok( $hold_rs->reset->first->shipment_hold_reason_id, '==', $SHIPMENT_HOLD_REASON__OTHER,
                        "Shipment Hold record's Reason Id is 'Other'" );
        like( $hold_rs->first->comment, qr/Refused DDU charges/i,
                        "Shipment Hold records's Comment mentions 'Refused DDU charges'" );
        cmp_ok( $customer->discard_changes->ddu_terms_accepted, '==', 0,
                        "Customer's 'Accept Subsequent DDU' flag is still FALSE" );
        cmp_ok(
            $log_rs->reset->first->correspondence_templates_id,
            '!=',
            $CORRESPONDENCE_TEMPLATES__DDU_ORDER__DASH__SET_UP_PERMANENT_DDU_TERMS_AND_CONDITIONS,
            "and NO email was sent"
        );


        note "Accept Charges and Subsequent ones and Do not Send an Email";
        _setup_shipment_for_ddu( $shipment );
        $framework->flow_mech__fulfilment__ddu
                    ->flow_mech__fulfilment__ddu_set_ddu_status_link( $shipment->id )
                        ->flow_mech__fulfilment__ddu_set_ddu_status_submit( { authorise => 'authorise_all' , sendemail => 'no' } );

        like( $mech->app_status_message(), qr/DDU Charges Accepted for Shipment: ${shipment_id} and ALL Subsequent Shipments/i,
                        "Got Success message saying that 'Charges Accepted for all Subsequent Shipments'" );
        cmp_ok( $shipment->discard_changes->shipment_status_id, '==', $SHIPMENT_STATUS__PROCESSING,
                        "Shipment Status is now 'Processing'" );
        cmp_ok( $flag_rs->reset->first->flag_id, '==', $FLAG__DDU_ACCEPTED,
                        "Shipment now has flag: 'DDU Accepted'" );
        cmp_ok( $hold_rs->reset->count, '==', 0, "No Shipment Hold records have been created" );
        cmp_ok( $customer->discard_changes->ddu_terms_accepted, '==', 1,
                        "Customer's 'Accept Subsequent DDU' flag is now TRUE" );
        cmp_ok(
            $log_rs->reset->first->correspondence_templates_id,
            '!=',
            $CORRESPONDENCE_TEMPLATES__DDU_ORDER__DASH__SET_UP_PERMANENT_DDU_TERMS_AND_CONDITIONS,
            "and NO email was sent"
        );

        note "Accept Charges and Subsequent ones and Send an Email";
        _setup_shipment_for_ddu( $shipment );
        $framework->flow_mech__fulfilment__ddu
                    ->flow_mech__fulfilment__ddu_set_ddu_status_link( $shipment->id )
                        ->flow_mech__fulfilment__ddu_set_ddu_status_submit( { authorise => 'authorise_all' , sendemail => 'yes' });

        like( $mech->app_status_message(), qr/DDU Charges Accepted for Shipment: ${shipment_id} and ALL Subsequent Shipments/i,
                        "Got Success message saying that 'Charges Accepted for all Subsequent Shipments'" );
        cmp_ok( $shipment->discard_changes->shipment_status_id, '==', $SHIPMENT_STATUS__PROCESSING,
                        "Shipment Status is now 'Processing'" );
        cmp_ok( $flag_rs->reset->first->flag_id, '==', $FLAG__DDU_ACCEPTED,
                        "Shipment now has flag: 'DDU Accepted'" );
        cmp_ok( $hold_rs->reset->count, '==', 0, "No Shipment Hold records have been created" );
        cmp_ok( $customer->discard_changes->ddu_terms_accepted, '==', 1,
                        "Customer's 'Accept Subsequent DDU' flag is now TRUE" );
        cmp_ok(
            $log_rs->reset->first->correspondence_templates_id,
            '==',
            $CORRESPONDENCE_TEMPLATES__DDU_ORDER__DASH__SET_UP_PERMANENT_DDU_TERMS_AND_CONDITIONS,
            "and 'Set up Permanent DDU Terms and Conditions' email WAS sent"
        );
    };


    return;
}

=head2 _test_displaying_language_preference

Test displaying the Customer's Language Preference on the DDU Hold page.

Login with operator permissions for Fulfilment/DDU.

Create selected order on NAP.

Place Shipment on DDU Hold

Add DDU Flags

Set the customer's default to not accept DDU Charges by Default

Remove any existing customer attributes.

Get the Fulfilment/DDU page and check that the default language is displayed in
the 'Awaiting Notification' table.

Set the language to French, update the page and check we display French in the
'Awaiting Notification' table.

Send a DDU email request and check we display French.

Delete the row in the db, and check we've switched back to the default
language.

=cut

sub _test_displaying_langauge_preference {
    my ( $framework, $oktodo )  = @_;

    SKIP: {
        skip '_test_displaying_langauge_preference', 1        if ( !$oktodo );

        note "TESTING: '_test_displaying_langauge_preference'";

        my $mech            = $framework->mech;
        my $schema          = $framework->schema;
        my $default_language= $schema->resultset('Public::Language')
                                        ->get_default_language_preference
                                            ->description;

        # create an Order
        my $orddetails  = $framework->flow_db__fulfilment__create_order_selected(
                                channel     => Test::XTracker::Data->channel_for_nap,
                                products    => 2,
                            );
        my $customer    = $orddetails->{customer_object};
        my $shipment    = $orddetails->{shipment_object};
        my $channel     = $shipment->get_channel;
        my $conf_section= $channel->business->config_section;

        _setup_shipment_for_ddu( $shipment );

        $customer->customer_attribute->delete       if ( $customer->customer_attribute );

        note "check if the Customer's Language is displayed in the 'Awaiting Notification' table";

        $framework->flow_mech__fulfilment__ddu;
        my $row = _get_row_from_table( $mech, $conf_section, $shipment, 'ddu_awaiting_sending_notification' );
        is( $row->{CPL}, $default_language, "Default Language is displayed on the Page" );

        # set Language to be French
        $customer->set_language_preference( 'FR' );
        $framework->flow_mech__fulfilment__ddu;
        $row    = _get_row_from_table( $mech, $conf_section, $shipment, 'ddu_awaiting_sending_notification' );
        is( $row->{CPL}, 'French', "Having changed Customer's Language Preference, 'French' is now displayed" );

        note "check if the Customer's Language is displayed in the 'Awaiting Reply' table";

        $framework->flow_mech__fulfilment__ddu_send_request_email( $conf_section, [ $shipment->id ] );
        $row    = _get_row_from_table( $mech, $conf_section, $shipment, 'ddu_awaiting_reply' );
        is( $row->{CPL}, 'French', "Customer's Language Preference of 'French' is displayed" );

        $customer->customer_attribute->delete;
        $framework->flow_mech__fulfilment__ddu;
        $row    = _get_row_from_table( $mech, $conf_section, $shipment, 'ddu_awaiting_reply' );
        is( $row->{CPL}, $default_language, "Customer's Language Preference is now the Default and displayed" );
    };

    return;
}

#-----------------------------------------------------------------

# returns the Row for a Shipment
# in the specified table
sub _get_row_from_table {
    my ( $mech, $conf_section, $shipment, $table_id )   = @_;

    my $table   = $mech->as_data->{page_data}{ $conf_section }{ $table_id };

    my ( $row ) = grep {
        $_->{'Shipment Nr.'}{value} == $shipment->id
    } @{ $table };

    return $row;
}

sub _setup_shipment_for_ddu {
    my $shipment    = shift;

    $shipment->discard_changes;

    # place Shipment on DDU Hold
    $shipment->update( { shipment_status_id => $SHIPMENT_STATUS__DDU_HOLD } );

    # Add DDU Flags
    $shipment->shipment_flags->delete;
    $shipment->shipment_flags->create( { flag_id => $FLAG__DDU_PENDING } );

    # Shipment Hold Reasons
    $shipment->shipment_holds->delete;

    # set the Customer's default to not
    # accept DDU Charges by Default
    $shipment->order->customer->update( { ddu_terms_accepted => 0 } );

    return;
}
