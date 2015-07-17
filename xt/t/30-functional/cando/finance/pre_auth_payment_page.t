#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

pre_auth_payment_page.t - Tests the Pre-Authorise Payment page

=head1 DESCRIPTION

This tests the Pre-Authorise Payment page which you get to as a Finance user
from the Order View page.

The functionality it currently tests is:
    * Creating a new Pre-Auth
    * Cancel a Pre-Auth

Verifies that billing, payment and pre_auth details are displayed and that
error messages are correctly displayed for invalid cancel pre_auth submissions.

Verifies that cancel pre_auth works correctly with valid submission and that
logs are updated accordingly.

#TAGS orderview needsrefactor cando

=cut

use Data::Dump      qw( pp );

use Test::XTracker::Data;
use Test::XT::Flow;

use XTracker::Constants                 qw( :application );
use XTracker::Constants::FromDB     qw(
    :authorisation_level
);
use XTracker::Constants     qw( :psp_default );

my $schema  = Test::XTracker::Data->get_schema;
isa_ok( $schema, "XTracker::Schema" );

my $framework   = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::CustomerCare',
        'Test::XT::Flow::Fulfilment',
        'Test::XT::Flow::Finance',
    ],
);

# create an Order
my $orddetails  = $framework->flow_db__fulfilment__create_order(
    channel  => Test::XTracker::Data->channel_for_nap,
    products => 2,
);
my $order       = $orddetails->{order_object};
my $shipment    = $orddetails->{shipment_object};
my $customer    = $orddetails->{customer_object};
my $site        = site_from_customer( $customer );
my $order_id    = $order->id;

# create the Pre-Auth
my $next_preauth= Test::XTracker::Data->get_next_preauth( $schema->storage->dbh );
my $ord_payment = Test::XTracker::Data->create_payment_for_order( $order, {
    psp_ref     => $next_preauth,
    preauth_ref => $next_preauth,
    fulfilled   => 'f',
    valid       => 't'
} );
my $cancel_log_rs= $ord_payment->log_payment_preauth_cancellations
                                    ->search( {}, { order_by => 'id DESC' } );

note "Order Nr/Id: ".$order->order_nr."/".$order_id;
note "Shipment Id: ".$shipment->id;

Test::XTracker::Data->set_department( 'it.god', 'Finance' );
$framework->login_with_permissions( {
    perms => {
        $AUTHORISATION_LEVEL__OPERATOR => [
            'Customer Care/Order Search',
            'Customer Care/Customer Search',
        ]
    }
} );

$framework->errors_are_fatal(0);

# The PSP issues a self-signed certificate, so we need to skip verification.
$framework->mech->ssl_opts( verify_hostname => 0 );

$framework->mech->log_snitch->pause;        # suppress known warning in log thrown because of communication with non-existent PSP
$framework->flow_mech__customercare__orderview( $order_id );

$framework->flow_mech__finance__pre_authorise_order;
my $pgdata  = $framework->mech->as_data;

ok( exists( $pgdata->{billing_details} ), "Billing Details found in Page" );
ok( exists( $pgdata->{payment_details} ), "Payment Details found in Page" );
ok( exists( $pgdata->{pre_auth_details} ), "Existing Pre-Auth Details found in Page" );
ok( !exists( $pgdata->{cancelled_pre_auth_log} ), "Pre-Auth Cancellation Log NOT found in Page" );
ok( !exists( $pgdata->{replacement_cancelled_pre_auth_log} ), "Replaced Pre-Auth Cancellation Log NOT found in Page" );
cmp_ok( _check_for_cancel_btn( $framework->mech ), '==', 1, "Cancel Button IS in Form" );

# Because the PSP is not present, we should get an error telling us this.
$framework->mech->has_feedback_error_ok( qr/There was a problem with the Payment Service, please try refreshing the page/ );

