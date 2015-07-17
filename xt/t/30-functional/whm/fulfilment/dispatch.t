#!/usr/bin/env perl

use NAP::policy qw/test/;

=head1 NAME

dispatch.t - Dispatch tests

=head1 DESCRIPTION

This test run is looped through all enabled channels, and through default and
premier shipments.

Test selection and test picking - if we're in IWS phase check the printouts
expected at picking (just an address card).

Pack the shipment.

For IWS, go the labelling page and submit the shipment, else go to assign the
air waybill if we have a domestic shipment (though according to Nuno this
shouldn't be required, so consider removing this bit or testing somewhere
else).

If we're on DC1 we test for the appropriate printouts (depending on the type of
shipment, we check for address cards, return proformas, shipping input form,
invoices and matchup sheets). This test should be extended to work on all DCs,
not just DC1!

Go to Fulfilment/Dispatch and check we have our expected shipment in the table.
Dispatch the shipment using its shipment number and check for a success
message. Check that we have sent the appropriate container empty messages.

If we have a domestic shipment, check we've sent the dispatch email (by looking
at the logs) and hack the shipment back to I<Packing> so we can try dispatching
it again using its air waybill number, and check that this worked.

If we have a premier shipment, test we didn't send a dispatch email.

Check we can't redispatch a dispatched shipment using waybill or shipment
numbers.

Switch to handheld mode.

Hack the shipment back to packing. Test successful dispatch and failed
redispatch both using waybill and shipment numbers.

Test Premier Dispatch in handheld mode, but only if we have a premier shipment
and we're in DC1. Hack the shipment so it's in an incorrect state for dispatch
(I<Cancelled>) and try dispatching, should fail.  Fix the shipment but change
the item to an incorrect state (I<Selected>) and try dispatching - should fail
again. Fix the item, and try dispatching - it should now pass. Try
redispatching, and we should see an error.

#TAGS toobig fulfilment dispatch whm

=cut

use FindBin::libs;


use XTracker::Constants::FromDB   qw(
                                        :business
                                        :shipment_status
                                        :shipment_item_status
                                        :shipment_type
                                        :authorisation_level
                                        :correspondence_templates
                                    );

use Test::XTracker::Data;
use Test::XTracker::Data::CMS;

use Test::XTracker::Mechanize;
use XTracker::Config::Local         qw( :DEFAULT :carrier_automation dc_address );
use XTracker::Database::Shipment    qw( get_postcode_shipping_charges get_state_shipping_charges get_country_shipping_charges
                                        :carrier_automation );
use XT::Domain::PRLs;

use Test::XTracker::PrintDocs;
use Test::XTracker::RunCondition
    export => [qw( $iws_rollout_phase $prl_rollout_phase )];
use Test::XTracker::Artifacts::RAVNI;

use Data::Dump  qw( pp );

my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::WMS',
        'Test::XT::Flow::PRL',
    ],
);
my $schema = $framework->schema;
my $mech = $framework->mech;
$mech->force_datalite(1);

# make sure the 'Dispatch Order' Email Template has CMS ID
Test::XTracker::Data::CMS->set_ifnull_cms_id_for_template( $CORRESPONDENCE_TEMPLATES__DISPATCH_ORDER );

my @channels= $schema->resultset('Public::Channel')->search({'is_enabled'=>1},{ order_by => 'id' })->all;

Test::XTracker::Data->set_department('it.god', 'Shipping');

__PACKAGE__->setup_user_perms;

$mech->do_login;

