#!/usr/bin/env perl

use NAP::policy "tt",     'test';

use Guard;

use Test::XTracker::Data;
use Test::XTracker::Hacks::isaFunction;
use Test::More::Prefix qw( test_prefix );
use Test::XTracker::Mock::Handler;
use Test::XTracker::Mechanize;
use Test::XTracker::Data::Order;
use XTracker::Config::Local qw(
    :DEFAULT
    :carrier_automation
    customercare_email
);
use XTracker::Database::Session;
use Test::XTracker::Data::Shipping;

use XTracker::Constants::FromDB   qw(
                                        :channel
                                        :shipment_item_status
                                        :shipment_status
                                        :shipment_type
                                        :correspondence_templates
                                    );

use XTracker::Constants::FromDB qw(:authorisation_level);
use Test::XT::Flow;

use NAP::Carrier;

my $dc_name = Test::XTracker::Data->whatami;
note "TESTING FOR: $dc_name";

my $schema      = Test::XTracker::Data->get_schema;
my $channels    = $schema->resultset('Public::Channel')->get_channels();
my $auto_states = $schema->resultset('Public::Channel')->get_carrier_automation_states();
my $restore_carrier_automation_guard = guard {
    note "Restoring carrier automation";
    Test::XTracker::Data->restore_carrier_automation_state( $auto_states );
};


# turn On Carrier Automation for each Channel
Test::XTracker::Data->set_carrier_automation_state( $_ => 'On' ) for keys %{ $channels };

# Setup framework
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

# set packing station name for operator
my $operator= $schema->resultset('Public::Operator')->search( { username => 'it.god' } )->first;
my $handler = Test::XTracker::Mock::Handler->new({
    operator_id => $operator->id,
});

my $mech = $framework->mech;

CHANNEL:
foreach my $channel ( sort { $b->{id} <=> $a->{id} } values %{ $channels } ) {
    if (($dc_name eq 'DC2') && ($channel->{name} eq 'MRPORTER.COM')) {
        note 'TODO: MrPorter tests have been omitted on DC2';
        # DC2 missing data for MRP makes this test fail
        # TODO: find a BA who can tell us what the shipping charges should be
        next CHANNEL;
    }

    test_prefix($channel->{name});
    note "Testing Channel: ".$channel->{name}." (".$channel->{id}.")";
    my $channel_id  = $channel->{id};
    my $pids        = Test::XTracker::Data->find_or_create_products( { channel_id => $channel_id } );
    my $customer    = Test::XTracker::Data->find_customer( { channel_id => $channel_id } );

    Test::XTracker::Data->ensure_stock( $pids->[0]{pid}, $pids->[0]{size_id}, $channel_id );

    # now DHL is DC2's default carrier for international deliveries need to explicitly set
    # the carrier to 'UPS' for this DC2CA test
    my $default_carrier = $dc_name eq "DC2"
        ? 'UPS'
        : config_var('DistributionCentre', 'default_carrier');

    # get shipping account for Domestic UPS
    my $shipping_account    = Test::XTracker::Data->find_or_create_shipping_account({
        channel_id => $channel_id,
        acc_name   => 'Domestic',
        carrier    => $default_carrier."%",
    });

    my $address = Test::XTracker::Data->create_order_address_in(
        "current_dc_premier",
    );

    # go get some pids relevant to the db I'm using - channel is for test
    # context
    my $tmp = undef;
    ($tmp,$pids) = Test::XTracker::Data->grab_products({
            how_many => 1,
    });

    my $base = {
        customer_id          => $customer->id,
        channel_id           => $channel_id,
        shipment_type        => $SHIPMENT_TYPE__DOMESTIC,
        shipment_status      => $SHIPMENT_STATUS__PROCESSING,
        shipment_item_status => $SHIPMENT_ITEM_STATUS__NEW,
        shipping_account_id  => $shipping_account->id,
        invoice_address_id   => $address->id,
        shipping_charge_id   => 4
    };

    my ($order, $order_hash) = Test::XTracker::Data->apply_db_order({
        base => $base,
        pids => $pids,
        price => [qw/100.00/],
    });

    # make sure products aren't restricted
    Test::XTracker::Data::Order->clear_item_shipping_restrictions( $order->get_standard_class_shipment );

    my $order_nr = $order->order_nr;
    note "Shipping Acc.: ".$shipping_account->id;
    note "Order Nr: $order_nr";
    note "Cust Nr/Id : ".$customer->is_customer_number."/".$customer->id;

    $mech->order_nr($order_nr);

    my ($ship_nr, $status, $category) = gather_order_info();
    note "Shipment Nr: $ship_nr";

    # The order status might be Credit Hold. Check and fix if needed
    if ($status eq "Credit Hold") {
        Test::XTracker::Data->set_department('it.god', 'Finance');
        $mech->reload;
        $mech->follow_link_ok({ text_regex => qr/Accept Order/ }, "Order approved");
        ($ship_nr, $status, $category) = gather_order_info();
    }
    is($status, $mech->get_table_value('Order Status:'), "Order is accepted");

    # make the shipment autoable for DC2 shouldn't be for DC1
    my $nc = NAP::Carrier->new({
        schema      => Test::XTracker::Data->get_schema,
        shipment_id => $ship_nr,
        operator_id => $handler->operator_id,
    });
    $nc->deduce_autoable;

    if ( $dc_name eq "DC2" ) {
        cmp_ok( $schema->resultset('Public::Shipment')->find( $ship_nr )->is_carrier_automated, '==', 1, "Shipment is Automated" );
        test_edit_ship_address_dc2( $mech, $ship_nr, $channel );
    }
    else {
        cmp_ok( $schema->resultset('Public::Shipment')->find( $ship_nr )->is_carrier_automated, '==', 0, "Shipment is NOT Automated" );
        test_edit_ship_address_dc1( $mech, $ship_nr, $channel, 1 );
    }
}

