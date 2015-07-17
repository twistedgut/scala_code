#!/usr/bin/env perl

=head1 NAME

ca_packing_am.t - Test carrier automation at packing, without IWS

=head1 DESCRIPTION

ca = carrier automation
am = america (DC2)

    * test packing station name
    * test set packing station name
    * test reprint permissions
    * test complete packing

#TAGS fulfilment packing checkruncondition prl ups printer html xpath http needsrefactor whm

=cut

use NAP::policy "tt", 'test';

use Test::XTracker::Data;
use Test::XTracker::Mechanize;
use Test::XTracker::Mechanize::Session;
use XTracker::Config::Local         qw( :DEFAULT :carrier_automation );
use XTracker::Database::Shipment    qw( get_postcode_shipping_charges get_state_shipping_charges get_country_shipping_charges
                                        :carrier_automation check_country_paperwork );
use Test::XTracker::Mock::Handler;

use XTracker::Constants::FromDB qw(
    :authorisation_level
    :department
    :shipment_item_returnable_state
    :shipment_item_status
    :shipment_status
    :shipment_type
);

use XTracker::Database::Profile     qw( get_operator_preferences );
use Test::XT::Flow;
use Test::XTracker::PrintDocs;
use Test::XTracker::Artifacts::Labels;
use Test::XTracker::RunCondition dc => 'DC2', export => [qw( $prl_rollout_phase )];

use feature ':5.14';

my $schema = Test::XTracker::Data->get_schema;
my $operator = $schema->resultset('Public::Operator')->find({ username => 'it.god' });

my $channel  = Test::XTracker::Data->channel_for_nap;
my $channel_id  = $channel->id;
my $pids        = Test::XTracker::Data->grab_products( { channel_id => $channel_id } );
my $ps_grp      = _get_packing_station_groups( $schema, $channel_id );

# get other packing station for a different channel not ideal as it assumes
# the OUTNET doesn't share packing stations with NAP will fail if it does
my $othr_ps_grp = _get_packing_station_groups( $schema, Test::XTracker::Data->channel_for_out->id );

Test::XTracker::Data->ensure_stock( $pids->[0]{pid}, $pids->[0]{size_id}, $channel_id );

my $mech = Test::XTracker::Mechanize->new;
Test::XTracker::Data->set_department($operator->username, 'Shipping');

my $framework = Test::XT::Flow->new_with_traits(
    traits => ['Test::XT::Flow::Fulfilment', 'Test::XT::Flow::PRL'], mech => $mech );

my $handler = _update_operator_packing_station(
    $operator, $ps_grp->{ps_settings}[0]->value
);

$framework->login_with_permissions({
    perms => {
        $AUTHORISATION_LEVEL__OPERATOR => [
            'Customer Care/Order Search',
            (map { "Fulfilment/$_" } qw/Airwaybill Dispatch Packing Picking Selection Labelling/, 'Invalid Shipments')
        ],
    },
});

# extract session_id from cookie jar
my $session_store  = $mech->session;
note "Session Id: ".$session_store->session_id;

# get shipping account for Domestic UPS
my $shipping_account = Test::XTracker::Data->find_shipping_account({
    channel_id => $channel_id,
    acc_name   => 'Domestic',
    carrier    => 'UPS',
});
my $customer = Test::XTracker::Data->find_customer( { channel_id => $channel_id } );
my $address = Test::XTracker::Data->create_order_address_in('current_dc_premier');

my $order = Test::XTracker::Data->create_db_order({
    customer_id => $customer->id,
    channel_id  => $channel_id,
    items => {
        $pids->[0]{sku} => { price => 100.00 },
    },
    shipment_type => $SHIPMENT_TYPE__DOMESTIC,
    shipment_status => $SHIPMENT_STATUS__PROCESSING,
    shipment_item_status => $SHIPMENT_ITEM_STATUS__NEW,
    shipping_account_id => $shipping_account->id,
    invoice_address_id => $address->id,
    shipping_charge_id => 4   # NY Metro Express
});

note "Shipping Acc.: ".$shipping_account->id;
note "Order Nr: " . $order->order_nr;
note "Cust Nr/Id : ".$customer->is_customer_number."/".$customer->id;

$mech->order_nr($order->order_nr);

my ($ship_nr, $status, $category) = gather_order_info();
note "Shipment Nr: $ship_nr";

# make sure shipment valid
my $shipment_ob = $schema->resultset('Public::Shipment')->find( $ship_nr );
Test::XTracker::Data->toggle_shipment_validity( $shipment_ob, 1 );

# The order status might be Credit Hold. Check and fix if needed
if ($status eq "Credit Hold") {
    Test::XTracker::Data->set_department($operator->username, 'Finance');
    $mech->reload;
    $mech->follow_link_ok({ text_regex => qr/Accept Order/ }, "Order approved");
    ($ship_nr, $status, $category) = gather_order_info();
}
is($status, $mech->get_table_value('Order Status:'), "Order is accepted");

# Get shipment to packing stage
my $skus= $mech->get_order_skus();
my $container_id = Test::XT::Data::Container->get_unique_id({ how_many => 1 });

Test::XTracker::Data::Order->allocate_order($order);
Test::XTracker::Data::Order->select_order($order);
$framework->flow_msg__prl__pick_shipment(
    shipment_id => $order->shipments->first->id,
    container => {
        $container_id => [keys %$skus],
    }
);
$framework->flow_msg__prl__induct_shipment(
    shipment_row => $order->shipments->first,
);

# Set the bloody packing station otherwise if ran standalone this fails
$framework->mech__fulfilment__set_packing_station( $channel_id );

test_packing_station_name( $ship_nr, $skus );
test_set_packing_station_name( $mech, $handler );
test_reprint_permissions( $ship_nr, $skus );
test_complete_packing( $ship_nr, $skus );

done_testing;