CHANNEL:
foreach my $channel ( @channels ) {

    note "Creating Order for Channel: ".$channel->name." (".$channel->id.")";

    # now DHL is DC2's default carrier for international deliveries need to explicitly set
    # the carrier to 'UPS' for this DC2CA test
    my $default_carrier = ( $channel->is_on_dc(2) ? 'UPS' : config_var('DistributionCentre','default_carrier') );

    my $ship_account    = Test::XTracker::Data->find_shipping_account( { channel_id => $channel->id, carrier => $default_carrier."%" } );
    my $prem_postcode   = Test::XTracker::Data->find_prem_postcode( $channel->id );
    my $postcode        = ( defined $prem_postcode ? $prem_postcode->postcode :
                            ( $channel->is_on_dc(2) ? '11371' : 'NW10 4GR' ) );
    my $dc_address = dc_address($channel);
    my $address         = Test::XTracker::Data->order_address( {
                    address         => 'create',
                    address_line_1  => $dc_address->{addr1},
                    address_line_2  => $dc_address->{addr2},
                    address_line_3  => $dc_address->{addr3},
                    towncity        => $dc_address->{city},
                    county          => '',
                    country         => $dc_address->{country},
                    postcode        => $postcode,
            } );

    my $pids        = Test::XTracker::Data->find_or_create_products( { channel_id => $channel->id, how_many => 2 } );
    my $customer    = Test::XTracker::Data->find_customer( { channel_id => $channel->id } );

    Test::XTracker::Data->ensure_stock( $pids->[0]{pid}, $pids->[0]{size_id}, $channel->id );

    my $order_args  = {
            customer_id => $customer->id,
            channel_id  => $channel->id,
            items => {
                $pids->[0]{sku} => { price => 100.00 },
            },
            shipment_type => $SHIPMENT_TYPE__DOMESTIC,
            shipment_status => $SHIPMENT_STATUS__PROCESSING,
            shipment_item_status => $SHIPMENT_ITEM_STATUS__NEW,
            shipping_account_id => $ship_account->id,
            invoice_address_id => $address->id,
            shipping_charge_id => 4,
        };

    # no gift messages for JC (?)
    if ($channel->name ne 'JIMMYCHOO.COM') {
        $order_args->{gift_shipment} = 1;
        $order_args->{gift_message} = "t\N{U+00E9}st gift \N{U+2764} message";
    }

    # create order
    my $standard_order   = Test::XTracker::Data->create_db_order( $order_args );

    # create premier order
    $order_args->{premier_routing_id} = 2;
    $order_args->{shipment_type} = $SHIPMENT_TYPE__PREMIER;
    my $premier_order   = Test::XTracker::Data->create_db_order( $order_args );

    foreach my $order ($premier_order, $standard_order) {
        my $print_directory = Test::XTracker::PrintDocs->new();

        my $order_nr = $order->order_nr;

        $mech->order_nr($order_nr);

        my ($ship_nr, $status, $category) = gather_order_info();
        my $shipment    = $schema->resultset('Public::Shipment')->find( $ship_nr );
        note "* testing [" . $shipment->shipment_type->type . "] shipment on channel " . $channel->name;

        note "Shipping Acc.: ".$ship_account->id;
        note "Order Nr: $order_nr";
        note "Shipment Nr: $ship_nr";
        note "Shipping Type: ".$shipment->shipment_type->type;
        note "Cust Nr/Id : ".$customer->is_customer_number."/".$customer->id;

        # The order status might be Credit Hold. Check and fix if needed
        if ($status eq "Credit Hold") {
            Test::XTracker::Data->set_department('it.god', 'Finance');
            $mech->reload;
            $mech->follow_link_ok({ text_regex => qr/Accept Order/ }, "Order approved");
            ($ship_nr, $status, $category) = gather_order_info();
        }
        is($status, $mech->get_table_value('Order Status:'), "Order is accepted");

        if ( $channel->is_on_dc(2) ) {
            # Need this to be nice and high otherwise it'll get put on hold
            # when we try to select it.
            $shipment->update({'av_quality_rating'=>100});
        }

        # Get shipment to packing stage
        my $skus= $mech->get_order_skus();
        if ($prl_rollout_phase) {
            Test::XTracker::Data::Order->allocate_shipment($shipment);
            Test::XTracker::Data::Order->select_shipment($shipment);
            my $container_id = Test::XT::Data::Container->get_unique_id({ how_many => 1 });
            $framework->flow_msg__prl__pick_shipment(
                shipment_id => $shipment->id,
                container => {
                    $container_id => [keys %$skus],
                }
            );
            $framework->flow_msg__prl__induct_shipment(shipment_row => $shipment);
        } else {
            $mech->test_direct_select_shipment( $ship_nr );
            $skus = $mech->get_info_from_picklist($print_directory,$skus) if $iws_rollout_phase == 0;
            $mech->test_pick_shipment($ship_nr, $skus);
        }

        if ($iws_rollout_phase) {
            # send the print at pick request
            $framework->flow_wms__send_ready_for_printing(
                shipment_id => 's-' . $shipment->id,
                pick_station => 1,
            );
            # check we printed what we should have
            test_pick_print_docs($shipment, $print_directory);
        }

        $mech->test_pack_shipment( $ship_nr, $skus );

        if (config_var('Fulfilment', 'labelling_subsection')) {
            $mech->test_labelling( $ship_nr );
        }
        else {
            # According to Nuno this bit is never required, as waybills are
            # added either at packing or labelling. I'm refactoring though and
            # I don't want to remove this test altogether
            $mech->test_assign_airway_bill( $ship_nr ) if $shipment->is_domestic;
        }
        # So after some refactoring it looks like this test is only done for
        # DC1... no idea why :/ But as it doesn't pass for DC2/3 I'll keep the
        # behaviour and make a call to new_files otherwise so we don't barf.
        # TODO: FIXME ACROSS ALL DCs!
        if ( config_var('Fulfilment', 'labelling_subsection') ) {
            test_dispatch_print_docs($shipment, $print_directory)
        }
        else {
            $print_directory->new_files;
        }

        test_dispatch($mech,$ship_nr);
    }
}

