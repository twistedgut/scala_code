#!/usr/bin/env perl
# vim: set ts=4 sw=4 sts=4:

use NAP::policy "tt",     'test';

=head1 NAME

order_view_send_email.t - Send Email - Left hand menu option on Order View page

=head1 DESCRIPTION

Checks the use of the 'Send Email' left hand menu option on the Order View page, this allows a user
to send any email that is assigned to their Department in the 'correspondence_templates' table.

#TAGS orderview email cando

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::Email;
use Test::XT::Flow;

use XTracker::Config::Local             qw( customercare_email localreturns_email );
use XTracker::Constants                 qw( :application );
use XTracker::Constants::FromDB         qw (
                                            :authorisation_level
                                            :correspondence_templates
                                            :department
                                            :shipment_status
                                            :shipment_hold_reason
                                        );
use XTracker::Utilities                 qw( number_in_list );


my $schema  = Test::XTracker::Data->get_schema;
isa_ok( $schema, "XTracker::Schema" );


my $framework   = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::CustomerCare',
        'Test::XT::Data::Order',
    ],
);

$framework->login_with_permissions( {
    perms => {
        $AUTHORISATION_LEVEL__OPERATOR => [
            'Customer Care/Order Search',
            'Customer Care/Customer Search',
        ]
    }
} );


#----------------------- Tests -----------------------
_test_send_email( $framework, 1 );
#-----------------------------------------------------

done_testing();

=head1 METHODS

=head2 _test_send_email

    _test_send_email( $framework, $ok_to_do_flag );

Tests that for every Department that has Email Templates assigned to them in
the 'correspondence_templates' table that they can get to the 'Send Email'
option and checks the following on the page:

    * To address
    * From address
    * Reply-To address
    * Subject
    * Content
    * Content-Type (hidden field)

For Subject & Content it just checks there is a value and not what the value is.

Then checks the actions:

    * Checks that an Email is logged when it is sent

=cut

