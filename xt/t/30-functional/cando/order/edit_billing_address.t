#!/usr/bin/env perl

use NAP::policy "tt",     'test';

=head1 DESCRIPTION

This sanity tests the Billing Address related things in EditAddress
and UpdateAddress.

=cut

use Test::More::Prefix qw/test_prefix/;
use Test::XTracker::Data;
use Test::XTracker::Data::Shipping;
use Test::XTracker::Data::Order;
use Test::XT::Flow;
use XTracker::Constants::FromDB qw(
    :authorisation_level
    :shipment_status
    :shipment_item_status
    :shipment_type
    :shipping_charge_class
);
use XTracker::Database qw( :common );

use XT::Net::WebsiteAPI::TestUserAgent;
use XT::Data::DateStamp;

my $schema = Test::XTracker::Data->get_schema;

test_prefix("Setup: framework");
my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        "Test::XT::Flow::CustomerCare",
    ],
);
$framework->login_with_permissions({
    perms => {
        $AUTHORISATION_LEVEL__MANAGER => [
            "Customer Care/Order Search",
        ],
   },
    dept => "Distribution Management", # Important for the EditAddress page
});
$framework->mech->force_datalite(1);

test_prefix("Setup: order shipment");

my $channel = Test::XTracker::Data->channel_for_nap();
my $mech    = $framework->mech; #Test::XTracker::Mechanize->new;

# Test the Edit Billing Address pages
my $edit_billing_address_test_cases;
push @$edit_billing_address_test_cases, {
    prefix      => "Pre=>Dom",
    description => "Premier to Domestic",
    setup => {
        current => {
            address_in          => "current_dc_premier",
            shipment_type      => $SHIPMENT_TYPE__PREMIER,
            shipping_charge_id => Test::XTracker::Data::Order->get_premier_shipping_charge(
                $channel, { id => 3, description => "Daytime, 10:00-17:00", } # Premier routing
            )->id,
        },
        new => {
            address_in => "current_dc",
        },
    },
    expected => {
        final => {
            shipment_note => {
                DC1 => { shipment_note_qr => qr|\QAddress(some one, Unit 3, Charlton Gate Business Park, Anchor and Hope Lane, LONDON, London, NW10 4GR, United Kingdom => Bert Ernieson, Unit 3, Charlton Gate Business Park, Anchor and Hope Lane, LONDON, London, BN1 9RF, United Kingdom), Nominated Delivery Date(15/09/2011 => ), Shipment Type(Premier => Domestic), Shipping Charge(Premier Daytime => UK Express), Shipping Charge Price(10.00 => 5.00), Shipping SKU(9000210-001 => 900003-001)| },
                DC2 => { shipment_note_qr => qr|\QAddress(some one, 725 Darlington Avenue, Mahwah, NJ, New Jersey, NY, 11371, United States => Bert Ernieson, 725 Darlington Avenue, Mahwah, NJ, New Jersey, CA, 90210, United States), Nominated Delivery Date(15/09/2011 => ), Shipment Type(Premier => Domestic), Shipping Charge(Premier Daytime => California 3-5 Business Days), Shipping Charge Price(10.00 => 0.00), Shipping SKU(9000211-001 => 900045-002)| },
            },
        },
    },
} if $channel->has_customer_facing_premier_shipping_charges;

sub test_edit_billing_address {
    my ($test_cases) = @_;
    test_prefix("");
    note("*** Test edit_billing_address");

    # May be either an amend to existing or a completely new address
    my $initial_steps = [
        sub { $framework->flow_mech__customercare__choose_address() },
        sub { $framework->flow_mech__customercare__new_address() },
       ];

    # Submit and Test Updated Shipment, Shipment Note
    for my $case (@$test_cases) {

        for my $initial_step (@$initial_steps){
            my $setup = $case->{setup} || {};
            my $expected = $case->{expected};

            my $new_order_address = Test::XTracker::Data->create_order_address_in(
                $setup->{new}->{address_in},
               );

            my $address_fields = {
                first_name => "Bert",
                last_name  => "Ernieson",
                map { $_ => $new_order_address->$_ }
                  qw/ address_line_1 address_line_2 towncity county postcode country/,
            };

            # Follow 'edit address' link
            my $order_id = setup_address_test($case, $setup);

            # New or amend - we end up on the same form
            $initial_step->();

            # Edit address form
            submit_address_change($setup, $order_id, $address_fields);

            check_address($order_id, $address_fields);
        }

    }
}

sub test_choose_billing_address {
    my ($test_cases) = @_;

    # Submit and Test Updated Shipment, Shipment Note
    for my $case (@$test_cases) {

        my $setup = $case->{setup} || {};
        my $expected = $case->{expected};

        # Follow 'edit address' link
        my $order_id = setup_address_test($case, $setup);

        # Submit the form
        $framework->flow_mech__customercare__choose_address;

        # Set the new first name
        my $new_first_name = 'Newfirst';
        $mech->submit_form_ok({
            with_fields => { first_name => $new_first_name },
            button      => "submit"
        }, "Update the address" );


        # Confirm
        $mech->submit_form( form_name => 'editAddress');
        $mech->no_feedback_error_ok;

        like(
            $mech->uri,
            qr|CustomerCare/OrderSearch/OrderView\?order_id=$order_id|,
            "Got back to the OrderView page for Order ($order_id) ok",
           );

        check_address($order_id, {first_name => $new_first_name} );
    }
}

sub setup_address_test {
    my ($case, $setup) = @_;

    note("** $case->{description}");
    test_prefix("$case->{prefix} * Setup: ");

    note "*** Setup";
    my ($shipment_row, $response_or_data) = Test::XTracker::Data::Order->create_shipment(
        $channel,
        {
            shipment_item_status => $SHIPMENT_ITEM_STATUS__NEW,
            shipment_status      => $SHIPMENT_STATUS__PROCESSING,
            %{$setup->{current}},
        },
       );

    my $order_id = $shipment_row->order->id;
    note("order_id($order_id), shipment_id(" . $shipment_row->id . ")");

    test_prefix("$case->{prefix}: * Run");

    $mech->order_nr($shipment_row->order->order_nr);
    $mech->order_view_url;
    $mech->follow_link_ok({ text_regex => qr/Edit Billing Address/ });

    return $order_id;
}

sub submit_address_change {
    my ($setup, $order_id, $address_fields) = @_;

    $mech->submit_form_ok({ with_fields => $address_fields,
                            button      => "submit"
                          }, "Update the address" );

    $mech->no_feedback_error_ok;
    $mech->content_unlike(
        qr/Shipping Option/ms,
        "Billing Address confirmation page doesn't mention Shipping Option (like the Edit Shipping Address page would)",
    );

    note("Submit confirmation screen");
    $mech->submit_form(form_name => 'editAddress');

    $mech->no_feedback_error_ok;
    like(
        $mech->uri,
        qr|CustomerCare/OrderSearch/OrderView\?order_id=$order_id|,
        "Got back to the OrderView page for Order ($order_id) ok",
    );
}


sub check_address {
    my ($order_id, $address_fields) = @_;

    my $order = $schema->resultset('Public::Orders')->find($order_id);

    is($order->invoice_address->first_name,
       $address_fields->{first_name},
       'Address first name is updated'
    );
}

# Run the tests
test_edit_billing_address($edit_billing_address_test_cases);
test_choose_billing_address($edit_billing_address_test_cases);

done_testing();