# restore CMS Id on Email Template
Test::XTracker::Data::CMS->restore_cms_id_for_template( $CORRESPONDENCE_TEMPLATES__DISPATCH_ORDER );

done_testing;


=head2 test_dispatch

 $mech  = test_dispatch($mech,$shipment_id,$oktodo)

This tests the Dispatch process by either using a Shipment Id or a Outward AWB, also tests that the dispatch process works in both normal Full Screen mode and Hand Held mode.

=cut

sub test_dispatch {
    my ($mech,$ship_nr)     = @_;

    my $schema      = Test::XTracker::Data->get_schema;

    my $shipment    = $schema->resultset('Public::Shipment')->find( $ship_nr );

    # We need to ensure that the shipment's air-waybills are unique, else it could screw up the below tests
    my ($out_awb, $ret_awb) = Test::XTracker::Data->generate_air_waybills({ require_unique => 1 });
    $shipment->update({
        outward_airway_bill => $out_awb,
        return_airway_bill  => $ret_awb
    });

    my $ship_emails_rs  = $shipment->shipment_email_logs
                                    ->search( {}, { order_by => 'id DESC' } );

    note "TESTING Dispatch";

    # Test normal full screen mode

    # check that when Manager level access can see List of Shipments
    Test::XTracker::Data->grant_permissions( 'it.god', 'Fulfilment', 'Dispatch', $AUTHORISATION_LEVEL__MANAGER );
    $mech->get_ok('/Fulfilment/Dispatch');
    $mech->content_like( qr/Shipments Awaiting Dispatch/, "Can find Table of Shipments as Manager" );

    # check that when Operator level access can't see List of Shipments
    Test::XTracker::Data->grant_permissions( 'it.god', 'Fulfilment', 'Dispatch', $AUTHORISATION_LEVEL__OPERATOR );

    # get the last email log Id
    my $last_email_log_id   = ( $ship_emails_rs->reset->count ? $ship_emails_rs->first->id : 0 );

    # using Shipment Id
    $mech->get_ok('/Fulfilment/Dispatch');
    $mech->content_unlike( qr/Shipments Awaiting Dispatch/, "Can't find Table of Shipments as Operator" );
    my $xt_to_prls = Test::XTracker::Artifacts::RAVNI->new('xt_to_prls');
    $mech->submit_form_ok({
        with_fields => {
                shipment_id     => $ship_nr,
            },
        button  => 'submit'
    }, "Full Page - Using Shipment Id: ".$ship_nr );
    $mech->no_feedback_error_ok;
    $mech->has_feedback_success_ok(qr/The shipment was successfully dispatched/,"Shipment Dispatched by Id");

    _check_container_empty_messages($xt_to_prls, $shipment);

    # reset shipment status
    $shipment->discard_changes;

    if ( $shipment->shipment_type_id == $SHIPMENT_TYPE__DOMESTIC ) {
        # check Dispatch Email was sent
        my $latest_email_log  = $ship_emails_rs->reset->first;
        isa_ok( $latest_email_log, 'XTracker::Schema::Result::Public::ShipmentEmailLog', "Got an Email Log Record" );
        cmp_ok( $latest_email_log->id, '>', $last_email_log_id, "and it's New" );
        cmp_ok( $latest_email_log->correspondence_templates_id, '==', $CORRESPONDENCE_TEMPLATES__DISPATCH_ORDER,
                                                "and it's for the correct Template: 'Dispatch Order'" );

        # Dispatch again but by using Outward AWB
        $shipment->update({ shipment_status_id => $SHIPMENT_STATUS__PROCESSING });
        $shipment->shipment_items->update({ shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PACKED });
        $xt_to_prls = Test::XTracker::Artifacts::RAVNI->new('xt_to_prls');
        $mech->submit_form_ok({
            with_fields => {
                shipment_id     => $out_awb,
            },
            button  => 'submit'
        }, "Full Page - Using Outward AWB: ".$out_awb );
        $mech->no_feedback_error_ok;
        $mech->has_feedback_success_ok(qr/The shipment was successfully dispatched/,"Shipment Dispatched by AWB");
        if ($prl_rollout_phase and $shipment->has_containers) {
            _check_container_empty_messages($xt_to_prls, $shipment);
        }
        $shipment->discard_changes;
        cmp_ok( $shipment->shipment_status_id, "==", $SHIPMENT_STATUS__DISPATCHED, "Shipment Status is set to Dispatched" );
    }
    elsif ( $shipment->shipment_type_id == $SHIPMENT_TYPE__PREMIER ) {
        # check Dispatch Email was NOT sent for Premier Shipments
        my $latest_email_log_id = ( $ship_emails_rs->reset->count ? $ship_emails_rs->first->id : 0 );
        cmp_ok( $latest_email_log_id, '==', $last_email_log_id,
                                    "No new Emails have been Sent for Premier Shipment when it was Dispatched" );
    }

    # Test both ways can't be re-dispatched

    # with Shipment Id
    $mech->submit_form_ok({
        with_fields => {
                shipment_id     => $ship_nr,
            },
        button  => 'submit'
    }, "Re-Dispatch Full Page - Using Shipment Id: ".$ship_nr );
    $mech->has_feedback_error_ok( qr/The shipment has already been dispatched/, "Already Dispatched with Id" );

    if ($shipment->shipment_type->id eq $SHIPMENT_TYPE__DOMESTIC) {
        # with Outward AWB
        $mech->submit_form_ok({
            with_fields => {
                    shipment_id     => $out_awb,
                },
            button  => 'submit'
        }, "Re-Dispatch Full Page - Using Outward AWB: ".$out_awb );
        $mech->has_feedback_error_ok( qr/Could not find an Un-Dispatched Shipment for Outward AWB: $out_awb/, "Couldn't find Un-Dispatched Shipment with AWB" );
    }

    # Test Hand Held mode

    # reset shipment status
    $shipment->discard_changes;
    $shipment->update({ shipment_status_id => $SHIPMENT_STATUS__PROCESSING });
    $shipment->shipment_items->update({ shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PACKED });

    # check that when Manager level access can't see List of Shipments in Hand Held Mode
    Test::XTracker::Data->grant_permissions( 'it.god', 'Fulfilment', 'Dispatch', $AUTHORISATION_LEVEL__MANAGER );

    $mech->get_ok('/HandHeld/Home');
    $mech->follow_link_ok({ text => 'Dispatch' }, "Hand Held Dispatch Screen" );
    $mech->content_unlike( qr/Shipments Awaiting Dispatch/, "Can't find Table of Shipments as Manager in Hand Held Mode" );

    # set access level back to Operator and check still can't see table
    Test::XTracker::Data->grant_permissions( 'it.god', 'Fulfilment', 'Dispatch', $AUTHORISATION_LEVEL__OPERATOR );
    $mech->get_ok('/HandHeld/Home');
    $mech->follow_link_ok({ text => 'Dispatch' }, "Hand Held Dispatch Screen" );
    $mech->content_unlike( qr/Shipments Awaiting Dispatch/, "Can't find Table of Shipments as Operator in Hand Held Mode" );

    # using Shipment Id
    $mech->submit_form_ok({
        with_fields => {
                shipment_id     => $ship_nr,
            },
        button  => 'submit'
    }, "Hand Held - Using Shipment Id: ".$ship_nr );
    $mech->no_feedback_error_ok;
    $mech->has_feedback_success_ok(qr/The shipment was successfully dispatched/,"Shipment Dispatched by Id");
    $mech->content_contains( 'body class="handheld"', "Still in Hand Held Mode" );

    # reset shipment status
    $shipment->discard_changes;

    if ($shipment->shipment_type->id eq $SHIPMENT_TYPE__DOMESTIC) {
        $shipment->update({ shipment_status_id => $SHIPMENT_STATUS__PROCESSING });
        $shipment->shipment_items->update({ shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PACKED });
        # using Outward AWB
        $mech->submit_form_ok({
            with_fields => {
                    shipment_id     => $out_awb,
                },
            button  => 'submit'
        }, "Hand Held - Using Outward AWB: ".$out_awb );
        $mech->no_feedback_error_ok;
        $mech->has_feedback_success_ok(qr/The shipment was successfully dispatched/,"Shipment Dispatched by AWB");
        $mech->content_contains( 'body class="handheld"', "Still in Hand Held Mode" );
        $shipment->discard_changes;
        cmp_ok( $shipment->shipment_status_id, "==", $SHIPMENT_STATUS__DISPATCHED, "Shipment Status is set to Dispatched" );
    }

    # Test both ways can't be re-dispatched

    # with Shipment Id
    $mech->submit_form_ok({
        with_fields => {
                shipment_id     => $ship_nr,
            },
        button  => 'submit'
    }, "Re-Dispatch Hand Held - Using Shipment Id: ".$ship_nr );
    $mech->has_feedback_error_ok( qr/The shipment has already been dispatched/, "Already Dispatched with Id" );
    $mech->content_contains( 'body class="handheld"', "Still in Hand Held Mode" );

    if ($shipment->shipment_type->id eq $SHIPMENT_TYPE__DOMESTIC) {
        # with Outward AWB
        $mech->submit_form_ok({
            with_fields => {
                    shipment_id     => $out_awb,
                },
            button  => 'submit'
        }, "Re-Dispatch Hand Held - Using Outward AWB: ".$out_awb );
        $mech->has_feedback_error_ok( qr/Could not find an Un-Dispatched Shipment for Outward AWB: $out_awb/, "Couldn't find Un-Dispatched Shipment with AWB" );
        $mech->content_contains( 'body class="handheld"', "Still in Hand Held Mode" );
    }

    if ($shipment->shipment_type->id eq $SHIPMENT_TYPE__PREMIER
            && $shipment->order->channel->is_on_dc(1)) {
        note "Testing Handheld Premier Dispatch page";

        Test::XTracker::Data->grant_permissions( 'it.god', 'Fulfilment', 'Premier Dispatch', $AUTHORISATION_LEVEL__OPERATOR );
        $mech->get_ok('/HandHeld/Home');
        $mech->follow_link_ok({ text => 'Premier Dispatch' }, "Hand Held Premier Dispatch Screen" );
        my $box_id = $shipment->shipment_boxes->first->id;

        # try while the shipment is in the wrong status
        $shipment->discard_changes;
        $shipment->update({ shipment_status_id => $SHIPMENT_STATUS__CANCELLED });
        $mech->submit_form_ok({
            with_fields => {
                    box_id     => $box_id,
                },
            button  => 'submit'
        }, "Hand Held Premier Dispatch - Using Box Id: ".$box_id );
        $mech->has_feedback_error_ok( qr/DO NOT DISPATCH.*has been cancelled/ );

        # fix the shipment status, but make the shipment items wrong
        $shipment->discard_changes;
        $shipment->update({ shipment_status_id => $SHIPMENT_STATUS__PROCESSING });
        $shipment->shipment_items->update({ shipment_item_status_id => $SHIPMENT_ITEM_STATUS__SELECTED });
        $mech->submit_form_ok({
            with_fields => {
                    box_id     => $box_id,
                },
            button  => 'submit'
        }, "Hand Held Premier Dispatch - Using Box Id: ".$box_id );
        $mech->has_feedback_error_ok( qr/DO NOT DISPATCH.*contains items which are not the correct status for dispatch/ );

        # fix the shipment items too
        $shipment->discard_changes;
        $shipment->shipment_items->update({ shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PACKED });

        # now it should work
        $mech->submit_form_ok({
            with_fields => {
                    box_id     => $box_id,
                },
            button  => 'submit'
        }, "Hand Held Premier Dispatch - Using Box Id: ".$box_id );
        $mech->no_feedback_error_ok;

        # re-dispatch should fail
        $mech->submit_form_ok({
            with_fields => {
                    box_id     => $box_id,
                },
            button  => 'submit'
        }, "Hand Held Premier Dispatch - Using Box Id: ".$box_id );
        $mech->has_feedback_error_ok( qr/DO NOT DISPATCH.*already been dispatched/ );
    }

    return $mech;
}