test_edit_ship_address_restrictions();
test_customer_email_form();
test_no_shipping_country_change_on_fulfilment_only();

done_testing;

=head1 TESTS

=head2 test_edit_ship_address_dc2

 $mech = test_edit_ship_address_dc2($mech,$shipment_id,$channel,$oktodo)

For DC2, this tests that the shipping address can be edited
and that the RTCB (autoable) flag and the AV Quality field
are updated correctly and the DHL Destination Code is always empty.

RTCB = Real-Time Carrier Booking

=cut

sub test_edit_ship_address_dc2 {
    my ($mech,$ship_nr,$channel) = @_;

    my $schema      = Test::XTracker::Data->get_schema;

    my $shipment    = $schema->resultset('Public::Shipment')->find( $ship_nr );
    my $rtcb_log    = $shipment->log_shipment_rtcb_states->search(undef,{ order_by => 'id DESC' });
    my $ups_qrt     = get_ups_qrt( $channel->{config_section} );

    # NOTE: As far as I can tell this makes *REAL* calls to UPS... should
    # probably be moved to t/40-external (or even deleted maybe)
    my %test_addresses  = (
        bad_address => {
            first_name      => 'Bad',
            last_name       => 'Address',
            address_line_1  => '123 Acatia Avenue',
            address_line_2  => 'a2',
            towncity        => 'New York',
            county          => 'NY',
            postcode        => '1234',
            country         => 'United States',
        },
        good_address    => {
            first_name      => 'Barack',
            last_name       => 'Obama',
            address_line_1  => 'The Whitehouse',
            address_line_2  => '1600 Pennsylvania Avenue, NW',
            towncity        => 'Washington',
            county          => 'DC',
            postcode        => '20500',
            country         => 'United States',
        },
        good_address_2  => {
            first_name      => 'Good',
            last_name       => 'Address',
            address_line_1  => '101 Main Street',
            address_line_2  => 'difference',
            towncity        => 'Pittsburgh',
            county          => 'PA',
            postcode        => '15228',
            country         => 'United States',
        },
        foreign_address => {
            first_name      => 'Foreign',
            last_name       => 'Address',
            address_line_1  => 'Unit 3',
            address_line_2  => 'Charlton Gate Business Park',
            towncity        => 'London',
            county          => '',
            postcode        => 'SE7 7RU',
            country         => 'United Kingdom',
        },
    );
    my %check_addr_fields   = (
        first_name      => 'First Name',
        last_name       => 'Surname',
        address_line_1  => 'Address Line 1',
        address_line_2  => 'Address Line 2',
        towncity        => 'Town/City',
        county          => 'County',
        postcode        => 'Postcode',
        country         => 'Country',
    );


    note "TESTING Edit Ship Address DC2";

    # Splitting this out in to a piece of reusable code
    my $update_address = sub {
        my ( $address_key, $address_name, %options ) = @_;
        my $address_hash = $test_addresses{ $address_key } ||
            die "No address $address_key";

        note("Setting the address to $address_name [$address_key]");
        my $tp = "Tests against: [$address_name]: ";

        # View the order
        $mech->order_view_url;

        # Go to the Edit Shipping Address page
        $mech->follow_link_ok({ text_regex => qr/Edit Shipping Address/ });

        # New step - choose address from the customer set
        $framework->flow_mech__customercare__choose_address();

        # Fill the target address
        $mech->submit_form_ok({
            with_fields => $address_hash,
            button      => 'submit'
        }, 'Update the address to ' . $address_name );
        $mech->no_feedback_error_ok;
        $mech->submit_form_ok(
            { form_name => "editAddress", button => "submit" },
            "Confirm Select Shipping Option",
        );

        # Did that look right?
        _check_form_address( $mech, \%check_addr_fields,
            $address_hash );

        # Confirm it
        $mech->submit_form_ok({
            form_name   => 'editAddress',
            button      => 'submit'
        }, 'Confirm Bad Address' );
        $mech->no_feedback_error_ok;

        # Update our local copies of the DB objects
        $shipment->discard_changes;
        $rtcb_log->reset;

        # Check the address has been changed in the DB
        _check_table_address( $shipment->shipment_address,
            $address_hash );

        # Check the DHL destination is not set
        is( $shipment->destination_code, undef, $tp . 'DHL Destination code is empty' );

        # Check carrier automation flag
        my $is_carrier_automated = $options{'is_carrier_automated'}
            // die "Please specify 'is_carrier_automated'";
        is( $shipment->is_carrier_automated, $is_carrier_automated,
            $tp .  'Shipment is ' . ($is_carrier_automated ? '' : 'NOT ') . 'automated' );

        # Check RTCB log reason
        like(
            $rtcb_log->first->reason_for_change,
            ($options{'log_reason'} // die "Please specify 'log_reason'"), #/
            "${tp}RTCB Log reason matches: $options{'log_reason'}"
        );

        # Check av_quality
        my $av_quality = $shipment->av_quality_rating || 0;
        if ( $options{'passes_av_quality'} // die "Please specify 'passes_av_quality'" ) { #/
            cmp_ok( $av_quality, '>=', $ups_qrt,
                "${tp}Shipment AV Quality [$av_quality] >= [$ups_qrt]");
        } else {
            cmp_ok( $av_quality, '<', $ups_qrt,
                "${tp}Shipment AV Quality [$av_quality] < [$ups_qrt]");
        }

        test_prefix('');
    };

    # 'bad_address' - Should unautomate the shipment, av_quality is too low
    $update_address->('bad_address', 'Bad Address',
        is_carrier_automated => 0,
        passes_av_quality    => 0,
        log_reason           =>
            qr/^AUTO: Changed because of an Address Validation/
    );

    # 'good_address' - Should reautomate the shipment, av_quality is ok
    $update_address->('good_address', 'Good Address',
        is_carrier_automated => 1,
        passes_av_quality    => 1,
        log_reason           =>
            qr/Changed because of an Address Validation check/
    );

    # 'good_address' - Should reautomate the shipment, av_quality is ok
    $update_address->('good_address', 'Good Address, Second Attempt',
        is_carrier_automated => 1,
        passes_av_quality    => 1,
        log_reason           =>
            qr/Changed because of an Address Validation check/
    );

    return if $shipment->order->channel->business->fulfilment_only;

    subtest 'test foreign address' => sub {
        $mech->follow_link_ok({ text_regex => qr/Edit Shipping Address/ });

        # New step - choose address from the customer set
        $framework->flow_mech__customercare__choose_address();

        $mech->submit_form_ok({
                with_fields => $test_addresses{foreign_address},
                button      => 'submit',
            }, 'Edit with Foreign Address' );
        $mech->no_feedback_error_ok;
        $mech->submit_form_ok(
            { form_name => "editAddress", button => "submit" },
            "Confirm Select Shipping Option",
        );

        note $mech->uri;
        _check_form_address( $mech, \%check_addr_fields, $test_addresses{foreign_address} );
        $mech->submit_form_ok({
                form_name   => 'editAddress',
                button      => 'submit',
            }, 'Confirm Foreign Address' );
        $mech->no_feedback_error_ok;
        $shipment->discard_changes;
        $rtcb_log->reset;
        _check_table_address( $shipment->shipment_address, $test_addresses{foreign_address} );
        ok( !$shipment->is_carrier_automated, 'Shipment is NOT Automated' );
    };

    # test setting good addresses but with the Automation State turned 'Off' so that
    # they should always be non-autoable

    subtest 'test automation import off only with good address' => sub {
        # first set the State to being 'Import_Off_Only' which should make no difference
        Test::XTracker::Data->set_carrier_automation_state( $channel->{id}, 'Import_Off_Only' );
        $mech->follow_link_ok({ text_regex => qr/Edit Shipping Address/ });

        # New step - choose address from the customer set
        $framework->flow_mech__customercare__choose_address();

        $mech->submit_form_ok({
                with_fields => $test_addresses{good_address},
                button      => 'submit',
            }, "Edit with Good Address with Automation State set to 'Import_Off_Only'" );
        $mech->no_feedback_error_ok;
        $mech->submit_form_ok(
            { form_name => "editAddress", button => "submit" },
            "Confirm Select Shipping Option",
        );

        _check_form_address( $mech, \%check_addr_fields, $test_addresses{good_address} );
        $mech->submit_form_ok({
                form_name   => 'editAddress',
                button      => 'submit',
            }, "Confirm Good Address with Automation State set to 'Import_Off_Only'" );
        $mech->no_feedback_error_ok;
        $shipment->discard_changes;
        $rtcb_log->reset;
        _check_table_address( $shipment->shipment_address, $test_addresses{good_address} );
        ok( $shipment->is_carrier_automated, 'Shipment IS Automated' );
        is( $shipment->destination_code, undef, 'DHL Destination Code is Empty' );
        cmp_ok( $shipment->av_quality_rating, '>=', $ups_qrt, 'Shipment AV Quality ('.$shipment->av_quality_rating.') >= Threshold ('.$ups_qrt.')' );
        like( $rtcb_log->first->reason_for_change, qr/Changed because of an Address Validation check/, 'RTCB Log Reason because of AV Check' );
    };

    # now set the State to being 'Off' which should mean the shipment should be non-autoable
    subtest 'test automation off with good address' => sub {
        Test::XTracker::Data->set_carrier_automation_state( $channel->{id}, 'Off' );
        $mech->follow_link_ok({ text_regex => qr/Edit Shipping Address/ });

        # New step - choose address from the customer set
        $framework->flow_mech__customercare__choose_address();

        $mech->submit_form_ok({
                with_fields => $test_addresses{good_address_2},
                button      => 'submit',
            }, "Edit with Good Address 2 with Automation State set to 'Off'" );
        $mech->no_feedback_error_ok;
        $mech->submit_form_ok(
            { form_name => "editAddress", button => "submit" },
            "Confirm Select Shipping Option",
        );

        _check_form_address( $mech, \%check_addr_fields, $test_addresses{good_address_2} );
        $mech->submit_form_ok({
                form_name   => 'editAddress',
                button      => 'submit',
            }, "Confirm Good Address 2 with Automation State set to 'Off'" );
        $mech->no_feedback_error_ok;
        $shipment->discard_changes;
        $rtcb_log->reset;
        _check_table_address( $shipment->shipment_address, $test_addresses{good_address_2} );
        ok( !$shipment->is_carrier_automated, 'Shipment is NOT Automated' );
        is( $shipment->destination_code, undef, 'DHL Destination Code is Empty' );
        is( $shipment->av_quality_rating, '', 'Shipment AV Quality is empty' );
        like( $rtcb_log->first->reason_for_change, qr/^STATE: Carrier Automation State is 'Off'/, 'RTCB Log Reason because State is Off' );
    };

    # now turn back on again and shipment should be autoable
    subtest 'test automation on with good address' => sub {
        Test::XTracker::Data->set_carrier_automation_state( $channel->{id}, 'On' );
        $mech->follow_link_ok({ text_regex => qr/Edit Shipping Address/ });

        # New step - choose address from the customer set
        $framework->flow_mech__customercare__choose_address();

        $mech->submit_form_ok({
                with_fields => $test_addresses{good_address},
                button      => 'submit',
            }, "Edit with Good Address with Automation State back to 'On'" );
        $mech->no_feedback_error_ok;
        $mech->submit_form_ok(
            { form_name => "editAddress", button => "submit" },
            "Confirm Select Shipping Option",
        );

        _check_form_address( $mech, \%check_addr_fields, $test_addresses{good_address} );
        $mech->submit_form_ok({
                form_name   => 'editAddress',
                button      => 'submit',
            }, "Confirm Good Address with Automation State back to 'On'" );
        $mech->no_feedback_error_ok;
        $shipment->discard_changes;
        $rtcb_log->reset;
        _check_table_address( $shipment->shipment_address, $test_addresses{good_address} );
        ok( $shipment->is_carrier_automated, 'Shipment IS Automated' );
        is( $shipment->destination_code, undef, 'DHL Destination Code is Empty' );
        cmp_ok( $shipment->av_quality_rating, '>=', $ups_qrt, 'Shipment AV Quality ('.$shipment->av_quality_rating.') >= Threshold ('.$ups_qrt.')' );
        like( $rtcb_log->first->reason_for_change, qr/Changed because of an Address Validation check/, 'RTCB Log Reason because of AV Check' );
    };

    return;
}

=head2 test_edit_ship_address_dc1

 $mech  = test_edit_ship_address_dc1($mech,$shipment_id,$channel,$oktodo)

For DC1, this tests that the DHL destination code gets filled in when editing the Shipping Address and the Shipment always remains NON Autoable.

=cut

sub test_edit_ship_address_dc1 {
    my ($mech,$ship_nr,$channel,$oktodo)    = @_;

    my $schema      = Test::XTracker::Data->get_schema;

    my $shipment    = $schema->resultset('Public::Shipment')->find( $ship_nr );

    my %test_addresses  = (
            bad_address => {
                first_name      => 'Bad',
                last_name       => 'Address',
                address_line_1  => '123 Acatia Avenue',
                address_line_2  => 'a2',
                towncity        => '',
                county          => '',
                postcode        => '',
                country         => 'United Kingdom',
            },
            good_address    => {
                first_name      => 'Good',
                last_name       => 'Address',
                address_line_1  => '101 Main Street',
                address_line_2  => 'a2',
                towncity        => 'Glasgow',
                county          => 'Lanarkshire',
                postcode        => 'G2 3QA',
                country         => 'United Kingdom',
            },
            foreign_address => {
                first_name      => 'Foreign',
                last_name       => 'Address',
                address_line_1  => '34 High Street',
                address_line_2  => 'a2',
                towncity        => 'Pittsburgh',
                county          => 'PA',
                postcode        => '15228',
                country         => 'United States',
            },
        );
    my %check_addr_fields   = (
            first_name      => 'First Name',
            last_name       => 'Surname',
            address_line_1  => 'Address Line 1',
            address_line_2  => 'Address Line 2',
            towncity        => 'Town/City',
            county          => 'County',
            postcode        => 'Postcode',
            country         => 'Country',
        );

    SKIP: {
        skip "test_edit_ship_address_dc1",1     if ( !$oktodo );

        note "TESTING Edit Ship Address DC1";

#       $mech->get_ok( $mech->order_view_url );
        $mech->follow_link_ok({ text_regex => qr/Edit Shipping Address/ });

        # New step - choose address from the customer set
        $framework->flow_mech__customercare__choose_address();

        $mech->submit_form_ok({
                with_fields => $test_addresses{bad_address},
                button      => 'submit',
            }, 'Edit with Bad Address' );
        $mech->no_feedback_error_ok;
        $mech->submit_form_ok(
            { form_name => "editAddress", button => "submit" },
            "Confirm Select Shipping Option",
        );

        _check_form_address( $mech, \%check_addr_fields, $test_addresses{bad_address} );
        $mech->submit_form_ok({
                form_name   => 'editAddress',
                button      => 'submit',
            }, 'Confirm Bad Address' );
        $mech->no_feedback_error_ok;
        $shipment->discard_changes;
        _check_table_address( $shipment->shipment_address, $test_addresses{bad_address} );
        note "shipment_id: ". $shipment->id;
        is( $shipment->destination_code, '', 'DHL Destination Code is Empty' );
        ok( !$shipment->is_carrier_automated, 'Shipment is NOT Automated' );

        $mech->order_view_url;
        $mech->follow_link_ok({ text_regex => qr/Edit Shipping Address/ });

        # New step - choose address from the customer set
        $framework->flow_mech__customercare__choose_address();

        $mech->submit_form_ok({
                with_fields => $test_addresses{good_address},
                button      => 'submit',
            }, 'Edit with Good Address' );
        $mech->no_feedback_error_ok;
        $mech->submit_form_ok(
            { form_name => "editAddress", button => "submit" },
            "Confirm Select Shipping Option",
        );

        _check_form_address( $mech, \%check_addr_fields, $test_addresses{good_address} );
        $mech->submit_form_ok({
                form_name   => 'editAddress',
                button      => 'submit',
            }, 'Confirm Good Address' );
        $mech->no_feedback_error_ok;
        $shipment->discard_changes;
        _check_table_address( $shipment->shipment_address, $test_addresses{good_address} );
        is( $shipment->destination_code, 'GLA', 'DHL Destination Code is set to Glasgow ('.$shipment->destination_code.')' );
        ok( !$shipment->is_carrier_automated, 'Shipment is NOT Automated' );

        $mech->order_view_url;
        $mech->follow_link_ok({ text_regex => qr/Edit Shipping Address/ });

        # New step - choose address from the customer set
        $framework->flow_mech__customercare__choose_address();

        unless ($channel->{fulfilment_only}) {
            $mech->submit_form_ok({
                    with_fields => $test_addresses{foreign_address},
                    button      => 'submit',
                }, 'Edit with Foreign Address' );
            $mech->no_feedback_error_ok;
            $mech->submit_form_ok(
                { form_name => "editAddress", button => "submit" },
                "Confirm Select Shipping Option",
            );

            _check_form_address( $mech, \%check_addr_fields, $test_addresses{foreign_address} );
            $mech->submit_form_ok({
                    form_name   => 'editAddress',
                    button      => 'submit',
                }, 'Confirm Foreign Address' );
            $mech->no_feedback_error_ok;
            $shipment->discard_changes;
            _check_table_address( $shipment->shipment_address, $test_addresses{foreign_address} );
            is( $shipment->destination_code, 'PIT', 'DHL Destination Code is set to Pittsburgh ('.$shipment->destination_code.')' );
            ok( !$shipment->is_carrier_automated, 'Shipment is NOT Automated' );
        }
    }

    return $mech;
}

# test_no_shipping_country_change_on_fulfilment_only - ensure that any attempt
# to change the shipping country on an order for a fulfilment only channel
# results in an error and does not cause an internal server error.

sub test_no_shipping_country_change_on_fulfilment_only {

    my $schema      = Test::XTracker::Data->get_schema;

    # Get a fulfilment_only channel
    my $channel     = Test::XTracker::Data->fulfilment_only_channel;
    SKIP: {
        skip "No Fulfilment Channel To Test", 13 unless $channel;

        my $pid_set     = Test::XTracker::Data->get_pid_set({ jc  => 1, });

        my $pids = $pid_set->{(keys %{$pid_set})[0]};

        my $order       = Test::XTracker::Data->create_domestic_order(
                                channel => $channel,
                                pids    => $pids->{pids},
                                date    => DateTime->now(time_zone => $channel->timezone),
                          );

        my $shipment    = $order->get_standard_class_shipment;

        # TODO - if we launch a DC in .ru we will need to change this!
        my $address_obj = Test::XTracker::Data->create_order_address_in('Russia');
        my $new_address = {
            address_line_1  => $address_obj->address_line_1,
            address_line_2  => $address_obj->address_line_2,
            towncity        => $address_obj->towncity,
            county          => $address_obj->county,
            postcode        => $address_obj->postcode,
            country         => $address_obj->country,
        };

        $mech->order_nr( $order->order_nr );
        $mech->get_ok( $mech->order_view_url );
        $mech->follow_link_ok({ text_regex => qr/Edit Shipping Address/ });

        # New step - choose address from the customer set
        $framework->flow_mech__customercare__choose_address();

        $mech->errors_are_fatal(0);

        $mech->submit_form_ok({
                with_fields => $new_address,
                button      => 'submit',
            }, 'Edit with Bad Address' );
        $mech->has_feedback_error_ok( qr/Cannot change shipping country for a 'fulfilment only' business/ );
    }
}

sub test_edit_ship_address_restrictions {

    my ( $pids, $product, $order ) = _new_order();

    my ( $country_pass, $country_fail ) = Test::XTracker::Data::Shipping
        ->get_restriction_countries_and_update_product( $product->discard_changes );
    note "Using Valid Country: '" . $country_pass->country . "', and Invalid Country: '" . $country_fail->country . "'";
    note "Using Product: " . $product->id . " and Variant: " . $pids->[0]{variant}->id;

    # Get the order view page for this order.
    $mech->order_nr( $order->order_nr );
    $mech->order_view_url;

    # Get the edit address page.
    $mech->follow_link_ok( { text_regex => qr/Edit Shipping Address/ } );

    # New step - choose address from the customer set
    $framework->flow_mech__customercare__choose_address();

    # Test for failure.
    $mech->submit_form_ok( {
        with_fields => {
            country => $country_fail->country,
        },
    }, 'Submitted edit address form with invalid country' );
    $mech->has_feedback_error_ok( qr/Cannot update address, order contains restricted products \(see below\)/i );

    like( $mech->content, qr/Chinese origin product/i, 'Got correct restriction' )
                    or diag "Data Used: Shipping Attribute: "
                            . p( $product->discard_changes->shipping_attribute )
                            . "\nFirst Shipment Item: " . p( $order->discard_changes->get_standard_class_shipment->shipment_items->first );

    # Test for success.
    $mech->get_ok($mech->order_view_url);
    $mech->follow_link_ok( { text_regex => qr/Edit Shipping Address/ } );
    $framework->flow_mech__customercare__choose_address();

    $mech->submit_form_ok( {
        with_fields => {
            country => $country_pass->country,
        },
    }, 'Submitted edit address form with valid country' );
    $mech->no_feedback_error_ok;

    # de-restrict the Product so that other
    # tests don't have problems with it
    $product->discard_changes->shipping_attribute->update( {
        fish_wildlife   => 0,
        cites_restricted=> 0,
        is_hazmat       => 0,
    } );
}

=head2 test_customer_email_form

Test the email confirmation form on the Edit Address page.

This can be reached from: Order View -> Edit Shipping Address

It's the final page of editing the address, when the email text
is confirmed.

=cut

sub test_customer_email_form {

    note 'Testing the Customer Email form';

    # Get the correspondence template
    my $template = $schema
        ->resultset('Public::CorrespondenceTemplate')
        ->find( $CORRESPONDENCE_TEMPLATES__CONFIRM_PRICE_CHANGE__1 );

    # Record the original values. We can't use a transaction,
    # because otherwise the Web App would not see the changes.
    my $old_subject = $template->subject;
    my $old_content = $template->content;

    # Update to known values.
    $template->update( {
        subject => 'Test Subject',
        content => 'Test Content',
    } );

    # Grab a new order.
    my ( $pids, $product, $order ) = _new_order();

    # Make the order free, so the new shipping charge puts it
    # over the limit.
    foreach my $shipment ( $order->shipments ) {

        $shipment->update( {
            shipping_charge => 0,
        } );

        foreach my $shipment_item ( $shipment->shipment_items ) {

            $shipment_item->update( {
                tax        => 0,
                duty       => 0,
                unit_price => 0,
            } );

        }

    }

    # Get the order view page for this order.
    $mech->order_nr( $order->order_nr );
    $mech->order_view_url;

    # Edit the shipping address to be a different country (so we get a
    # large shipping charge) and get to the final confirmation
    # page.
    $framework
        ->flow_mech__customercare__edit_shipping_address
        ->flow_mech__customercare__choose_address
        ->flow_mech__customercare__edit_address(
            $order->get_standard_class_shipment_address_country eq 'United Kingdom'
                ? {
                    county  => 'NY',
                    country => 'United States'
                }
                : {
                    county  => '',
                    country => 'United Kingdom'
                }
        )
        ->flow_mech__customercare__confirm_address;

    # We should get no errors.
    $mech->no_feedback_error_ok;

    # Make sure the email is displayed correctly.
    is_deeply( $mech->as_data->{customer_email}, {
        'Email Text' => 'Test Content',
        'From' => {
            'input_name'  => 'email_from',
            'input_value' => customercare_email( $order->channel->business->config_section, {
                schema => $schema,
                locale => $order->customer->locale,
            } ),
            'value' => ''
        },
        'Reply-To' => {
            'input_name'  => 'email_replyto',
            'input_value' => customercare_email( $order->channel->business->config_section, {
                schema => $schema,
                locale => $order->customer->locale,
            } ),
            'value' => ''
        },
        'Send Email' => {
            'input_name'  => 'send_email',
            'input_value' => 'yes',
            'value' => 'Yes No'
        },
        'Subject' => {
            'input_name'  => 'email_subject',
            'input_value' => 'Test Subject',
            'value' => ''
        },
        'To' => {
            'input_name'  => 'email_to',
            'input_value' => $order->email,
            'value' => ''
        },
    }, 'Email template is present and contains the correct data' );

    # Restore the template to it's original values.
    $template->update( {
        subject => $old_subject,
        content => $old_content,
    } );

}

#------------------------------------------------------------------------------------------------

sub _new_order {

    # Get a product to test with.
    my ( undef, $pids ) = Test::XTracker::Data->grab_products( {
        how_many => 1,
        # The channel must not be fuilfilment only, as you cannot change
        # the country on the Edit Shipping Address page.
        channel  => $schema->resultset('Public::Channel')->fulfilment_only(0)->first,
    } );

    my $product = $schema->resultset('Public::Product')->find( $pids->[0] );
    isa_ok( $product, 'XTracker::Schema::Result::Public::Product' );

    # Create a new order.
    my ( $order ) = Test::XTracker::Data->apply_db_order( {
        pids  => $pids,
        base => {
            shipment_status      => $SHIPMENT_STATUS__PROCESSING,
            shipment_item_status => $SHIPMENT_ITEM_STATUS__NEW,
        },
    } );

    isa_ok( $order, 'XTracker::Schema::Result::Public::Orders' );
    note 'Order Number: ' . $order->order_nr;

    return ( $pids, $product, $order );

}

# this checks the new address shown on the confirm screen matches
# what should have been submitted
sub _check_form_address {
    my ( $mech, $chk_flds, $address )   = @_;

    subtest 'test form address' => sub {
        foreach ( keys %{ $chk_flds } ) {
            $mech->content_like( qr/$chk_flds->{$_}:.*$address->{$_}/s, 'Form Field: '.$chk_flds->{$_}.' should be '.$address->{$_} );
        }
    };
}

# this checks the columns in a table have been updated correctly
# with the address that has been submitted
sub _check_table_address {
    my ( $addr_rec, $address )  = @_;
    subtest 'test table-address' => sub {
        while (my ($column, $expected) = each %$address) {
            is $addr_rec->get_column($column), $expected,
                "Column: $column should be $expected";
        }
    };
}

# set's up user's permissions and preferences
sub setup_user_perms {
    Test::XTracker::Data->grant_permissions('it.god', 'Customer Care', 'Order Search', 2);

    # Perms needed for the order process
    for (qw/Airwaybill Dispatch Packing Picking Selection Labelling/ ) {
        Test::XTracker::Data->grant_permissions('it.god', 'Fulfilment', $_, 2);
    }
    Test::XTracker::Data->grant_permissions('it.god', 'Fulfilment', 'Invalid Shipments', 2);

    my $operator= $schema->resultset('Public::Operator')->search( { username => 'it.god' } )->first;

    # set packing station name for operator
    my $handler = Test::XTracker::Mock::Handler->new({
        operator_id => $operator->id,
    });

    return $handler;
}

# First time check that we can get the order via search
# Other times go straight to that url
sub gather_order_info {
  my ($order_nr) = @_;

  $mech->get_ok($mech->order_view_url);

  # On the order view page we need to find the shipment ID

  my $ship_nr = $mech->get_table_value('Shipment Number:');

  my $status = $mech->get_table_value('Order Status:');


  my $category = $mech->get_table_value('Customer Category:');
  return ($ship_nr, $status, $category);
}