sub _test_send_email {
    my ( $framework, $oktodo )      = @_;

    my $mech    = $framework->mech;

    SKIP: {
        skip '_test_send_email', 1      if ( !$oktodo );

        note "TESTING: '_test_send_email'";

        # create an Order
        my $orddetails  = $framework->selected_order(
            channel     => Test::XTracker::Data->channel_for_nap,
            products    => 2,
        );
        my $order       = $orddetails->{order_object};
        my $shipment    = $orddetails->{shipment_object};
        my $channel     = $order->channel;
        my $conf_section= $channel->business->config_section;

        my $log_rs      = $order->order_email_logs( {}, { order_by => 'id DESC' } );

        # get a list of all Templates which are assigned a Department
        my @templates_to_test   = $schema->resultset('Public::CorrespondenceTemplate')->search(
            {
                department_id   => { '!=' => undef },
            }
        )->all;

        # to test correct localised from/reply-to email
        # address used change Customer's language to be French
        $order->customer->set_language_preference('fr');


        # build up a list of all Templates for each
        # Department so that each can be checked

        # only these departments can see the 'Send Email' menu option
        my @allowed_departments = (
            $DEPARTMENT__FINANCE,
            $DEPARTMENT__SHIPPING,
            $DEPARTMENT__SHIPPING_MANAGER,
            $DEPARTMENT__CUSTOMER_CARE,
            $DEPARTMENT__CUSTOMER_CARE_MANAGER,
            $DEPARTMENT__DISTRIBUTION_MANAGEMENT,
            $DEPARTMENT__STOCK_CONTROL,
        );
        my %tests;
        TEMPLATE:
        foreach my $template ( @templates_to_test ) {
            next TEMPLATE       if ( !number_in_list( $template->department_id, @allowed_departments ) );
            push @{ $tests{ $template->department_id } }, $template;
        }


        # get the From email addresses used by all templates for the correct Locale
        my $customercare_email  = Test::XTracker::Data::Email->create_localised_email_address( customercare_email( $conf_section ), 'fr_FR' );
        my $localreturns_email  = Test::XTracker::Data::Email->create_localised_email_address( localreturns_email( $conf_section ), 'fr_FR' );

        # list of Templates that use the 'localreturns_email' as
        # their 'From' address, everythingelse uses 'customercare_email'
        my %templates_from_localreturns = (
            'Premier - Arrange Colection'   => $localreturns_email->localised_email_address,
            'Premier - Arrange Delivery'    => $localreturns_email->localised_email_address,
            'Premier - Collection Arranged' => $localreturns_email->localised_email_address,
            'Premier - Delivery Arranged'   => $localreturns_email->localised_email_address,
        );


        # list of fields on the form to check aren't empty
        my @form_fields_to_check    = (
            'Subject',
            'Email Text',
        );

        my $department_rs   = $schema->resultset('Public::Department');
        foreach my $department_id ( keys %tests ) {
            my $department  = $department_rs->find( $department_id );
            note "DEPARTMENT: '" . $department->department . "', Id: " . $department->id;

            my $templates   = $tests{ $department_id };

            Test::XTracker::Data->set_department( 'it.god', $department->department );

            foreach my $template ( @{ $templates } ) {
                note "    TEMPLATE: '" . $template->name . "', Id: " . $template->id;

                # get rid of Email Logs
                $order->order_email_logs->delete;
                _reset_shipment( $shipment );

                $framework
                    ->flow_mech__customercare__orderview( $order->id )
                        ->flow_mech__customercare__send_email
                            ->flow_mech__customercare__send_email_select_email_template( $template->id );

                # check page contents
                my $expect_from_email = $templates_from_localreturns{ $template->name } // $customercare_email->localised_email_address;
                my $pg_data         = $framework->mech->as_data()->{email_form};
                my $got_template_id = $pg_data->{hidden_fields}{template_id} // 0;
                cmp_ok( $got_template_id, '==', $template->id, "Hidden Field: 'template_id' is for the correct Template: '" . $template->id . "'" );
                my $content_type    = $pg_data->{hidden_fields}{email_content_type};
                ok( $content_type, "Hidden Field: 'email_content_type' has a value: '${content_type}'" );
                is( $pg_data->{To}, $order->email, "Field: 'To' has Order's Email Address: '" . $order->email . "'" );
                is( $pg_data->{From}, $expect_from_email, "Field: 'From' uses the correct address: '${expect_from_email}'" );
                is( $pg_data->{'Reply To'}, $expect_from_email, "Field: 'Reply To' uses the correct address: '${expect_from_email}'" );
                foreach my $field ( @form_fields_to_check ) {
                    my $value   = $pg_data->{ $field };
                    ok(
                        defined $value && length( $value ) >= 5,    # arbitary value to make sure
                                                                    # something useful has been found
                        "Field: '${field}' has a value on the page: '$value'"
                    );
                }
                cmp_ok( $log_rs->reset->count, '==', 0, "No Email has been Logged" );

                # now actually send the email
                $framework->flow_mech__customercare__send_an_email;
                my $success_msg = $framework->mech->as_data()->{success_msg};
                like( $success_msg, qr/Email successfully sent/i, "Got Sent Success message" );
                cmp_ok( $log_rs->reset->count, '==', 1, "An Email has been Logged" );
                cmp_ok( $log_rs->first->correspondence_templates_id, '==', $template->id,
                                    "and it is for the correct Template" );

                # check if the Shipment should be on Hold
                _check_for_on_hold( $shipment, $template );
            }
        }

        Test::XTracker::Data::Email->cleanup_localised_email_addresses;
    };

    return;
}

#-----------------------------------------------------------------

=head2 _reset_shipment

    _reset_shipment( $dbic_shipment );

Resets a Shipment to 'Processing' Status and removes any Shipment Holds.

=cut

sub _reset_shipment {
    my $shipment    = shift;

    $shipment->discard_changes;

    $shipment->update_status( $SHIPMENT_STATUS__PROCESSING, $APPLICATION_OPERATOR_ID );
    $shipment->shipment_holds->delete;

    return;
}

=head2 _check_for_on_hold

    _check_for_on_hold( $dbic_shipment, $dbic_template );

Test Helper that checks to see that for certain templates the Shipment has been placed on Hold.

=cut

sub _check_for_on_hold {
    my ( $shipment, $template ) = @_;

    $shipment->discard_changes;

    if ( $template->id == $CORRESPONDENCE_TEMPLATES__ORDERING_FROM_THE_OTHER_SITE_NOTIFICATION_EMAIL__5 ) {
        # when 'Ordering From the Other Site' notification is sent then
        # the Order is put on Hold, awaiting the Customer's response
        note "Template: '" . $template->name . "' should have put Shipment on Hold";
        cmp_ok( $shipment->shipment_status_id, '==', $SHIPMENT_STATUS__HOLD, "Shipment Status is on 'Hold'" );
        my $hold    = $shipment->shipment_holds->first;
        isa_ok( $hold, 'XTracker::Schema::Result::Public::ShipmentHold', "Shipment has a 'shipment_hold' record created for it" );
        cmp_ok( $hold->shipment_hold_reason_id, '==', $SHIPMENT_HOLD_REASON__ORDER_PLACED_ON_INCORRECT_WEBSITE,
                                        "and has the expected Reason given" );
    }
    else {
        cmp_ok( $shipment->shipment_status_id, '==', $SHIPMENT_STATUS__PROCESSING, "Shipment hasn't been put on Hold" );
    }

    return;
}