=head2 test_pick_print_docs

 test_pick_print_docs($shipment)

This tests that the correct documents have been printed at picking for this shipment.

=cut

sub test_pick_print_docs {
    my ($shipment, $print_directory) = @_;

    die 'No pick print docs in iws phase' unless $iws_rollout_phase;

    my @expected_file_types;
    if ($shipment->is_premier){
        push(@expected_file_types, 'addresscard');
    }
    if ($shipment->has_gift_messages() && $shipment->can_automate_gift_message()) {
        push(@expected_file_types, 'giftmessage');
    }

    test_print_docs($shipment, $print_directory, @expected_file_types);
}

=head2 test_dispatch_print_docs

 test_dispatch_pick_print_docs($shipment)

This tests that the correct documents have been printed at dispatch for this shipment.

=cut

sub test_dispatch_print_docs {
    my ($shipment, $print_directory)     = @_;

    my @expected_file_types;
    if ($shipment->is_premier && $iws_rollout_phase){
        @expected_file_types = qw/invoice retpro/;
    } elsif ($shipment->is_premier) {
        @expected_file_types = qw/addresscard invoice retpro/;
    } elsif ($shipment->is_domestic) {
        @expected_file_types = qw/invoice retpro shippingform/;
        push (@expected_file_types, 'dgn') if $shipment->has_hazmat_lq_items;

    } else {
        die "didn't expect that shipment type for shipment id ".$shipment->id;
    }

    # All non-IWS and non-premier shipments that failed (DC2) or never went
    # through (DC3) carrier automation require matchup sheets
    if ( !$iws_rollout_phase
      && !$shipment->is_premier
      && !$shipment->real_time_carrier_booking
    ) {
        push @expected_file_types, 'matchup_sheet';
    }
    # even if it was printed at picking, they're supposed to get a warning
    # that the gift message is required at labelling time too
    if ($shipment->gift_message && !$shipment->can_automate_gift_message) {
        warn 'I would have expected a gift message warning here too!';
        push @expected_file_types, 'giftmessagewarning';
    }

    test_print_docs($shipment, $print_directory, sort @expected_file_types);
}