# Check the Payment Service form has the correct fields.
like( $pgdata->{psp_form_redirect_url}, qr|http://.*/CustomerCare/CustomerSearch/AuthorisePayment.*orders_id=$order_id|, 'psp_form_redirect_url looks correct' );
is( $pgdata->{psp_form_payment_session_id}, '', 'psp_form_payment_session_id is empty (No PSP)' );
is( $pgdata->{psp_form_customer_id}, $customer->id, 'psp_form_customer_id is correct (' . $customer->id . ')' );
is( $pgdata->{psp_form_site}, $site, "psp_form_site is correct ($site)" );
is( $pgdata->{psp_form_admin_id}, '0', 'psp_form_admin_id is zero' );
is( $pgdata->{psp_form_keep_card}, '0', 'psp_form_keep_card is zero' );
is( $pgdata->{psp_form_saved_card}, '0', 'psp_form_saved_card is zero' );

# because the PSP can't be mocked Cancelling
# a Pre-Auth will always result in failure but
# should still create a log to show you tried
note "Now Attempt to Cancel the Pre-Auth";
$framework->flow_mech__finance__cancel_preauth_submit();
$pgdata = $framework->mech->as_data;
unlike( $framework->mech->app_error_message, qr/The card number must/, "Card Number Error Message NOT Shown" );
cmp_ok( $cancel_log_rs->reset->count(), '==', 1, "Cancel Log has been Created" );
ok( exists( $pgdata->{cancelled_pre_auth_log} ), "Pre-Auth Cancellation Log found in Page" );
like( $pgdata->{cancelled_pre_auth_log}[0]{'Successful Cancellation'}, qr/No/, "Log Shows as NOT having Cancelled the Pre-Auth" );

note "Manually change the 'cancelled' flag in the log to be TRUE then call the page again";
$cancel_log_rs->first->update( { cancelled => 1 } );
$framework->flow_mech__customercare__orderview( $order_id )
            ->flow_mech__finance__pre_authorise_order;
$pgdata = $framework->mech->as_data;
like( $pgdata->{pre_auth_details}{'Pre-Auth Reference'}, qr/This Pre-Auth has been Cancelled/, "Cancel Message Shown next to 'PSP Reference'" );
cmp_ok( _check_for_cancel_btn( $framework->mech ), '==', 0, "Cancel Button NOT in Form now Pre-Auth has been Flagged as 'Cancelled'" );
ok( exists( $pgdata->{cancelled_pre_auth_log} ), "Pre-Auth Cancellation Log found in Page" );
like( $pgdata->{cancelled_pre_auth_log}[0]{'Successful Cancellation'}, qr/Yes/, "Log Shows as Pre-Auth being Cancelled" );
like( $pgdata->{cancelled_pre_auth_log}[0]{'Context'}, qr/Pre-Authorise Payment Page/, "Log Shows Context as being this page" );

note "Now Move the logs an check Replacement Cancellation logs";
# check all the logs have been moved
$ord_payment->copy_to_replacement_and_move_logs();
$framework->flow_mech__customercare__orderview( $order_id )
            ->flow_mech__finance__pre_authorise_order;
$pgdata = $framework->mech->as_data;
ok( !exists( $pgdata->{cancelled_pre_auth_log} ), "Pre-Auth Cancellation Log NOT found in Page" );
ok( exists( $pgdata->{replacement_cancelled_pre_auth_log} ), "Replacement Pre-Auth Cancellation Log found in Page" );


# because the PSP can't be mocked any this is of questionable value
note "Check Card Payment Authorisation with correct Fields";
$framework->flow_mech__finance__new_preauth_submit( { number => '1' x 15, cardholder => 'Ms Test Person', expiry_month => '01', expiry_year => '99' } );
ok( $framework->mech->response->code, 'Got a response of any kind' );

$framework->errors_are_fatal(1);
$framework->mech->log_snitch->unpause;      # Un-Pause otherwise it will still warn when the test ends

done_testing();

#-----------------------------------------------------------------

# checks to see if the 'CANCEL' button is present in the form
sub _check_for_cancel_btn {
    my $mech    = shift;

    return ( $mech->content =~ m{<input .* value="CANCEL" .*/>}s ? 1 : 0 );
}

sub site_from_customer {
    my ( $customer ) = @_;

    my $site = lc $customer->channel->web_name;
    $site =~ s/-/_/;

    return $site;

}
