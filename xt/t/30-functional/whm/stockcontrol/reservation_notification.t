#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

reservation_notification.t - Send a Reservation Customer Notification Email

=head1 DESCRIPTION

Make reservation record available for 'Customer Notification'

Go to Reservation Summary page

Loop through 3 departments checking the 'From Email Address' for each:
    * Customer Care
    * Fashion Advisor
    * Personal Shopping

Have a look at the Customer Notification page.
Get the notification for the customer we're interested in from the page.

Submit the Customer Notification request.

Ensure the reservation 'notified' flag is now TRUE.

#TAGS shouldbecando reservation inventory whm

=cut

use Test::XTracker::Data::Email;
use Test::XT::Flow;

use XTracker::Constants::FromDB         qw( :authorisation_level :reservation_status );
use XTracker::Config::Local             qw(
                                            config_var
                                            customercare_email
                                            fashionadvisor_email
                                            personalshopping_email
                                        );

my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::Reservations',
    ],
);

# set the Sales Channel for NaP
my $channel         = Test::XTracker::Data->get_local_channel_or_nap;
my $channel_name    = uc( $channel->name );
my $config_section  = $channel->business->config_section;
$framework->mech->channel( $channel );

# get the default & localised From Email Addresses
# for the following three Departments:
#       Customer Care
#       Fashion Advisor
#       Personal Shopping
my $email_address   = _get_from_email_addresses( $channel );

# creates a Reservation whose Customer will have the Default From Address
my $reservation_default = _create_reservation( $channel );
$reservation_default->customer->customer_attribute->delete      if ( $reservation_default->customer->customer_attribute );
# creates a Reservation whose Customer will have a Localised From Address
my $reservation_local   = _create_reservation( $channel );
$reservation_local->customer->set_language_preference('fr');


$framework->login_with_permissions( {
    perms => {
            $AUTHORISATION_LEVEL__MANAGER => [
                'Stock Control/Reservation',
            ]
        }
} );

# make reservation record available for 'Customer Notification'
$reservation_default->update( {
    date_uploaded   => \'now()',
    status_id       => $RESERVATION_STATUS__UPLOADED,
} );
$reservation_local->update( {
    date_uploaded   => \'now()',
    status_id       => $RESERVATION_STATUS__UPLOADED,
} );

# go to Reservation Summary page
$framework->mech__reservation__summary;

# loop through 3 departments checking the 'From Email Address' for each
foreach my $department ( keys %{ $email_address } ) {
    my $default_address = $email_address->{ $department }{default};
    my $local_address   = $email_address->{ $department }{local};

    note "Department: $department, Email Address - default: '${default_address}', local: '${local_address}'";

    # set the department of the operator
    Test::XTracker::Data->set_department( $reservation_default->operator_id, $department );

    # have a look at the Customer Notification page
    $framework->mech__reservation__summary_click_customer_notification;

    note "get the notification for the customer we're interested in from the page who has no Preferred Language Preference";
    my ($cust)  = grep { $_->{customer_info}{'Customer Number'} == $reservation_default->customer->is_customer_number }
                            @{ $framework->mech->as_data->{customer_emails}{ $channel_name } };
    ok( defined $cust, "Found Notification for Customer" );

    is( $cust->{email_info}{"To Email"}{input_value}, $reservation_default->customer->email,
                        "To Email Address is for the Customer: '" . $cust->{email_info}{"To Email"}{input_value} . "'" );
    is( $cust->{email_info}{"From Email"}{input_value}, $default_address,
                        "From Email Address for department is the Default email address: '" . $cust->{email_info}{"From Email"}{input_value} . "'" );

    note "get the notification for the customer we're interested in from the page who has a Preferred Language of 'French'";
    ($cust) = grep { $_->{customer_info}{'Customer Number'} == $reservation_local->customer->is_customer_number }
                            @{ $framework->mech->as_data->{customer_emails}{ $channel_name } };
    ok( defined $cust, "Found Notification for Customer" );

    is( $cust->{email_info}{"To Email"}{input_value}, $reservation_local->customer->email,
                        "To Email Address is for the Customer: '" . $cust->{email_info}{"To Email"}{input_value} . "'" );
    is( $cust->{email_info}{"From Email"}{input_value}, $local_address,
                        "From Email Address for department is the Localised email address: '" . $cust->{email_info}{"From Email"}{input_value} . "'" );
}

# submit without selecting any Reservations and an error should occur
$framework->errors_are_fatal(0);
$framework->mech__reservation__summary_customer_notification_submit( {
    reservation_id      => 'none',
    # need the Customer Id to make sure the correct FORM is used
    customer_id         => $reservation_default->customer_id,
} );
$framework->errors_are_fatal(1);
$framework->mech->has_feedback_error_ok( qr/No Reservations were selected to be Notified/i,
                    "Error message as expected when NOT selecting any Reservations to be Notified" );

# now submit the Customer Notification request
$framework->mech__reservation__summary_customer_notification_submit( {
    reservation_id      => $reservation_default->id,
    is_customer_number  => $reservation_default->customer->is_customer_number,
    customer_id         => $reservation_default->customer_id,
    channel_name        => $channel_name,
} );
$framework->mech->has_feedback_success_ok( qr/Customer notification successful\./, "Success message as expected" );

$reservation_default->discard_changes;
cmp_ok( $reservation_default->notified, '==', 1, "Reservation 'notified' flag is now TRUE" );


# clean-up Localised Email Addresses
Test::XTracker::Data::Email->cleanup_localised_email_addresses();

done_testing();

#--------------------------------------------------------------

# create a new Reservation which will also create a new Customer
sub _create_reservation {
    my $channel = shift;

    my $data = Test::XT::Flow->new_with_traits(
        traits => [
            'Test::XT::Data::ReservationSimple',
        ],
    );

    return $data->reservation;
}

# get email from addresses to check for
# in tests for different Departments
sub _get_from_email_addresses {
    my $channel     = shift;

    my $config_section  = $channel->business->config_section;
    my %email_address;

    # create localised versions of Email Addresses so
    # that the From Address used is a Localised version
    $email_address{'Customer Care'}{local}      =
        Test::XTracker::Data::Email->create_localised_email_for_config_setting( $channel, 'customercare_email', 'fr_FR' )
                                    ->localised_email_address;
    $email_address{'Fashion Advisor'}{local}    =
        Test::XTracker::Data::Email->create_localised_email_for_config_setting( $channel, 'fashionadvisor_email', 'fr_FR' )
                                    ->localised_email_address;
    $email_address{'Personal Shopping'}{local}  =
        Test::XTracker::Data::Email->create_localised_email_for_config_setting( $channel, 'personalshopping_email', 'fr_FR' )
                                    ->localised_email_address;

    # get the various non-localised email addresses to check, for each department
    $email_address{'Customer Care'}{default}        = customercare_email( $config_section );
    $email_address{'Fashion Advisor'}{default}      = fashionadvisor_email( $config_section );
    $email_address{'Personal Shopping'}{default}    = personalshopping_email( $config_section );

    return \%email_address;
}