=head2 test_print_docs

 test_print_docs($shipment)

This tests that the correct documents have been printed for this shipment.

=cut

sub test_print_docs {
    my ($shipment, $print_directory, @expected_file_types) = @_;

    return unless @expected_file_types;

    my @print_docs = $print_directory->wait_for_new_files( files => scalar(@expected_file_types) );
    my @printed_file_types = sort map { $_->file_type } @print_docs;
    is_deeply(\@printed_file_types,\@expected_file_types,"Found ".$shipment->shipment_type->type." paperwork print docs");
}

#------------------------------------------------------------------------------------------------

sub setup_user_perms {
  Test::XTracker::Data->grant_permissions( 'it.god', 'Customer Care', 'Order Search', $AUTHORISATION_LEVEL__OPERATOR );
  # Perms needed for the order process
  for (qw/Airwaybill Dispatch Packing Picking Selection Labelling/ ) {
    Test::XTracker::Data->grant_permissions( 'it.god', 'Fulfilment', $_, $AUTHORISATION_LEVEL__OPERATOR );
  }
  Test::XTracker::Data->grant_permissions( 'it.god', 'Fulfilment', 'Invalid Shipments', $AUTHORISATION_LEVEL__OPERATOR );
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

sub _check_container_empty_messages {
    my ($xt_to_prls, $shipment) = @_;

    my $number_of_prls = XT::Domain::PRLs::get_number_of_prls;
    my $number_of_containers = $shipment->containers->count;
    my $expected_messages = $number_of_containers * $number_of_prls;

    $xt_to_prls->expect_messages({
        messages => [
            ({
                '@type' => 'container_empty',
            }) x $expected_messages,
        ],
    }) if $expected_messages;
}