sub test_reprint_permissions {
    my ( $ship_nr, $skus ) = @_;

    note 'Testing reprint permissions';

    my $shipment    = $schema->resultset('Public::Shipment')->find( $ship_nr );
    Test::XTracker::Data->ca_good_address($shipment);
    $shipment->set_carrier_automated(1);

    my @allowed_departments = ( $DEPARTMENT__DISTRIBUTION_MANAGEMENT );
    my $department_rs = $schema->resultset('Public::Department');
    # NOTE: There is currently a bug in DBIC that doesn't translate the below
    # perl into SQL correctly - the limit is applied to the whole rs instead of
    # just the arg's
#    local $schema->storage->{debug}=1;
#    my $departments = $department_rs->search({ id => \@allowed_departments})->union(
#        $department_rs->search_rs({ id => { q{!=} => \@allowed_departments } },{rows => 1}),
#    );
#    for my $department ( $departments->search({}, {order_by => 'id'})->all ) {
    my $allowed = $department_rs->search({ id => \@allowed_departments});
    my $not_allowed = $department_rs->search_rs(
        { id => { q{!=} => \@allowed_departments } },
        { rows => 1 }
    );
    for my $department ( map { $_->all } $allowed, $not_allowed ) {
        Test::XTracker::Data->set_department($operator->username, $department->department);
        _goto_packing_step( $shipment, $mech, $skus, "Complete" );
        $mech->submit_form_ok({
            form_name   => 'completePack',
            button      => 'submit',
        }, "Complete Packing");
        my $el = $mech->find_xpath(q{//form[@name='gotoPackingRePrint']})->pop;
        if ( $department->id ~~ \@allowed_departments ) {
            ok( $el, $department->department . ' should be able to re-print' );
        }
        else {
            ok( !$el, sprintf
                '%s should not be able to re-print (not in allowed set)',
                $department->department,
            );
        }
    }
}

=head2 test_packing_station_name

    $mech  = test_packing_station_name($mech,$shipment_id,$skus)

Tests to make sure that the Packing Station link and name show up and is checked
at all the stages.

=cut

sub test_packing_station_name {
    my ($ship_nr,$skus)   = @_;

    my $schema      = Test::XTracker::Data->get_schema;

    my $shipment    = $schema->resultset('Public::Shipment')->find( $ship_nr );

    note "TESTING Packing Station Name";

    # clean-up the shipment's address so that the UPS API Call passes
    Test::XTracker::Data->ca_good_address( $shipment );

    for my $step ( qw{ListPage PrePack PackItems AddBox Complete Packed} ) {
        _run_through_ps_name_tests( $shipment, $skus, $step );
    }

    return;
}


=head2 test_set_packing_station_name

    $mech  = test_set_packing_station_name( $mech, $handler );

Tests the 'Set Packing Station' page is working properly
(/Fulfilment/Packing/SelectPackingStation).

This is the page that sets an operator's packing station on their
'operator_preferences' record.

=cut

sub test_set_packing_station_name {
    my ( $mech, $handler ) = @_;

    my $schema  = Test::XTracker::Data->get_schema;
    my $op_prefs= $schema->resultset('Public::OperatorPreference');
    my $op_pref = $op_prefs->find( $handler->operator_id );

    note "TESTING Set Packing Station Name Page";

    # Get session and store to fiddle with
    my $session = $session_store->get_session;

    if ( defined $op_pref ) { $op_pref->delete }
    delete $session->{op_prefs};
    $session_store->save_session;

    # go to packing page
    $mech->get_ok('/Fulfilment/Packing');
    $mech->content_lacks( 'div id="packing_station"', "Fulfilment/Packing Page, No Packing Station Name Displayed" );

    $mech->follow_link_ok( { text_regex => qr/^Set Packing Station/ }, "Go To 'Set Packing Station' Page" );
    $mech->has_tag('span','Select a Packing Station', "Found Page" );
    $mech->content_lacks( 'div id="packing_station"', "Set Packing Station Page, No Packing Station Name Displayed" );

    $mech->form_name( 'setPackingStation' );
    is($mech->value( 'ps_name' ),"","Packing Station is empty in SELECT tag");

    $mech->follow_link_ok({ text_regex => qr/^Back to Packing/ }, "Back to Packing Link Followed");
    like( $mech->uri->path, qr{/Fulfilment/Packing$}, "Returned to Fulfilment/Packing page");

    $mech->follow_link_ok( { text_regex => qr/^Set Packing Station/ }, "Go To 'Set Packing Station' Page Again" );

    my @packing_stations_to_test = splice( @{ $ps_grp->{ps_settings} }, 0, 1);
    foreach my $ps (@packing_stations_to_test) {

        my $ps_value    = $ps->value;
        my $ps_dispval  = $ps_value;
        $ps_dispval     =~ s/_/ /g;

        $mech->submit_form_ok({
                with_fields => {
                    ps_name => $ps_value,
                },
                button => 'submit',
            }, 'Change Packing Station: '.$ps_dispval);
        $mech->no_feedback_error_ok;
        $mech->has_feedback_success_ok( qr/Packing Station Selected/, "Changed Packing Station Name: ".$ps_dispval);
        like( $mech->uri->path, qr{/Fulfilment/Packing$}, "Returned to Fulfilment/Packing page: ".$ps_dispval);
        $mech->has_tag('span',$ps_dispval, "Fulfilment/Packing, Packing Station Name displayed: ".$ps_dispval);

        $session = $session_store->get_session;
        is($session->{op_prefs}{packing_station_name},$ps_value,"Session Has Packing Station Name: ".$ps_dispval);
        $op_pref    = $op_prefs->find( $handler->operator_id );
        is($op_pref->packing_station_name,$ps_value,"Packing Station Name set on Operator Preferences record: ".$ps_dispval);
        # it doesn't work very well unless you do this
        $session_store->save_session;

        $mech->follow_link_ok( { text_regex => qr/^Set Packing Station/ }, "Go To 'Set Packing Station' Page" );
        $mech->has_tag('span',$ps_dispval,"Packing Station Name is Displayed on Page: ".$ps_dispval);

        $mech->form_name( 'setPackingStation' );
        is($mech->value( 'ps_name' ),$ps_value,"Packing Station is set in SELECT tag: ".$ps_dispval);
    }

    # clear the Packing Station Name Setting
    $mech->submit_form_ok({
            with_fields => {
                    ps_name => '',
                },
            button => 'submit',
        }, 'Clear Packing Station');
    $mech->no_feedback_error_ok;
    $mech->has_feedback_success_ok( qr/Packing Station Cleared/, "Cleared Packing Station Name");
    $mech->content_lacks( 'div id="packing_station"', "Fulfilment/Packing Page, No Packing Station Name Displayed" );

    $mech->follow_link_ok( { text_regex => qr/^Set Packing Station/ }, "Go To 'Set Packing Station' Page" );
    $mech->content_lacks( 'div id="packing_station"', "Set Packing Station Page, No Packing Station Name Displayed" );
    $mech->form_name( 'setPackingStation' );
    is($mech->value( 'ps_name' ),"","No Packing Station is set in SELECT tag");

    $session = $session_store->get_session;
    is($session->{op_prefs}{packing_station_name},"","Session Has Packing Station Name Cleared");
    $op_pref    = $op_prefs->find( $handler->operator_id );
    is($op_pref->packing_station_name,"","Packing Station Name on Operator Preferences record is Cleared");

    # reset operator_preferences/session
    $session = _make_session_valid( $session );

    return $mech;
}


=head2 test_complete_packing

    $mech  = test_complete_packing($mech,$shipment_id,$skus);

This tests the last stage of packing for Automated & Non-Automated Shipments
to make sure the correct messages are being displayed and documents are being
printed.

=cut

sub test_complete_packing {
    my ( $ship_nr, $skus )    = @_;

    my $print_docs = Test::XTracker::PrintDocs->new(title => 'test_complete_packing');
    my $label_docs = Test::XTracker::Artifacts::Labels->new(title => 'test_complete_packing');
    my $barcode_docs = Test::XTracker::PrintDocs->new(
        title => 'test_complete_packing',
        read_directory => Test::XTracker::Data->print_barcodes_path()
    );

    my $shipment    = $schema->resultset('Public::Shipment')->find( $ship_nr );
    my $ship_item   = $shipment->shipment_items->first;
    my $print_log   = $schema->resultset('Public::ShipmentPrintLog')->search(
        {
            shipment_id => $ship_nr,
            file => { 'ilike' => [ qw(
                                    shippingform%
                                    outpro%
                                    retpro%
                                    invoice%
                                    outward-%
                                    return-%
                                    ) ]
                    }
        },
        {
            order_by    => 'me.document,me.id',
        }
    );

    my $dbh = $schema->storage->dbh;
    my ( $num_proforma, $num_returns_proforma ) = check_country_paperwork( $dbh, $shipment->shipment_address->country );
    my %file_times;
    my $ship_boxes;
    my $ca_data1;
    my $ca_data2;
    my $box_count;


    note "TESTING Complete Packing Stage";

    note "TEST Non-Automated Shipment";

    # make shipment Non-Automated
    $shipment->set_carrier_automated(0);

    _goto_packing_step( $shipment, $mech, $skus, "Complete" );

    # mock up some box label image data;
    $shipment->discard_changes;
    _mock_box_label_data( $shipment );

    $mech->submit_form_ok({
                    form_name   => 'completePack',
                    button      => 'submit',
                }, "Complete Packing");
    $mech->no_feedback_error_ok;
    $mech->has_feedback_success_ok( qr/Shipment @{[$shipment->id]} has now been packed\./, "Non-Automated Complete Ok" );
    $mech->has_tag_like( 'p', qr/This shipment did not go through Carrier Automation/, "Non-Automated Complete Message Ok" );

    # There might be other files here too, feel free to extend this test to
    # check for/against the presence of additional files
    {
    my ( @files ) = $print_docs->new_files;
    ok( (grep { $_->filename eq "shippingform-$ship_nr.html" } @files),
        q{should find 'Shipping Input Form' file} );
    }
    $barcode_docs->non_empty_file_exists_ok("pickorder$ship_nr.png", q{should find 'Barcode' file});

    $mech->submit_form_ok({
                    form_name   => 'gotoPacking',
                    button      => 'submit',
                }, "Goto Packing");
    $mech->no_feedback_error_ok;
    $mech->submit_form_ok({
                    form_name   => 'validate_empty_tote',
                    button      => 'is_empty',
                }, "Goto Packing");
    $mech->has_tag_like( 'h3', qr/^Pack Shipment/, "Back at Start of Packing" );
    $print_log->reset->delete;

    $print_docs->delete_file("shippingform-$ship_nr.html");
    $label_docs->delete_file("pickorder$ship_nr.png");

    # check no label files were created for the boxes
    $ship_boxes = $shipment->shipment_boxes;
    while ( my $box = $ship_boxes->next ) {
        $label_docs->file_not_present_ok('outward-'.$box->id.'.lbl', 'no outward image file should be created');
        $label_docs->file_not_present_ok('return-'.$box->id.'.lbl', 'no return image file should be created');
    }

    # Check we can't go to the pre-packing stage as it's already done
    $mech->get_ok('/Fulfilment/Packing');
    $mech->submit_form_ok({ with_fields => { shipment_id => $shipment->id, }, button => 'submit', }, 'To Pre-Pack Screen');
    $mech->no_feedback_error_ok;
    unlike( $mech->uri->path, qr{/Fulfilment/CheckShipment$}, "NOT on check shipment page");

    note "TEST Automated Shipment (should fail)";

    # make shipment Automated
    set_carrier_automated( $dbh, $ship_nr, 1 );

    _goto_packing_step( $shipment, $mech, $skus, "Complete" );
    $shipment->discard_changes;
    _mock_box_label_data( $shipment );

    # test that when the API Call fails it gives the appropriate message

    # mess-up the shipment's address to cause the call to 'process_shipment_for_carrier_automation' to FAIL
    Test::XTracker::Data->ca_bad_address( $shipment );

    $mech->submit_form_ok({
                    form_name   => 'completePack',
                    button      => 'submit',
                }, "Complete Packing");
    $mech->no_feedback_error_ok;
    $mech->has_feedback_success_ok( qr/The shipment has now been packed but Failed Carrier Automation/, "Automated Failure Complete Ok" );
    $mech->has_tag_like( 'p', qr/This shipment failed the Carrier Automation process and has reverted to being processed Manually/, "Automated Failure Complete Message Ok" );

    # There might be other files here too, feel free to extend this test to
    # check for/against the presence of additional files
    {
    my ( @files ) = $print_docs->new_files;
    ok( (grep { $_->filename eq "shippingform-$ship_nr.html" } @files),
        q{should find 'Shipping Input Form' file} );
    }
    $barcode_docs->non_empty_file_exists_ok("pickorder$ship_nr.png", q{should find 'Barcode' file});

    $shipment->discard_changes;
    cmp_ok( $shipment->is_carrier_automated, '==', 0, "Shipment is now NOT Automated since it 'Failed' the UPS API Call" );
    # check the RTCB log has logged the change and reason
    # RTCB = Real-Time Carrier Booking
    my $rtcb_log    = $shipment->log_shipment_rtcb_states_rs->search( undef, { order_by => 'me.id DESC' } )->first;
    cmp_ok( $rtcb_log->shipment_id, '==', $shipment->id, 'RTCB Log: Shipment Id matches' );
    cmp_ok( $rtcb_log->new_state, '==', 0, 'RTCB Log: State is FALSE' );
    cmp_ok( $rtcb_log->operator_id, '==', $operator->id, 'RTCB Log: Operator ID matches' );
    like( $rtcb_log->reason_for_change, qr{UPS API: 10203 - Test Hard Error 3}, 'RTCB Log: Reason for Change Matches' ); # error comes from Test::XT::Net::UPS
    if ($rtcb_log->reason_for_change =~ m{500 Can't connect to wwwcie.ups.com}) {
        die $rtcb_log->reason_for_change;
    }
    is( $shipment->outward_airway_bill, "none", "Shipment Outward AWB is set to 'none'" );
    is( $shipment->return_airway_bill, "none", "Shipment Return AWB is set to 'none'" );
    $mech->submit_form_ok({
                    form_name   => 'gotoPacking',
                    button      => 'submit',
                }, "Goto Packing");
    $mech->no_feedback_error_ok;
    $mech->submit_form_ok({
                    form_name   => 'validate_empty_tote',
                    button      => 'is_empty',
                }, "Goto Packing");
    $mech->has_tag_like( 'h3', qr/^Pack Shipment/, "Back at Start of Packing" );

    $print_docs->delete_file("shippingform-$ship_nr.html");
    $label_docs->delete_file("pickorder$ship_nr.png");

    $print_log->reset->delete;
    # check no label files were created for the boxes
    $ship_boxes = $shipment->shipment_boxes;
    while ( my $box = $ship_boxes->next ) {
        $label_docs->file_not_present_ok('outward-'.$box->id.'.lbl', 'no outward image file should be created');
        $label_docs->file_not_present_ok('return-'.$box->id.'.lbl', 'no return image file should be created');
    }

    # Check we can't go to the pre-packing stage as it's already done
    $mech->get_ok('/Fulfilment/Packing');
    $mech->submit_form_ok({ with_fields => { shipment_id => $shipment->id, }, button => 'submit', }, 'To Pre-Pack Screen');
    $mech->no_feedback_error_ok;
    unlike( $mech->uri->path, qr{/Fulfilment/CheckShipment$}, "NOT on check shipment page");


    # make shipment Automated
    set_carrier_automated( $dbh, $ship_nr, 1 );

    _goto_packing_step( $shipment, $mech, $skus, "Complete" );
    $shipment->discard_changes;
    _mock_box_label_data( $shipment );

    note "TEST Automated Shipment for non-returnable shipment";

    # clean-up the shipment's address first for the UPS API
    Test::XTracker::Data->ca_good_address( $shipment );

    # make the shipment non-returnable (if it isn't already)
    my $is_shipment_originally_returnable = $shipment->get_shipment_returnable_status == $SHIPMENT_ITEM_RETURNABLE_STATE__YES;
    Test::XTracker::Data->set_shipment_returnable( $ship_nr, 0 );
    is ( $shipment->get_shipment_returnable_status, $SHIPMENT_ITEM_RETURNABLE_STATE__NO, "Shipment is non-returnable");

    # test that the appropriate non-returnable shipment message is provided at the end of packing

    $mech->submit_form_ok({
                    form_name   => 'completePack',
                    button      => 'submit',
                }, "Complete Packing");
    $mech->no_feedback_error_ok;
    $mech->has_feedback_success_ok( qr/The shipment has now been packed using Carrier Automation/, "Automated Success Complete Ok" );
    $mech->content_like( qr/Returns documentation will not be printed for this shipment as all shipment items are non-returnable/,
                               "Displayed message that no returns documentation will be printed" );
    like( $mech->find_xpath(q{//div[@class='info']})->to_literal,
        qr/Shipment Id:.*$ship_nr.*This Shipment uses Carrier Automation and you should have had Paperwork/,
        "Automated Success Complete Message Ok" );

    if ( $is_shipment_originally_returnable ) {
        Test::XTracker::Data->set_shipment_returnable( $ship_nr, 1 );
    }

    $mech->submit_form_ok({
                    form_name   => 'gotoPacking',
                    button      => 'submit',
                }, "Goto Packing");
    $mech->no_feedback_error_ok;
    $mech->submit_form_ok({
                    form_name   => 'validate_empty_tote',
                    button      => 'is_empty',
                }, "Goto Packing");
    $mech->has_tag_like( 'h3', qr/^Pack Shipment/, "Back at Start of Packing" );
    $print_log->reset->delete;

    $print_docs->delete_file("shippingform-$ship_nr.html");
    $label_docs->delete_file("pickorder$ship_nr.png");
    # remove label files created for future tests
    $ship_boxes = $shipment->shipment_boxes;
    while ( my $box = $ship_boxes->next ) {
        $label_docs->delete_file( sprintf('outward-%s.lbl', $box->id) );
    }

    # reset carrier automation data for later tests
    $shipment->clear_carrier_automation_data;
    $shipment->discard_changes;

    # Check we can't go to the pre-packing stage as it's already done
    $mech->get_ok('/Fulfilment/Packing');
    $mech->submit_form_ok({ with_fields => { shipment_id => $shipment->id, }, button => 'submit', }, 'To Pre-Pack Screen');
    $mech->no_feedback_error_ok;
    unlike( $mech->uri->path, qr{/Fulfilment/CheckShipment$}, "NOT on check shipment page");

    cmp_ok( $shipment->is_carrier_automated, '==', 1, "Shipment is STILL Automated since it 'Passed' the UPS API Call" );

    _goto_packing_step( $shipment, $mech, $skus, "Complete" );
    $shipment->discard_changes;
    _mock_box_label_data( $shipment );

    note "TEST Automated Shipment (should pass)";

    # test that when the API Call passes it gives the appropriate message

    # clean-up the shipment's address first for the UPS API
    Test::XTracker::Data->ca_good_address( $shipment );

    # We have to be in 'Distribution Management' for the reprint option to
    # appear on the CA documentation confirmation page
    Test::XTracker::Data->set_department($operator->username, 'Distribution Management');

    $mech->submit_form_ok({
                    form_name   => 'completePack',
                    button      => 'submit',
                }, "Complete Packing");
    $mech->no_feedback_error_ok;
    $mech->has_feedback_success_ok( qr/The shipment has now been packed using Carrier Automation/, "Automated Success Complete Ok" );
    like( $mech->find_xpath(q{//div[@class='info']})->to_literal,
        qr/Shipment Id:.*$ship_nr.*This Shipment uses Carrier Automation and you should have had Paperwork/,
        "Automated Success Complete Message Ok" );
    $shipment->discard_changes;
    $ca_data1   = _get_ca_data( $shipment );        # store data for comparison later on

    cmp_ok( $shipment->is_carrier_automated, '==', 1, "Shipment is STILL Automated since it 'Passed' the UPS API Call" );

    # There might be other files here too, feel free to extend this test to
    # check for/against the presence of additional files
    {
    my (@files) = $print_docs->new_files;
    my $invoice_filename = sprintf('invoice-%s.html', $shipment->renumerations->first->id);
    ok( (my ($invoice) = grep { $_->filename eq $invoice_filename } @files),
        'should find invoice document' );
    $file_times{invoice} = $invoice->file_age;

    if ( $num_proforma ) {
        my $outpro_filename = sprintf('outpro-%s.html', $shipment->id);
        ok( (my ($outpro) = grep { $_->filename eq $outpro_filename } @files),
            'should find outward proforma' );
        $file_times{outpro} = $outpro->file_age;
    }
    if ( $num_returns_proforma ) {
        my $retpro_filename = sprintf('retpro-%s.html', $shipment->id);
        ok( (my ($retpro) = grep { $_->filename eq $retpro_filename } @files),
            'should find outward proforma' );
        $file_times{retpro} = $retpro->file_age;
    }
    }

    # check label files were created for the boxes
    $ship_boxes = $shipment->shipment_boxes;
    $label_docs->wait_for_new_files( files => 2 * $ship_boxes->count );
    while ( my $box = $ship_boxes->next ) {
        my $out_filename = sprintf('outward-%s.lbl', $box->id);
        $label_docs->non_empty_file_exists_ok( $out_filename, 'outward image file should be created' );
        $file_times{outlab} = $label_docs->file_age( $out_filename );

        my $ret_filename = sprintf('return-%s.lbl', $box->id);
        $label_docs->non_empty_file_exists_ok( $ret_filename, 'return image file should be created' );
        $file_times{retlab} = $label_docs->file_age( $ret_filename );
    }

    # test Re-Print Option if the user didn't get the correct documents
    $mech->submit_form_ok({
                    form_name   => 'gotoPackingRePrint',
                    button      => 'submit',
                }, "Re-Print Automated Shipment Documents");
    $mech->no_feedback_error_ok;
    $mech->content_unlike( qr/Return Air Waybill/, 'No Return Air Waybill Section' );
    $mech->content_unlike( qr/Remove Waybill/, 'No Remove Waybill button' );
    # just hit Complete Packing again
    $mech->submit_form_ok({
                    form_name   => 'completePack',
                    button      => 'submit',
                }, "Complete Packing");
    $mech->no_feedback_error_ok;
    $mech->has_feedback_success_ok( qr/The shipment has now been packed using Carrier Automation/, "Automated Success Complete Ok" );
    like( $mech->find_xpath(q{//div[@class='info']})->to_literal,
        qr/Shipment Id:.*$ship_nr.*This Shipment uses Carrier Automation and you should have had Paperwork/,
        "Automated Success Complete Message Ok" );
    $ca_data2   = _get_ca_data( $shipment );
    is_deeply( $ca_data2, $ca_data1, "CA Data hasn't changed (AWB's etc.)" );

    # There might be other files here too, feel free to extend this test to
    # check for/against the presence of additional files
    {
    my (@files) = $print_docs->new_files;
    my $invoice_filename = sprintf('invoice-%s.html', $shipment->renumerations->first->id);
    ok( (my ($invoice) = grep { $_->filename eq $invoice_filename } @files),
        'should find invoice document' );
    my $new_invoice_age = $invoice->file_age;
    isnt $new_invoice_age, $file_times{invoice}, 'invoice file should have been touched by reprint';
    $file_times{invoice} = $new_invoice_age;

    if ( $num_proforma ) {
        my $outpro_filename = sprintf('outpro-%s.html', $shipment->id);
        ok( (my ($outpro) = grep { $_->filename eq $outpro_filename } @files),
            'should find outward proforma' );
        my $new_outpro_age = $outpro->file_age;
        isnt $new_outpro_age, $file_times{outpro}, 'outward proforma file should have been touched by reprint';
        $file_times{outpro} = $new_outpro_age;
    }
    if ( $num_returns_proforma ) {
        my $retpro_filename = sprintf('retpro-%s.html', $shipment->id);
        ok( (my ($retpro) = grep { $_->filename eq $retpro_filename } @files),
            'should find outward proforma' );
        my $new_retpro_age = $retpro->file_age;
        isnt $new_retpro_age, $file_times{retpro}, 'return proforma file should have been touched by reprint';
        $file_times{retpro} = $new_retpro_age;
    }
    }

    # check label files were created for the boxes
    $ship_boxes = $shipment->shipment_boxes;
    $label_docs->wait_for_new_files( files => 2 * $ship_boxes->count );
    while ( my $box = $ship_boxes->next ) {
        my $outlab_filename = sprintf('outward-%s.lbl', $box->id);
        $label_docs->non_empty_file_exists_ok( $outlab_filename, 'outward image file should be created' );
        my $new_outlab_age = $label_docs->file_age( $outlab_filename );
        isnt $new_outlab_age, $file_times{outlab}, 'outward label file should have been touched by reprint';
        $file_times{outlab} = $new_outlab_age;

        my $retlab_filename = sprintf('return-%s.lbl', $box->id);
        $label_docs->non_empty_file_exists_ok( $retlab_filename, 'return image file should be created' );
        my $new_retlab_age = $label_docs->file_age( $retlab_filename );
        isnt $new_retlab_age, $file_times{retlab}, 'return label file should have been touched by reprint';
        $file_times{retlab} = $new_retlab_age;
    }

    # test Re-Print Option again and this time delete items and boxes
    # to see if a fresh call to UPS is made
    note "Testing when Removing Item from a box new CA Data is got from UPS API";
    $mech->submit_form_ok({
                    form_name   => 'gotoPackingRePrint',
                    button      => 'submit',
                }, "Re-Print Automated Shipment Documents");
    $mech->no_feedback_error_ok;
    $mech->submit_form_ok({
                    form_name   => 'removeItem'.$ship_item->id,
                }, 'Remove Item from box' );
    $mech->no_feedback_error_ok;
    $ca_data2   = _get_ca_data( $shipment );
    $ship_item->discard_changes;
    is( $ship_item->shipment_box_id, undef, 'Box removed from item record' );
    is( $ca_data2->{out_awb}, 'none', 'Outward AWB Cleared' );
    is( $ca_data2->{ret_awb}, 'none', 'Return AWB Cleared' );
    # complete packing again and see if the data has changed
    _goto_packing_step( $shipment, $mech, $skus, 'Packed', 'AddBoxNoDelete' );
    $mech->no_feedback_error_ok;
    $mech->has_feedback_success_ok( qr/The shipment has now been packed using Carrier Automation/, "Automated Success Complete Ok" );
    like( $mech->find_xpath(q{//div[@class='info']})->to_literal,
        qr/Shipment Id:.*$ship_nr.*This Shipment uses Carrier Automation and you should have had Paperwork/,
        "Automated Success Complete Message Ok" );
    $ca_data2   = _get_ca_data( $shipment );
    $ship_item->discard_changes;
    ok( length( $ship_item->shipment_box_id ), 'Box added to item record' );
    $box_count  = $shipment->shipment_boxes->count();
    isnt( $ca_data2->{out_awb}, 'none', 'Outward AWB NOT none' );
    isnt( $ca_data2->{ret_awb}, 'none', 'Return AWB NOT none' );

    isnt( $ca_data2->{out_awb}, $ca_data1->{out_awb}, 'Out AWB Changed after Remove Item' );
    isnt( $ca_data2->{ret_awb}, $ca_data1->{ret_awb}, 'Ret AWB Changed after Remove Item' );
    isnt( $ca_data2->{boxes}[0]{ trk_num }, $ca_data1->{boxes}[0]{ trk_num }, 'Box Trak Num Changed after Remove Item' );
    isnt( $ca_data2->{boxes}[0]{ out_lab }, $ca_data1->{boxes}[0]{ out_lab }, 'Box Out Lab Changed after Remove Item' );
    isnt( $ca_data2->{boxes}[0]{ ret_lab }, $ca_data1->{boxes}[0]{ ret_lab }, 'Box Ret Lab Changed after Remove Item' );
    $ca_data1   = $ca_data2;

    # There might be other files here too, feel free to extend this test to
    # check for/against the presence of additional files
    {
    my (@files) = $print_docs->new_files;
    my $invoice_filename = sprintf('invoice-%s.html', $shipment->renumerations->first->id);
    ok( (my ($invoice) = grep { $_->filename eq $invoice_filename } @files),
        'should find invoice document' );
    my $new_invoice_age = $invoice->file_age;
    isnt $new_invoice_age, $file_times{invoice}, 'invoice file should have been touched after item removed';
    $file_times{invoice} = $new_invoice_age;

    if ( $num_proforma ) {
        my $outpro_filename = sprintf('outpro-%s.html', $shipment->id);
        ok( (my ($outpro) = grep { $_->filename eq $outpro_filename } @files),
            'should find outward proforma' );
        my $new_outpro_age = $outpro->file_age;
        isnt $new_outpro_age, $file_times{outpro}, 'outward proforma file should have been touched after item removed';
        $file_times{outpro} = $new_outpro_age;
    }
    if ( $num_returns_proforma ) {
        my $retpro_filename = sprintf('retpro-%s.html', $shipment->id);
        ok( (my ($retpro) = grep { $_->filename eq $retpro_filename } @files),
            'should find outward proforma' );
        my $new_retpro_age = $retpro->file_age;
        isnt $new_retpro_age, $file_times{retpro}, 'return proforma file should have been touched after item removed';
        $file_times{retpro} = $new_retpro_age;
    }
    }
    # check label files were created for the boxes
    $ship_boxes = $shipment->shipment_boxes;
    $label_docs->wait_for_new_files( files => 2 * $ship_boxes->count );
    while ( my $box = $ship_boxes->next ) {
        my $outlab_filename = sprintf('outward-%s.lbl', $box->id);
        $label_docs->non_empty_file_exists_ok( $outlab_filename, 'outward label file should be created' );
        my $new_outlab_age = $label_docs->file_age( $outlab_filename );
        isnt $new_outlab_age, $file_times{outlab}, 'outward label file should have been touched after item removed';
        $file_times{outlab} = $new_outlab_age;

        my $retlab_filename = sprintf('return-%s.lbl', $box->id);
        $label_docs->non_empty_file_exists_ok( $retlab_filename, 'return label file should be created' );
        my $new_retlab_age = $label_docs->file_age( $retlab_filename );
        isnt $new_retlab_age, $file_times{retlab}, 'return label file should have been touched after item removed';
        $file_times{retlab} = $new_retlab_age;
    }

    # now delete a box
    note "Testing when Removing a Box new CA Data is got from UPS API";
    $shipment->discard_changes;
    $mech->submit_form_ok({
                    form_name   => 'gotoPackingRePrint',
                    button      => 'submit',
                }, "Re-Print Automated Shipment Documents");
    $mech->no_feedback_error_ok;
    $mech->submit_form_ok({
                    form_name   => 'removeBox',
                    with_fields => {
                        shipment_box_id => $shipment->shipment_boxes->first->id,
                    },
                    button      => 'submit',
                }, "Remove a Box" );
    $mech->no_feedback_error_ok;
    $ca_data2   = _get_ca_data( $shipment );
    is( $ca_data2->{out_awb}, 'none', 'Outward AWB Cleared' );
    is( $ca_data2->{ret_awb}, 'none', 'Return AWB Cleared' );
    cmp_ok( $shipment->shipment_boxes->count(), '<', $box_count, 'Number of boxes has been reduced' );
    # complete packing again and see if the data has changed

    _goto_packing_step( $shipment, $mech, $skus, 'Packed', 'AddBoxNoDelete' );
    $mech->no_feedback_error_ok;
    $mech->has_feedback_success_ok( qr/The shipment has now been packed using Carrier Automation/, "Automated Success Complete Ok" );
    like( $mech->find_xpath(q{//div[@class='info']})->to_literal,
        qr/Shipment Id:.*$ship_nr.*This Shipment uses Carrier Automation and you should have had Paperwork/,
        "Automated Success Complete Message Ok" );
    $ca_data2   = _get_ca_data( $shipment );
    cmp_ok( $shipment->shipment_boxes->count(), '==', $box_count, 'Number of boxes match again' );
    isnt( $ca_data2->{out_awb}, 'none', 'Outward AWB NOT none' );
    isnt( $ca_data2->{ret_awb}, 'none', 'Return AWB NOT none' );
    isnt( $ca_data2->{out_awb}, $ca_data1->{out_awb}, 'Out AWB Changed after Remove Box' );
    isnt( $ca_data2->{ret_awb}, $ca_data1->{ret_awb}, 'Ret AWB Changed after Remove Box' );
    isnt( $ca_data2->{boxes}[0]{ trk_num }, $ca_data1->{boxes}[0]{ trk_num }, 'Box Trak Num Changed after Remove Box' );
    isnt( $ca_data2->{boxes}[0]{ out_lab }, $ca_data1->{boxes}[0]{ out_lab }, 'Box Out Lab Changed after Remove Box' );
    isnt( $ca_data2->{boxes}[0]{ ret_lab }, $ca_data1->{boxes}[0]{ ret_lab }, 'Box Ret Lab Changed after Remove Box' );

    # I don't think there's any need to check files again as if it did after Removing an Item
    # which caused the CA data to be cleared then it should do it after Removing a box as it
    # uses the same method '$shipment->clear_carrier_automation_data' to do it.

    # Go Back to Packing List - This doesn't actually update anything, just takes the user back to the initial packing page
    # so that they can pack the next shipment
    $mech->submit_form_ok({
                    form_name   => 'gotoPacking',
                    button      => 'submit',
                }, "Goto Packing");
    $mech->no_feedback_error_ok;
    $mech->submit_form_ok({
                    form_name   => 'validate_empty_tote',
                    button      => 'is_empty',
                }, "Goto Packing");
    $mech->has_tag_like( 'h3', qr/^Pack Shipment/, "Back at Start of Packing" );

    # Check we can't go to the pre-packing stage as it's already done
    $mech->get_ok('/Fulfilment/Packing');
    $mech->submit_form_ok({ with_fields => { shipment_id => $shipment->id, }, button => 'submit', }, 'To Pre-Pack Screen');
    $mech->no_feedback_error_ok;
    unlike( $mech->uri->path, qr{/Fulfilment/CheckShipment$}, "NOT on check shipment page");


    # now Dispatch the order and it should say shipment already packed
    $shipment->discard_changes;
    $mech->test_dispatch( $shipment->outward_airway_bill );
    $mech->get_ok('/Fulfilment/Packing');
    $mech->submit_form_ok( { with_fields => { shipment_id => $shipment->id, }, button => 'submit', }, 'To Pre-Pack Screen' );
    $framework->mech->has_feedback_error_ok(
        ( map {
            qr{$_}
        } 'This shipment is already dispatched'),
        "Can't Pack a Dispatched Auto Shipment"
    );

    # put the shipment back to how it was
    $shipment->discard_changes;
    $shipment->shipment_items->update( {
                                shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PACKED
                            } );
    $shipment->update( {
                    shipment_status_id   => $SHIPMENT_STATUS__PROCESSING
                } );


    # Goto the order view page and check the Documents Exists
    # in the Print Log table at the bottom of the page and
    # display something when you click on them
    $print_log->reset;
    my @links;
    my $last_doc    = "";
    while ( my $log = $print_log->next ) {
        $mech->get_ok( $mech->order_view_url );
        if ( $last_doc ne $log->document ) {
            # there might be more than one link with the same
            # name but for a different file (particulary for
            # label files) but the log search is done in the
            # same order as the documents are created (hopefully)
            $last_doc= $log->document;
            @links   = $mech->find_all_links( text => $last_doc );
            cmp_ok( @links, ">", 0, "Found Links for ".$log->document." (".@links.")" );
        }
        my $link    = shift @links;
        my $logid   = $log->id;
        my $regex   = qr/OrderView\?.*viewdoc=$logid/;
        like( $link->url, $regex, "Found Link for ".$log->document.", Log Id: ".$log->id );
        $mech->follow_link_ok( { url => $link->url }, "Goto Link for Document ".$log->document )
            or diag '(link URL '.$link->url.')';
    }
    # check box tracking number is on order view page
    $mech->get_ok( $mech->order_view_url );
    my $trak_num    = $shipment->shipment_boxes->first->tracking_number;
    $mech->has_tag_like( 'td', qr/$trak_num/s, 'Box Tracking Number Found in Order View' );
    # make sure it's not displaying in DC1 format
    $mech->content_unlike( qr/JD0.*$trak_num/s, "Box Tracking Number Doesn't have JD0 prefix" );

    # remove label files created for future tests
    $ship_boxes = $shipment->shipment_boxes;
    while ( my $box = $ship_boxes->next ) {
        $label_docs->delete_file( sprintf('outward-%s.lbl', $box->id) );
        $label_docs->delete_file( sprintf('return-%s.lbl', $box->id) );
    }

    # Check use can still set the Shipment to be NON-Automated if user was still having problems
    # using EditShipment Page but only if they are in the correct department (which should be mangers only)

    # You must be in Shipping/Shipping Manager to edit an autoable shipment
    Test::XTracker::Data->set_department($operator->username, 'Shipping');

    $mech->test_edit_shipment( $ship_nr );

    $mech->submit_form_ok({
        with_fields => {
                rtcb => 0,
                rtcb_reason => "Couldn't Print Documents"
            },
        button => 'submit'
        }, 'Make the Shipment Non-Automated through the Edit Shipment Page');
    $mech->no_feedback_error_ok;

    # Start the packing process by going to the correct page
    $mech->get_ok('/Fulfilment/Packing');
    # say we're going to pack $ship_nr
    $mech->submit_form_ok({
        with_fields => {
                shipment_id => $ship_nr,
        },
        button => 'submit'
    }, "Pack Shipment");
    # we shouldn't have any errors
    $mech->no_feedback_error_ok;
    # our current page should be "Fulfilment/Packing/PackShipment"
    $mech->base_like(qr{http://.+/Fulfilment/Packing/PackShipment});

    $mech->submit_form_ok({
                    form_name   => 'completePack',
                    button      => 'submit',
                }, "Complete Packing");
    $mech->no_feedback_error_ok;
    $mech->has_feedback_success_ok( qr/Shipment $ship_nr has now been packed\./, "Non-Automated Complete Ok" );
    $mech->has_tag_like( 'p', qr/This shipment did not go through Carrier Automation/, "Non-Automated Complete Message Ok" );

    # There might be other files here too, feel free to extend this test to
    # check for/against the presence of additional files
    {
    my ( @files ) = $print_docs->new_files;
    ok( (grep { $_->filename eq "shippingform-$ship_nr.html" } @files),
        q{should find 'Shipping Input Form' file} );
    }
    $barcode_docs->non_empty_file_exists_ok( "pickorder$ship_nr.png", q{should find 'Barcode' file});

    # check shipment labels didn't get created
    $shipment->discard_changes;
    $ship_boxes = $shipment->shipment_boxes;
    while ( my $box = $ship_boxes->next ) {
        $print_docs->file_not_present_ok( sprintf('outward-%s.lbl', $box->id), 'no outward image file should be created' );
        $print_docs->file_not_present_ok( sprintf('return-%s.lbl', $box->id), 'no return image file should be created' );
    }
    $mech->submit_form_ok({
                    form_name   => 'gotoPacking',
                    button      => 'submit',
                }, "Goto Packing");
    $mech->no_feedback_error_ok;
    $mech->has_tag_like( 'h3', qr/^Pack Shipment/, "Back at Start of Packing" );

    return $mech;
}


#------------------------------------------------------------------------------------------------

=head2 _run_through_ps_name_tests

This tests what you should and shouldn't be-able to do at each packing stage
depending on different conditions regarding the operator's packing station:

   Test 1 - Packing Station Name Set & Valid & Shipment is Autoable       - Pass Through
   Test 2 - Packing Station Name Set & Invalid & Shipment is Autoable     - Sent Back to Fulfilment/Packing
   Test 3 - Packing Station Name Set & Invalid & Shipment is Not Autoable - Pass Through
   Test 4 - Packing Station Name Not Set & Shipment is Not Autoable       - Pass Through
   Test 5 - Packing Station Name Not Set & Shipment is Autoable           - Sent Back to Fulfilment/Packing
   Test 6 - Packing Station Name Set with a different channels
                                         & Shipment is Autoable           - Sent Back to Fulfilment/Packing

=cut

sub _run_through_ps_name_tests {
    my ( $shipment, $skus, $step )   = @_;

    # get the session so we can play with the op preferences
    my $session = $session_store->get_session;

    # make shipment Automated
    set_carrier_automated( $handler->{dbh}, $shipment->id, 1);

    $session = _make_session_valid( $session );

    my $ps_name = $handler->{preferences}{packing_station_name};
    $ps_name    =~ s/_/ /g;

    note "Testing Packing Step: ".$step;

    # most tests are not applicable if it's the first page we're testing
    if ( $step ne "ListPage" ) {

        # set-up a list of steps to skip when you are at a certain step
        my %skip   = (
                'PrePack'   => 'ListPage',
                'PackItems' => 'ListPage', # Can't skip trying to go to prepack page as when resuming packing prepack is skipped if already done
                'AddBox'    => 'PackItems',
                'Complete'  => 'AddBox',
                'Packed'    => 'Complete',
            );
        my $skip    = $skip{ $step };

        $mech   = _goto_packing_step( $shipment, $mech, $skus, $skip );

        # TEST 1 - Packing Station Name Set & Valid & Shipment is Autoable
        $mech   = _goto_packing_step( $shipment, $mech, $skus, $step, $skip );
        $mech->no_feedback_error_ok;
        my $link_ref    = $mech->find_link( text_regex => qr/Set Packing Station/ );
        if ($step eq 'AddBox' || $step eq 'Complete'){
            is($link_ref, undef, $mech->base().": $step, No Set Packing Station Link - Test 1")
        } else {
            is(ref($link_ref),"WWW::Mechanize::Link",$mech->base().": $step, Found Set Packing Station Link - Test 1");
        }
        $mech->has_tag( 'span', $ps_name, $mech->base().": $step, Packing Station Name Displayed - Test 1" );

        $mech   = _goto_packing_step( $shipment, $mech, $skus, $skip );

        # TEST 2 - Packing Station Name Set & Invalid & Shipment is Autoable
        $ps_grp->{ps_settings}[0]->update({ active => 0 });     # make PS invalid

        $mech->errors_are_fatal(0);
        $mech   = _goto_packing_step( $shipment, $mech, $skus, $step, $skip );
        #diag $mech->response->content       if $step eq "Packed";
        # TODO: tests fail here due to proxy issue preventing contact with carrier - will need to be amended if continues
        $mech->has_feedback_error_ok( qr/Your Packing Station is Not Valid, You Need to Change it Before Packing this Shipment/,"Back to List Page: $step, Test 2, error message displayed" )
            or note $mech->response->content; # XXX CCW
        $mech->errors_are_fatal(1);


        like( $mech->uri->path, qr{/Fulfilment/Packing$}, "Returned to Fulfilment/Packing page - Test 2");
        $mech->base_like(
            qr{http://.+/Fulfilment/Packing},   # the packing page, with or without errors in the URL
            'Returned to Fulfilment/Packing page (test 2) for shipment ' . $shipment->id
        )
            or note $mech->uri->path;
        $link_ref    = $mech->find_link( text_regex => qr/Set Packing Station/ );
        is(ref($link_ref),"WWW::Mechanize::Link",$mech->base().": $step, Found Set Packing Station Link - Test 2");
        $mech->has_tag( 'span', $ps_name, $mech->base().": $step, Packing Station Name Displayed - Test 2" );

        $session = _make_session_valid( $session );
        $mech   = _goto_packing_step( $shipment, $mech, $skus, $skip );

        # TEST 3 - Packing Station Name Set & Invalid & Shipment is Not Auotable
        $ps_grp->{ps_settings}[0]->update({ active => 0 });     # make PS invalid
        set_carrier_automated( $handler->{dbh}, $shipment->id, 0);      # make shipment Not Automated
        $mech->errors_are_fatal(0);
        $mech   = _goto_packing_step( $shipment, $mech, $skus, $step, $skip );
        $mech->has_feedback_error_ok( qr/Your Packing Station is Not Valid, You Need to Change it Before Packing this Shipment/,"Back to List Page: $step, Test 3, error message displayed" );
        $mech->errors_are_fatal(1);
        like( $mech->uri->path, qr{/Fulfilment/Packing$}, "Returned to Fulfilment/Packing page - Test 3");
        $mech->base_like(
            qr{http://.+/Fulfilment/Packing},   # the packing page, with or without errors in the URL
            'Returned to Fulfilment/Packing page (test 3) for shipment ' . $shipment->id
        )
            or note $mech->uri->path;
        $link_ref    = $mech->find_link( text_regex => qr/Set Packing Station/ );
        is(ref($link_ref),"WWW::Mechanize::Link",$mech->base().": $step, Found Set Packing Station Link - Test 3");
        $mech->has_tag( 'span', $ps_name, $mech->base().": $step, Packing Station Name Displayed - Test 3" );

        $session = _make_session_valid( $session );
        $mech   = _goto_packing_step( $shipment, $mech, $skus, $skip );

        # TEST 4 - Packing Station Name Not Set & Shipment is Not Autoable
        $handler    = _update_operator_packing_station( $operator, "" );     # clear packing station name
        delete $session->{op_prefs};       # clear op prefs from session to pick up change
        $session_store->save_session;

        # Refetch session from storage
        $session = $session_store->get_session;

        $mech->errors_are_fatal(0);
        $mech   = _goto_packing_step( $shipment, $mech, $skus, $step, $skip );
        $mech->has_feedback_error_ok( qr/You Need to Set a Packing Station before Packing this Shipment/,"Back to List Page: $step, Test 4" );
        $mech->errors_are_fatal(1);
        like( $mech->uri->path, qr{/Fulfilment/Packing$}, "Returned to Fulfilment/Packing page - Test 4");
        $link_ref    = $mech->find_link( text_regex => qr/Set Packing Station/ );
        is(ref($link_ref),"WWW::Mechanize::Link",$mech->base().": $step, Found Set Packing Station Link - Test 4");
        $mech->content_unlike( qr/$ps_name/, $mech->base().": $step, Packing Station Name Not Displayed - Test 4" );

        $session = _make_session_valid( $session );
        $mech   = _goto_packing_step( $shipment, $mech, $skus, $skip );

        # TEST 5 - Packing Station Name Not Set & Shipment is Autoable
        set_carrier_automated( $handler->{dbh}, $shipment->id, 1);                  # make shipment Automated
        $handler    = _update_operator_packing_station( $operator, "" );     # clear packing station name
        delete $session->{op_prefs};       # clear op prefs from session to pick up change
        $session_store->save_session;

        # Refetch session from storage
        $session = $session_store->get_session;

        $mech->errors_are_fatal(0);
        $mech   = _goto_packing_step( $shipment, $mech, $skus, $step, $skip );
        $mech->has_feedback_error_ok( qr/You Need to Set a Packing Station before Packing this Shipment/,"Back to List Page: $step, Test 5" );
        $mech->errors_are_fatal(1);
        like( $mech->uri->path, qr{/Fulfilment/Packing$}, "Returned to Fulfilment/Packing page - Test 5");
        $link_ref    = $mech->find_link( text_regex => qr/Set Packing Station/ );
        is(ref($link_ref),"WWW::Mechanize::Link",$mech->base().": $step, Found Set Packing Station Link - Test 5");
        $mech->content_unlike( qr/$ps_name/, $mech->base().": $step, Packing Station Name Not Displayed - Test 5" );

        $session= _make_session_valid( $session );
        $mech   = _goto_packing_step( $shipment, $mech, $skus, $skip );
    }
    else {

        # TEST 1 - Packing Station Name Set
        $mech   = _goto_packing_step( $shipment, $mech, $skus, $step );
        $mech->no_feedback_error_ok;
        my $link_ref    = $mech->find_link( text_regex => qr/Set Packing Station/ );
        is(ref($link_ref),"WWW::Mechanize::Link",$mech->base().": $step, Found Set Packing Station Link - Test 1");
        $mech->has_tag( 'span', $ps_name, $mech->base().": $step, Packing Station Name Displayed - Test 1" );

        $handler    = _update_operator_packing_station( $operator, "" );     # clear packing station name
        delete $session->{op_prefs};       # clear op prefs from session to pick up change
        $session_store->save_session;

        # Refetch session from storage
        $session = $session_store->get_session;

        # TEST 4 - Packing Station Name Not Set
        $mech   = _goto_packing_step( $shipment, $mech, $skus, $step );
        $mech->no_feedback_error_ok;
        $link_ref    = $mech->find_link( text_regex => qr/Set Packing Station/ );
        is(ref($link_ref),"WWW::Mechanize::Link",$mech->base().": $step, Found Set Packing Station Link - Test 4");
        $mech->content_unlike( qr/$ps_name/, $mech->base().": $step, Packing Station Name Not Displayed - Test 4" );

    }

    # clear Automation flag for shipment
    set_carrier_automated( $handler->{dbh}, $shipment->id, 0);

    $session = _make_session_valid( $session );

    return $mech;
}

# this resets the packing stage of a shipment and then goes
# through the packing steps to a particular point
sub _goto_packing_step {
    my ( $shipment, $mech, $skus, $step, $skip )    = @_;

    my %steps   = (
            'ListPage'  => 0,
            'PrePack'   => 1,
            'PackItems' => 2,
            'AddBox'    => 3,
            'AddBoxNoDelete'    => 3,
            'Complete'  => 4,
            'Packed'    => 5,
        );
    my $channel = $shipment->order->channel->business->config_section;
    my @boxes;

    $skip   = $skip || 'ListPage';

    # set-up box sizes for the Add Box step
    if ( $channel eq "NAP" ) {
        @boxes  = ( "NAP 3", "Outer 3" );
    }
    elsif ( $channel eq "OUTNET" ) {
        @boxes  = ( "Bag L", "Outer 4" );
    }

    if ( ( ( $steps{ $skip } < 4 ) || ( $steps{ $step } == 4 ) ) && 'AddBoxNoDelete' !~ /^($step|$skip)$/ ) {
        # get rid of boxes and reset shipment item status for the shipment
        # only do this if you are not skipping adding box otherwise the
        # previous box you added will be removed and complete won't work
        # properly
        $shipment->discard_changes;
        $shipment->update( {
                    outward_airway_bill     => 'none',
                    return_airway_bill      => 'none',
                } );
        $shipment->shipment_items->update({
                                container_id => $container_id,
                                shipment_box_id => undef,
                                shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PICKED,
                           });
        $shipment->shipment_boxes->delete;
    }

    # goto the front packing screen
    if ( $steps{ $skip } <= 0 ) {
        $mech->get_ok('/Fulfilment/Packing');
    }

    CASE: {
        if ( ( $steps{ $step } > 0 ) && ( $steps{ $skip } < 1 ) ) {
            # GO TO Pre Pack Shipment Page
            $mech->submit_form_ok({
                    with_fields => {
                            shipment_id => $shipment->id,
                        },
                   button => 'submit',
              }, 'To Pre-Pack Screen');
        }
        if ( ( $steps{ $step } > 1 ) && ( $steps{ $skip } < 2 ) )  {
            # can only do pre-pack once, after that it should resume on packing page
            if ($mech->uri->path =~ m/CheckShipment/){
                $framework->errors_are_fatal(0);
                $framework->flow_mech__fulfilment__packing_checkshipment_submit();
                $framework->errors_are_fatal(1);
            }
        }
        if ( ( $steps{ $step } > 2 ) && ( $steps{ $skip } < 3 ) ) {
            # GO TO Add Box Page
            foreach ( keys %{ $skus } ) {
                $mech->submit_form_ok({
                            with_fields => {
                                sku => $_,
                            },
                            button => 'submit'
                       }, "Packing SKU: ".$_);
            }
        }
        if ( ( $steps{ $step } > 3 ) && ( $steps{ $skip } < 4 ) ) {
            # GO TO Complete Packing Page
            $framework
                ->flow_mech__fulfilment__packing_packshipment_submit_boxes(
                    inner => $boxes[0],
                    outer => $boxes[1],
                );
        }
        if ( $steps{ $step } > 4 ) {
            # GO TO Shipment Packed Page
            $framework->flow_mech__fulfilment__packing_packshipment_complete;
        }
    };

    return $mech;
}

# this makes the operator preferences and session valid
# for skipping past various stages of the packing process
sub _make_session_valid {
    my $session     = shift;

    # make sure the first PS is active
    $ps_grp->{ps_settings}[0]->update({ active => 1 });
    $ps_grp->{ps_settings}[0]->discard_changes;
    # set the operator's PS name to the first PS
    $handler    = _update_operator_packing_station( $operator, $ps_grp->{ps_settings}[0]->value );
    delete $session->{op_prefs};       # clear op prefs from session to pick up change

    # Save amended session
    $session_store->save_session;

    # Refetch from storage for good measure
    $session = $session_store->get_session;

    return $session;
}

# update an operator's packing station preference
sub _update_operator_packing_station {
    my ( $operator, $ps_name ) = @_;

    $operator->update_or_create_preferences({ packing_station_name => $ps_name });

    $handler = Test::XTracker::Mock::Handler->new({
        operator_id => $operator->id,
        preferences => get_operator_preferences(
            $operator->result_source->schema->storage->dbh, $operator->id
        ),
    });

    return $handler;
}

# get all of the packing stations for a channel including id's
sub _get_packing_station_groups {
    my ( $schema, $channel_id ) = @_;

    my $retval;
    my $conf_grp    = $schema->resultset('SystemConfig::ConfigGroup')
                                ->search( { name => 'PackingStationList', channel_id => $channel_id } )
                                    ->first;

    my @conf_setting= $conf_grp->config_group_settings
                                ->search( { setting => 'packing_station' }, { order_by => 'sequence' } )
                                    ->all;

    $retval->{ps_grp}       = $conf_grp;
    $retval->{ps_settings}  = \@conf_setting;

    ok(defined $conf_grp,"Packing Station Group Exists, Channel Id: $channel_id");
    cmp_ok(@conf_setting,">",0,"At Least One Packing Station is Active, Channel Id: $channel_id");

    return $retval;
}

# Update Shipment Boxes for a Shipment to have some data in the
# 'outward_box_label_image' & 'return_box_label_image' fields
sub _mock_box_label_data {
    my $shipment    = shift;
    my $boxes       = $shipment->shipment_boxes;

    while ( my $box = $boxes->next ) {
        $box->update( { outward_box_label_image => 'OUTWARD IMAGE DATA '.$box->id, return_box_label_image => 'RETURN IMAGE DATA '.$box->id } );
    }

    return;
}

# used to get the carrier automation data returned by UPS
# that we store in shipment and shipment box tables
sub _get_ca_data {
    my  $shipment       = shift;

    my %data;

    $shipment->discard_changes;
    $data{ out_awb }    = $shipment->outward_airway_bill;
    $data{ ret_awb }    = $shipment->return_airway_bill;
    my $boxes   = $shipment->shipment_boxes->search( undef, { order_by => 'me.id ASC' } );
    while ( my $box = $boxes->next ) {
        push @{ $data{ boxes } }, {
                            trk_num => $box->tracking_number,
                            out_lab => $box->outward_box_label_image,
                            ret_lab => $box->return_box_label_image,
                        }
    }

    return \%data;
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
