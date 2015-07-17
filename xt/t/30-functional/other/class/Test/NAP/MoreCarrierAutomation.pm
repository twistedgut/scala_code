package Test::NAP::MoreCarrierAutomation;

=head1 NAME

Test::NAP::MoreCarrierAutomation - Test Carrier Automation, some more

=head1 DESCRIPTION

Test Carrier Automation.

#TAGS fulfilment packing picking thirdparty checkruncondition prl printer toobig needsrefactor ups xpath http editshipment candoandwhm

=head1 SEE ALSO

Test::NAP::CarrierAutomation

=head1 METHODS

=cut

use NAP::policy "tt", 'test';

use FindBin::libs;


use Test::XTracker::Data;
use Test::XTracker::Mechanize;
use XTracker::Config::Local qw/get_packing_stations/;
use XTracker::Database::Shipment    qw( :carrier_automation get_address_shipping_charges );

use XTracker::Constants::FromDB qw(
    :channel
    :shipment_item_status
    :shipment_status
    :shipment_type
    :shipping_charge_class
);
use Test::XTracker::PrintDocs;
use Data::Dump qw( pp );
use Test::XTracker::RunCondition
    dc => 'DC2',
    export => [qw ( $prl_rollout_phase )];

use parent 'NAP::Test::Class';

sub startup : Test(startup) {
    my ( $self ) = @_;

    my $schema = $self->{schema} = Test::XTracker::Data->get_schema;

    my $channel = $self->{channel} = Test::XTracker::Data->channel_for_nap;

    # So we can restore the states to what they were prior to running this test
    $self->{auto_states} = $schema->resultset('Public::Channel')->get_carrier_automation_states();
    Test::XTracker::Data->set_carrier_automation_state( $channel->id, 'On' );

    my $pids = $self->{pids} = Test::XTracker::Data->grab_products( { channel_id => $channel->id } );
    $self->{customer} = Test::XTracker::Data->find_customer( { channel_id => $channel->id } );

    $self->{premier_address} = Test::XTracker::Data->create_order_address_in('current_dc_premier');

    Test::XTracker::Data->ensure_stock( $pids->[0]{pid}, $pids->[0]{size_id}, $channel->id );

    $self->{mech} = Test::XTracker::Mechanize->new;
    $self->{framework} = Test::XT::Flow->new_with_traits(
        traits => [
            'Test::XT::Flow::Fulfilment',
            'Test::XT::Flow::CustomerCare',
            'Test::XT::Flow::PRL',
        ]
    );

    Test::XTracker::Data->set_department('it.god', 'Shipping');

    $self->setup_user_perms;

    $self->{mech}->do_login;

    $self->SUPER::startup;
}

sub setup : Test(setup) {
    my ( $self ) = @_;

    my $mech = $self->{mech};
    my $channel = $self->{channel};

    # get shipping account for Domestic UPS
    my $shipping_account= Test::XTracker::Data->find_shipping_account( {
                                                channel_id      => $channel->id,
                                                'acc_name'      => 'Domestic',
                                                'carrier'       => 'UPS',
                                            } );

    my $order = Test::XTracker::Data->create_db_order({
        customer_id => $self->{customer}->id,
        channel_id  => $channel->id,
        items => {
            $self->{pids}[0]{sku} => { price => 100.00 },
        },
        shipment_type => $SHIPMENT_TYPE__PREMIER,
        shipment_status => $SHIPMENT_STATUS__PROCESSING,
        shipment_item_status => $SHIPMENT_ITEM_STATUS__NEW,
        shipping_account_id => $shipping_account->id,
        invoice_address_id => $self->{premier_address}->id,
        # get premier shipping charge id
        #;$prem_postcode->shipping_charge_id,
        shipping_charge_id => $channel->postcode_shipping_charges(
                { postcode => $self->{premier_address}->postcode }
            )->related_resultset('shipping_charge')
            ->slice(0,0)
            ->single
            ->id,
    });

    if ($prl_rollout_phase) {
        Test::XTracker::Data::Order->allocate_order($order);
    }

    my $order_nr = $order->order_nr;

    if ( $ENV{HARNESS_VERBOSE} || $ENV{HARNESS_IS_VERBOSE} ) {
        diag "Shipping Acc.: ".$shipping_account->id;
        diag "Order Nr: $order_nr";
        diag "Cust Nr/Id : ".$self->{customer}->is_customer_number."/".$self->{customer}->id;
    }

    $mech->order_nr($order_nr);

    my ($ship_nr, $status, $category) = $self->gather_order_info();
    $self->{shipment_id} = $ship_nr;

    diag "Shipment Nr: $ship_nr" if $ENV{HARNESS_VERBOSE} || $ENV{HARNESS_IS_VERBOSE};

    # The order status might be Credit Hold. Check and fix if needed
    if ($status eq "Credit Hold") {
        Test::XTracker::Data->set_department('it.god', 'Finance');
        $mech->reload;
        $mech->follow_link_ok({ text_regex => qr/Accept Order/ }, "Order approved");
        ($ship_nr, $status, $category) = $self->gather_order_info();
    }
    is($status, $mech->get_table_value('Order Status:'), "Order is accepted");

    $self->{skus} = $mech->get_order_skus();

    $self->SUPER::setup;
}

sub shutdown : Tests(shutdown) {
    my ( $self ) = @_;
    Test::XTracker::Data->restore_carrier_automation_state( $self->{auto_states} );
    $self->SUPER::shutdown;
}

# TODO: Do something saner with this...
sub get_shipping_charges {
    my ( $self, $shipment ) = @_;

    my $address = $shipment->shipment_address;
    my %shipping_charges = get_address_shipping_charges(
        $self->{schema}->storage->dbh,
        $shipment->order->channel_id,
        {
            country  => $address->country,
            postcode => $address->postcode,
            state    => $address->county,
        },
    );

    my ( $premier_charge, @non_prem_charge );
    foreach ( keys %shipping_charges ) {
        if ( $shipping_charges{$_}{class_id} == $SHIPPING_CHARGE_CLASS__SAME_DAY ) {
            $premier_charge = $_;
        }
        else {
            push @non_prem_charge,$_;
        }
    }
    return $premier_charge, @non_prem_charge;
}

=head2 test_carrier_automation_field

Create a premier shipment, go to the edit page and verify that it appears.

Verify it has a shipment carrier automation span and check there's no rtcb
field in the form.

Change the charge to a nonpremier one and verify that it worked.

Verify that the shipment is now automatable and that the change was logged.

Verify that rtcb is now set to true.

Attempt to submit changing the rtcb field to false without a reason, expect an
error.

Try this again with a reason and verify that it worked.

Verify that the shipment is not automatable and that the change was logged.

Submit a form changing the shipping charge to another non-premier one, and
check that the shipment is not automated. Verify that rtcb can be edited.

Submit the edit form setting the charge to a premier one and pass an rtcb value
of true with a reason, verify that it worked.

Verify that rtcb is false and the shipment type is premier, and verify the
logging. Verify that rtcb can't be edited.

Change the shipment to a non-premier charge and verify that rtcb is true, is
editable and that the changes were logged.

Set rtcb to false with a reason, verify that the updated was successful and the
changes were logged.

Set rtcb to true with a reason, verify that the updated was successful and the
changes were logged.

Set rtcb to false with a reason, verify that the updated was successful and the
changes were logged.

Test submitting the form with no changes and verify that no changes were made
and nothing was logged.

Set rtcb to true with a reason, verify that the updated was successful and the
changes were logged.

Test submitting the form with no changes and verify that no changes were made
and nothing was logged.

Set the shipment's address to a premier address, verify that the rtcb is not
editable. Hack the shipment's address to be in the UK, set it back to a
non-premier charge and verify that rtcb off and not editable. Do the usual
log/state checks.

Hack the address to be in the US, and submit a page setting the shipment to be
premier, verify that rtcb is not editable.

Set it back to non-premier and verify that it is editable.

=head3 NOTE

About the following gift shipment tests: (although Sorin did some work here and
didn't change *any* of the test descriptions/comments - apparently a gift
message *wasn't* automatable before).

Make the shipment a gift shipment, verify that the rtcb flag is on.

Set it back to a non-gift shipment, check that it's automatable.

Make shipment premier and then non-premier again, check that it's still
automatable.

Submit the page with rtcb set to false (with a reason), check that the shipment
isn't automatable. Make the shipment a gift message again with rtcb set to on
and check that it is automatable.

Make the gift message premier and then non-premier again, check that rtcb is
set and editable.

Hack the carrier automation state to be I<Import Off Only> for the channel, submit
the page (with the parameters as they are and check that rtcb is still on (i.e.
the shipment is automatable).

Hack the carrier automation state to be I<Off>, submit the page and check that
the rtcb flag is off.

Submit the page by explicitly setting the rtcb flag to be on and check that the
rtcb flag is still off.

Hack the carrier automation state to be I<On> again, submit the page with the
rtcb flag set to on, and check that the rtcb flag is now set to on.

=cut

sub test_carrier_automation_field : Tests {
    my ( $self ) = @_;

    my $schema      = $self->{schema};
    my $dbh         = $schema->storage->dbh;

    my $mech = $self->{mech};
    my $channel = $self->{channel};
    my $ship_nr = $self->{shipment_id};
    my $shipment = $schema->resultset('Public::Shipment')->find( $ship_nr );

    # To make sure we have access to the rtcb field
    Test::XTracker::Data->set_department('it.god', 'Shipping');

    # Takes us to the edit shipment page
    $mech->test_edit_shipment( $ship_nr );

    my $rtcb_log    = $schema->resultset('Public::LogShipmentRtcbState')->search({ shipment_id => $ship_nr },{ join => 'operator', order_by => 'id desc' });
    my $rtcb_rec;
    my $users_name = $mech->logged_in_as_logname;
    my @row;
    # store for later use
    my $acc_id  = $shipment->shipping_account_id;

    # get premier and non-premier shipping charges
    my ($premier_charge, @non_prem_charge )
        = $self->get_shipping_charges( $shipment );

    note "TESTING various combinations of editing the rtcb field and shipping option";

    # TEST rtcb field can't be edited
    $mech->has_tag('h3','Shipment Carrier Automation','Has Carrier Automation Heading');
    is($mech->form_with_fields('rtcb'),undef,'No rtcb field in form');

    # TEST changing shipping option to non-premier means rtcb can be edited
    $mech->submit_form_ok({
        with_fields => {
                shipping_charge_id  => $non_prem_charge[0]
            },
        button => 'submit'
      }, 'Change Shipping Option to Non-Premier');
    $mech->no_feedback_error_ok;
    $mech->has_feedback_success_ok(qr/Shipment Updated/,"Shipment Updated");

    _test_rtcb_and_log_changes( $mech, $shipment, $rtcb_log, 1, "AUTO: Changed After 'is_autoable' TEST", $users_name );
    cmp_ok($shipment->shipment_type_id,"!=",$SHIPMENT_TYPE__PREMIER,'Shipment Type is no longer Premier');

    $mech   = $mech->test_edit_shipment( $ship_nr );
    isnt($mech->form_with_fields('rtcb'),undef,'Now rtcb field is in form');
    cmp_ok($mech->value("rtcb"),"==",1,"rtcb field on form is set to Yes");

    # TEST can't manually change rtcb field without a reason
    $mech->submit_form_ok({
        with_fields => {
                rtcb => 0
            },
        button  => 'submit'
      }, 'Change rtcb field without a reason');
    $mech->has_feedback_error_ok(qr/A Change to Carrier Automation MUST have a Reason/,"Can't Change rtcb without reason message");

    # TEST manually change rtcb field to FALSE with reason
    $mech->submit_form_ok({
        with_fields => {
                rtcb => 0,
                rtcb_reason => 'TEST REASON 1',
            },
        button  => 'submit'
      }, 'Change rtcb field with a reason');
    $mech->no_feedback_error_ok;
    $mech->has_feedback_success_ok(qr/Shipment Updated/,"Shipment Updated");

    _test_rtcb_and_log_changes( $mech, $shipment, $rtcb_log, 0, "TEST REASON 1", $users_name );

    $mech   = $mech->test_edit_shipment( $ship_nr );
    isnt($mech->form_with_fields('rtcb'),undef,'rtcb field is still in form');
    cmp_ok($mech->value("rtcb"),"==",0,"rtcb field on form is set to No");

    # TEST change shipping option to another non-premier and rtcb field remains FALSE
    $mech->submit_form_ok({
        with_fields => {
                shipping_charge_id  => $non_prem_charge[1]
            },
        button => 'submit'
      }, 'Change Shipping Option to another Non-Premier');
    $mech->no_feedback_error_ok;
    $mech->has_feedback_success_ok(qr/Shipment Updated/,"Shipment Updated");

    _test_rtcb_and_log_changes( $mech, $shipment, $rtcb_log, 0, "TEST REASON 1", $users_name );
    cmp_ok($shipment->shipment_type_id,"!=",$SHIPMENT_TYPE__PREMIER,'Shipment Type is still Non-Premier');

    $mech   = $mech->test_edit_shipment( $ship_nr );
    isnt($mech->form_with_fields('rtcb'),undef,'rtcb field is still in form');
    cmp_ok($mech->value("rtcb"),"==",0,"rtcb field on form is still set to No");

    # TEST change shipping option to be premier & manual change rtcb to TRUE with reason,
    #      rtcb should remain FALSE & now not be editable and reason in log should not have changed
    $mech->submit_form_ok({
        with_fields => {
                shipping_charge_id  => $premier_charge,
                rtcb => 1,
                rtcb_reason => 'TEST REASON 2'
            },
        button => 'submit'
      }, 'Change Shipping Option to Premier & Manually change rtcb to TRUE');
    $mech->no_feedback_error_ok;
    $mech->has_feedback_success_ok(qr/Shipment Updated/,"Shipment Updated");

    _test_rtcb_and_log_changes( $mech, $shipment, $rtcb_log, 0, "TEST REASON 1", $users_name );
    cmp_ok($shipment->shipment_type_id,"==",$SHIPMENT_TYPE__PREMIER,'Shipment Type is Premier');

    $mech   = $mech->test_edit_shipment( $ship_nr );
    is($mech->form_with_fields('rtcb'),undef,"rtcb field shouldn't be in the form");

    # TEST change shipping option to non-premier, rtcb should got to TRUE reason should be a system message
    $mech->submit_form_ok({
        with_fields => {
                shipping_charge_id  => $non_prem_charge[0]
            },
        button => 'submit'
      }, 'Change Shipping Option to Non-Premier');
    $mech->no_feedback_error_ok;
    $mech->has_feedback_success_ok(qr/Shipment Updated/,"Shipment Updated");

    _test_rtcb_and_log_changes( $mech, $shipment, $rtcb_log, 1, "AUTO: Changed After 'is_autoable' TEST", $users_name );

    $mech   = $mech->test_edit_shipment( $ship_nr );
    isnt($mech->form_with_fields('rtcb'),undef,'rtcb field is back in the form');
    cmp_ok($mech->value("rtcb"),"==",1,"rtcb field on form is set to Yes");

    # TEST manually change rtcb to FALSE with reason
    $mech->submit_form_ok({
        with_fields => {
                rtcb => 0,
                rtcb_reason => 'TEST REASON 3'
            },
        button => 'submit'
      }, 'Manually Change rtcb to FALSE with TEST REASON 3');
    $mech->no_feedback_error_ok;
    $mech->has_feedback_success_ok(qr/Shipment Updated/,"Shipment Updated");

    _test_rtcb_and_log_changes( $mech, $shipment, $rtcb_log, 0, "TEST REASON 3", $users_name );

    $mech   = $mech->test_edit_shipment( $ship_nr );
    isnt($mech->form_with_fields('rtcb'),undef,'rtcb field is in the form');
    cmp_ok($mech->value("rtcb"),"==",0,"rtcb field on form is set to No");

    # TEST manually change rtcb to TRUE with reason
    $mech->submit_form_ok({
        with_fields => {
                rtcb => 1,
                rtcb_reason => 'TEST REASON 4'
            },
        button => 'submit'
      }, 'Manually Change rtcb to TRUE with TEST REASON 4');
    $mech->no_feedback_error_ok;
    $mech->has_feedback_success_ok(qr/Shipment Updated/,"Shipment Updated");

    _test_rtcb_and_log_changes( $mech, $shipment, $rtcb_log, 1, "TEST REASON 4", $users_name );

    $mech   = $mech->test_edit_shipment( $ship_nr );
    isnt($mech->form_with_fields('rtcb'),undef,'rtcb field is in the form');
    cmp_ok($mech->value("rtcb"),"==",1,"rtcb field on form is set to Yes");

    # TEST manually change rtcb to FALSE with reason
    $mech->submit_form_ok({
        with_fields => {
                rtcb => 0,
                rtcb_reason => 'TEST REASON 5'
            },
        button => 'submit'
      }, 'Manually Change rtcb to FALSE with TEST REASON 5');
    $mech->no_feedback_error_ok;
    $mech->has_feedback_success_ok(qr/Shipment Updated/,"Shipment Updated");

    _test_rtcb_and_log_changes( $mech, $shipment, $rtcb_log, 0, "TEST REASON 5", $users_name );

    $mech   = $mech->test_edit_shipment( $ship_nr );
    isnt($mech->form_with_fields('rtcb'),undef,'rtcb field is in the form');
    cmp_ok($mech->value("rtcb"),"==",0,"rtcb field on form is set to No");

    # TEST submit form with no changes while rtcb is FALSE and should stay false
    my $old_rec = $shipment;

    $mech->submit_form_ok({
        form_name => 'editShipment',
        button => 'submit'
      }, 'Submit Form with NO Changes while rtcb is FALSE');
    $mech->no_feedback_error_ok;
    $mech->has_feedback_success_ok(qr/Shipment Updated/,"Shipment Updated");

    _test_rtcb_and_log_changes( $mech, $shipment, $rtcb_log, 0, "TEST REASON 5", $users_name );

    # check shipment record hasn't changed at all
    is($shipment->get_column($_),$old_rec->get_column($_),"No Change in Shipment Field $_")
        for $shipment->columns;

    $mech   = $mech->test_edit_shipment( $ship_nr );
    isnt($mech->form_with_fields('rtcb'),undef,'rtcb field is still in the form');
    cmp_ok($mech->value("rtcb"),"==",0,"rtcb field on form is still set to No");

    # TEST manually change rtcb to TRUE with reason
    $mech->submit_form_ok({
        with_fields => {
                rtcb => 1,
                rtcb_reason => 'TEST REASON 6'
            },
        button => 'submit'
      }, 'Manually Change rtcb to TRUE with TEST REASON 6');
    $mech->no_feedback_error_ok;
    $mech->has_feedback_success_ok(qr/Shipment Updated/,"Shipment Updated");

    _test_rtcb_and_log_changes( $mech, $shipment, $rtcb_log, 1, "TEST REASON 6", $users_name );

    $mech   = $mech->test_edit_shipment( $ship_nr );
    isnt($mech->form_with_fields('rtcb'),undef,'rtcb field is in the form');
    cmp_ok($mech->value("rtcb"),"==",1,"rtcb field on form is set to Yes");

    # TEST submit form with no changes while rtcb is TRUE and should stay true
    $old_rec = $shipment;

    $mech->submit_form_ok({
        form_name => 'editShipment',
        button => 'submit'
      }, 'Submit Form with NO Changes while rtcb is TRUE');
    $mech->no_feedback_error_ok;
    $mech->has_feedback_success_ok(qr/Shipment Updated/,"Shipment Updated");

    _test_rtcb_and_log_changes( $mech, $shipment, $rtcb_log, 1, "TEST REASON 6", $users_name );

    # check shipment record hasn't changed at all
    is($shipment->get_column($_),$old_rec->get_column($_),"No Change in Shipment Field $_")
        for $shipment->columns;

    $mech   = $mech->test_edit_shipment( $ship_nr );
    isnt($mech->form_with_fields('rtcb'),undef,'rtcb field is still in the form');
    cmp_ok($mech->value("rtcb"),"==",1,"rtcb field on form is still set to Yes");

    # TEST set back to Premier Change country address to 'United Kingdom' which can be autoable
    #      then set back to Non-Premier and rtcb field should still not be editable
    $mech->submit_form_ok({
        with_fields => {
                shipping_charge_id  => $premier_charge,
            },
        button => 'submit'
      }, 'Change Shipping Option to Premier');
    $mech->no_feedback_error_ok;
    $mech->has_feedback_success_ok(qr/Shipment Updated/,"Shipment Updated");

    _test_rtcb_and_log_changes( $mech, $shipment, $rtcb_log, 0, "AUTO: Changed After 'is_autoable' TEST", $users_name );

    $mech   = $mech->test_edit_shipment( $ship_nr );
    is($mech->form_with_fields('rtcb'),undef,'rtcb field should not be in the form');

    Test::XTracker::Data->order_address( {
                                            address     => 'update',
                                            address_id  => $shipment->shipment_address_id,
                                            country     => 'United Kingdom',
                                        } );

    $mech->submit_form_ok({
        with_fields => {
                shipping_charge_id  => $non_prem_charge[0]
            },
        button => 'submit'
      }, 'Change Shipping Option to Non-Premier with shipping address country as United Kindom');
    $mech->no_feedback_error_ok;
    $mech->has_feedback_success_ok(qr/Shipment Updated/,"Shipment Updated");

    _test_rtcb_and_log_changes( $mech, $shipment, $rtcb_log, 0, "AUTO: Changed After 'is_autoable' TEST", $users_name );

    $mech   = $mech->test_edit_shipment( $ship_nr );
    isnt($mech->form_with_fields('rtcb'),undef,'rtcb field should now be in the form');

    # TEST put address back to US and change to Premier and then back to Non-Premier to get rtcb field to true
    Test::XTracker::Data->order_address( {
        address     => 'update',
        address_id  => $shipment->shipment_address_id,
        country     => 'United States',
    } );
    $shipment->discard_changes;
    $shipment->update( { shipping_account_id => $acc_id } );

    $mech   = $mech->test_edit_shipment( $ship_nr );
    isnt($mech->form_with_fields('rtcb'),undef,'rtcb field found in the form again');

    $mech->submit_form_ok({
        with_fields => {
                shipping_charge_id  => $premier_charge
            },
        button => 'submit'
      }, 'Change Shipping Option to Premier with shipping address country back to United States');
    $mech->no_feedback_error_ok;
    $mech->has_feedback_success_ok(qr/Shipment Updated/,"Shipment Updated");

    _test_rtcb_and_log_changes( $mech, $shipment, $rtcb_log, 0, "AUTO: Changed After 'is_autoable' TEST", $users_name );

    $mech   = $mech->test_edit_shipment( $ship_nr );
    is($mech->form_with_fields('rtcb'),undef,'rtcb field not found in the form again');

    $mech->submit_form_ok({
        with_fields => {
                shipping_charge_id  => $non_prem_charge[0]
            },
        button => 'submit'
      }, 'Change Shipping Option to Non-Premier with shipping address country back to United States');
    $mech->no_feedback_error_ok;
    $mech->has_feedback_success_ok(qr/Shipment Updated/,"Shipment Updated");

    _test_rtcb_and_log_changes( $mech, $shipment, $rtcb_log, 1, "AUTO: Changed After 'is_autoable' TEST", $users_name );

    $mech   = $mech->test_edit_shipment( $ship_nr );
    isnt($mech->form_with_fields('rtcb'),undef,'rtcb field found in the form again');
    cmp_ok($mech->value("rtcb"),"==",1,"rtcb field on form is set to Yes");

    # TEST setting GIFT flag to TRUE which should make rtcb field FALSE and un-editable
    $mech->submit_form_ok({
        with_fields => {
                gift    => 1,
                gift_msg=> 'This is a test message'
            },
        button => 'submit'
      }, 'Change Shipment to be a Gift Shipment');
    $mech->no_feedback_error_ok;
    $mech->has_feedback_success_ok(qr/Shipment Updated/,"Shipment Updated");

    _test_rtcb_and_log_changes( $mech, $shipment, $rtcb_log, 1, "AUTO: Changed After 'is_autoable' TEST", $users_name );

    $mech   = $mech->test_edit_shipment( $ship_nr );

    cmp_ok($shipment->gift,"==",1,"Gift flag is set on Shipment record");
    is($shipment->gift_message,"This is a test message","Gift Message on Shipment is Correct");
    $mech->form_with_fields('gift');
    cmp_ok($mech->value("gift"),"==",1,"Gift Flag is set to Yes in Form");
    is($mech->value("gift_msg"),"This is a test message","Gift Message in Form is Correct");

    isnt($mech->form_with_fields('rtcb'),undef,"A Gift Shipment means the rtcb field shouldn't be in the form");

    # TEST setting GIFT flag to FALSE which should keep rtcb field TRUE and editable
    $mech->submit_form_ok({
        with_fields => {
                gift    => 0
            },
        button => 'submit'
      }, 'Change Shipment to be a Non-Gift Shipment');
    $mech->no_feedback_error_ok;
    $mech->has_feedback_success_ok(qr/Shipment Updated/,"Shipment Updated");

    _test_rtcb_and_log_changes( $mech, $shipment, $rtcb_log, 1, "AUTO: Changed After 'is_autoable' TEST", $users_name );

    $mech   = $mech->test_edit_shipment( $ship_nr );

    cmp_ok($shipment->gift,"==",0,"Gift flag is not set on Shipment record");
    $mech->form_with_fields('gift');
    cmp_ok($mech->value("gift"),"==",0,"Gift Flag is set to No in Form");

    isnt($mech->form_with_fields('rtcb'),undef,'A Non-Gift Shipment means the rtcb field should be in the form again');
    cmp_ok($mech->value("rtcb"),"==",1,"rtcb field on form is set to Yes");

    # TEST Manually set rtcb to FALSE with reason then manualy set rtcb to TRUE with reason but set gift flag to true
    #      which should mean the rtcb field remains false with no change in reason
    $mech->submit_form_ok({
        with_fields => {
                rtcb => 0,
                rtcb_reason => 'TEST REASON 7'
            },
        button => 'submit'
      }, 'Manually Change rtcb to FALSE with TEST REASON 7');
    $mech->no_feedback_error_ok;
    $mech->has_feedback_success_ok(qr/Shipment Updated/,"Shipment Updated");

    _test_rtcb_and_log_changes( $mech, $shipment, $rtcb_log, 0, "TEST REASON 7", $users_name );

    $mech   = $mech->test_edit_shipment( $ship_nr );

    $mech->submit_form_ok({
        with_fields => {
                gift        => 1,
                gift_msg    => 'This is another Gift Message',
                rtcb        => 1,
                rtcb_reason => 'TEST REASON 8'
            },
        button => 'submit'
      }, 'Manually Change rtcb to TRUE with TEST REASON 8 and set Gift Flag at the same time');
    $mech->no_feedback_error_ok;
    $mech->has_feedback_success_ok(qr/Shipment Updated/,"Shipment Updated");

    # rtcb should remain false with no change in log
    _test_rtcb_and_log_changes( $mech, $shipment, $rtcb_log, 1, "TEST REASON 8", $users_name );

    $mech   = $mech->test_edit_shipment( $ship_nr );
    isnt($mech->form_with_fields('rtcb'),undef,"rtcb field should be un-editable");

    # TEST make shipment premier while being a Gift Shipment then set to being Non-Premier
    #      and rtcb field should still be un-editable

    $mech->submit_form_ok({
        with_fields => {
                shipping_charge_id  => $premier_charge
            },
        button => 'submit'
      }, 'Change Shipping Option to Premier while Gift Flag is Set');
    $mech->no_feedback_error_ok;
    $mech->has_feedback_success_ok(qr/Shipment Updated/,"Shipment Updated");

    # rtcb should remain false with no change in log
    _test_rtcb_and_log_changes( $mech, $shipment, $rtcb_log, 0, "AUTO: Changed After 'is_autoable' TEST", $users_name );

    $mech   = $mech->test_edit_shipment( $ship_nr );
    is($mech->form_with_fields('rtcb'),undef,"Premier & Gift: rtcb field should still be un-editable");

    $mech->submit_form_ok({
        with_fields => {
                shipping_charge_id  => $non_prem_charge[0]
            },
        button => 'submit'
      }, 'Change Shipping Option to Non-Premier while Gift Flag is Set');
    $mech->no_feedback_error_ok;
    $mech->has_feedback_success_ok(qr/Shipment Updated/,"Shipment Updated");

    # rtcb should remain false with no change in log
    _test_rtcb_and_log_changes( $mech, $shipment, $rtcb_log, 1, "AUTO: Changed After 'is_autoable' TEST", $users_name );

    $mech   = $mech->test_edit_shipment( $ship_nr );
    isnt($mech->form_with_fields('rtcb'),undef,"Non-Premier & Gift: rtcb field should still be un-editable");

    # set shipment to be autoable just to tidy up
    $mech->submit_form_ok({
        with_fields => {
                gift    => 0
            },
        button => 'submit'
      }, 'Change Shipment to be a Non-Gift Shipment');
    $mech->no_feedback_error_ok;
    $mech->has_feedback_success_ok(qr/Shipment Updated/,"Shipment Updated");

    _test_rtcb_and_log_changes( $mech, $shipment, $rtcb_log, 1, "AUTO: Changed After 'is_autoable' TEST", $users_name );

    $mech   = $mech->test_edit_shipment( $ship_nr );

    isnt($mech->form_with_fields('rtcb'),undef,'A Non-Gift Shipment means the rtcb field should be in the form again');
    cmp_ok($mech->value("rtcb"),"==",1,"rtcb field on form is set to Yes");

    # test setting Automation Switch to 'Off' and the Shipment's automation flag should
    # then be set to FALSE each time the page is submitted, even if trying to explicitly set it to TRUE

    # First try with State 'Import_Off_Only' this shouldn't make a difference
    Test::XTracker::Data->set_carrier_automation_state( $channel->id, 'Import_Off_Only' );
    $mech   = $mech->test_edit_shipment( $ship_nr );
    $mech->submit_form_ok( {
        form_name   => 'editShipment',
        button      => 'submit',
    }, "Update with Automation State turned to 'Import_Off_Only'" );
    $mech->no_feedback_error_ok;
    $mech->has_feedback_success_ok(qr/Shipment Updated/,"Shipment Updated");
    _test_rtcb_and_log_changes( $mech, $shipment, $rtcb_log, 1, "AUTO: Changed After 'is_autoable' TEST", $users_name );

    # Now try with State 'Off' this shouldn't make a difference
    Test::XTracker::Data->set_carrier_automation_state( $channel->id, 'Off' );
    $mech   = $mech->test_edit_shipment( $ship_nr );
    $mech->submit_form_ok( {
        form_name   => 'editShipment',
        button      => 'submit',
    }, "Update with Automation State turned to 'Off'" );
    $mech->no_feedback_error_ok;
    $mech->has_feedback_success_ok(qr/Shipment Updated/,"Shipment Updated");
    _test_rtcb_and_log_changes( $mech, $shipment, $rtcb_log, 0, "STATE: Carrier Automation State is 'Off'", $users_name );
    $mech   = $mech->test_edit_shipment( $ship_nr );
    isnt($mech->form_with_fields('rtcb'),undef,'rtcb field should still be in the form');
    # now try and explicitly set it to yes
    $mech->submit_form_ok( {
        with_fields => {
            rtcb        => 1,
            rtcb_reason => 'DO IT NOW',
        },
        button      => 'submit',
    }, "Update with Automation State turned to 'Off' but explicitly turning rtcb to 'Yes'" );
    $mech->no_feedback_error_ok;
    $mech->has_feedback_success_ok(qr/Shipment Updated/,"Shipment Updated");
    _test_rtcb_and_log_changes( $mech, $shipment, $rtcb_log, 0, "STATE: Carrier Automation State is 'Off'", $users_name );

    # turn Automation back on again
    Test::XTracker::Data->set_carrier_automation_state( $channel->id, 'On' );
    $mech   = $mech->test_edit_shipment( $ship_nr );
    $mech->submit_form_ok( {
        with_fields => {
            rtcb        => 1,
            rtcb_reason => 'TURN IT ON AGAIN',
        },
        button      => 'submit',
    }, "Update with Automation State turned back 'On'" );
    $mech->no_feedback_error_ok;
    _test_rtcb_and_log_changes( $mech, $shipment, $rtcb_log, 1, "TURN IT ON AGAIN", $users_name );

    $mech   = $mech->test_edit_shipment( $ship_nr );

    return $mech;
}

=head2 test_ca_field_visibility

Create a shipment and make sure it has a non-premier shipping charge.

Make sure the shipment has a valid address and is automated.

Login as customercare and select the shipment. Verify that the shipment is
still automated but that customer care can't change the rtcb flag.

Pick the shipment, and verify that while the rtcb flag is on, customer care
can't see the carrier automation section.

Verify that distribution management and customer care manager departments have
a read-only view of the rtcb flag on the edit shipment page, whilst shipping
and shippihg manager can edit it.

Pack the shipment, and repeat the above department-based tests.

Set the shipment to not be carrier automated, and create a UPS manifest (it
should appear on it).

Verify that none of the above departments can edit the rtcb flag but they can
all see it on the edit shipment page.

Cancel the manifest and make the shipment automated again.

Set outward and return waybills and dispatch the shipment.

Check that nowhere have we have only produced the following documents: invoice,
return proforma or gift message warning (tbh these tests should follow the
calls that produce them, they shouldn't be right at the end).

=cut

sub test_ca_field_visibility : Tests {
    my ( $self ) = @_;

    my $mech = $self->{mech};
    my $skus = $self->{skus};
    my $channel = $self->{channel};

    my $schema      = $self->{schema};
    my $dbh         = $schema->storage->dbh;

    my $shipment_id  = $self->{shipment_id};
    my $shipment = $schema->resultset('Public::Shipment')->find( $shipment_id );

    # get premier and non-premier shipping charges
    my ($premier_charge, @non_prem_charge )
        = $self->get_shipping_charges( $shipment );

    $mech->test_edit_shipment( $shipment_id );
    # TEST changing shipping option to non-premier means rtcb can be edited
    $mech->submit_form_ok({
        with_fields => {
                shipping_charge_id  => $non_prem_charge[0]
            },
        button => 'submit'
      }, 'Change Shipping Option to Non-Premier');
    $mech->no_feedback_error_ok;
    $mech->has_feedback_success_ok(qr/Shipment Updated/,"Shipment Updated");

    # departments which should be-able to see the carrier automation field when the process has begun
    # and whether they can edit the field or not
    my @depts       = (
                        { dept => 'Distribution Management', canedit => 0 },
                        { dept => 'Shipping', canedit => 1 },
                        { dept => 'Shipping Manager', canedit => 1 },
                        { dept => 'Customer Care Manager', canedit => 0 },
                    );

    note "TESTING visibility of rtcb field through the selection - picking - packing - dispatch process";

    Test::XTracker::Data->set_department('it.god', 'Customer Care');
    my @manifests   = Test::XTracker::Data->clear_existing_manifest( "UPS" );

    # test that when the API Call passes it gives the appropriate message
    # make sure there is a good shipping address
    Test::XTracker::Data->ca_good_address( $shipment );

    set_carrier_automated( $dbh, $shipment_id, 1 );

    # TEST can still see rtcb field after shipment has been 'selected'

    # update shipment items to be selected
    my $print_directory = Test::XTracker::PrintDocs->new();
    if ($prl_rollout_phase) {
        Test::XTracker::Data::Order->select_order($shipment->order);
    } else {
        $mech   = $mech->test_direct_select_shipment( $shipment_id );
    }

    $mech->test_edit_shipment( $shipment_id );
    $mech->has_tag('h3','Shipment Carrier Automation','Has Carrier Automation Heading');
    is($mech->form_with_fields('rtcb'),undef,'rtcb field should not be in the form when in Customer Care department');
    $mech->content_like( qr/Use Carrier Automation:.*Yes.*show change log/s, 'rtcb field value should still be displayed (Yes)' );

    # TEST can't see rtcb field after shipment has been 'picked' as 'Customer Care' Dept.
    if ($prl_rollout_phase) {
        my $container_id = Test::XT::Data::Container->get_unique_id({ how_many => 1 });
        $self->{framework}->flow_msg__prl__pick_shipment(
            shipment_id => $shipment->id,
            container => {
                $container_id => [keys %$skus],
            }
        );
        $self->{framework}->flow_msg__prl__induct_shipment(
            shipment_id => $shipment->id,
        );
    } else {
        $skus  = $mech->get_info_from_picklist( $print_directory, $skus );
        $mech->test_pick_shipment( $shipment_id, $skus );
    }

    $mech->test_edit_shipment( $shipment_id );

    $mech->content_unlike( qr/Shipment Carrier Automation/, "Shouldn't see Carrier Automation Section when in Customer Care Department" );
    is($mech->form_with_fields('rtcb'),undef,'rtcb field should not be in the form');

    # TEST can see rtcb field after shipment has been 'picked' as a few departments
    for my $dept ( @depts ) {
        $self->_test_rtcb_see_edit_ability_by_dept( $shipment_id, 1, @{$dept}{qw/dept canedit/} );
    }

    $mech->get_ok( '/Fulfilment/Packing' );

    # Making this test a bit more resilient
    my $ps  = get_packing_stations( $schema, $channel->id );
    # Just get the first packing station of the available for this channel-
    my $packing_station = (sort @{$ps})[0];

    $mech->follow_link_ok( { text_regex => qr/^Set Packing Station/ }, "Go To 'Set Packing Station' Page Again" );
    $mech->submit_form_ok({
            with_fields => {
                ps_name => $packing_station,
            },
            button => 'submit',
      }, 'Change Packing Station to '.$packing_station);
    $mech->no_feedback_error_ok;
    $mech->has_feedback_success_ok( qr/Packing Station Selected/, "Changed Packing Station Name to $packing_station");

    $mech->test_pack_shipment($shipment_id, $skus);

    # NOTE: We will experience failures here when we can't connect to UPS, so
    # expect some tests to fail here if you're running tests locally
    # TEST can see rtcb field after shipment has been 'packed' as a few departments
    for my $dept ( @depts ) {
        $self->_test_rtcb_see_edit_ability_by_dept( $shipment_id, 1, @{$dept}{qw/dept canedit/} )
    }

    # TEST can see rtcb field after shipment has been 'manifested' but can't edit it, for a few departments only

    # set all depts so they can't edit the field as this is the case from now on
    $_->{canedit} = 0 for @depts;

    set_carrier_automated( $dbh, $shipment_id, 0 );     # make it so shipment should appear on manifest
    my $manifest_id = $mech->create_manifest( "UPS" );

    # check depts can't edit field only see it
    for my $dept ( @depts ) {
        $self->_test_rtcb_see_edit_ability_by_dept( $shipment_id, 0, @{$dept}{qw/dept canedit/} );
    }

    $mech->cancel_manifest( $manifest_id );
    Test::XTracker::Data->restore_cleared_manifest( @manifests );

    # TEST can see rtcb field after shipment has been 'dispatched' but can't edit it as a few departments

    # set the AWB's so it will dispatch
    set_carrier_automated( $dbh, $shipment_id, 1 );     # make shipment automated again
    my ( $out_awb, $ret_awb ) = Test::XTracker::Data->generate_air_waybills;
    $shipment->discard_changes;
    $shipment->update( {
                    outward_airway_bill => $out_awb,
                    return_airway_bill  => $ret_awb,
                } );

    $mech->test_dispatch( $shipment_id );

    # check depts can't edit field only see it
    for my $dept ( @depts ) {
        $self->_test_rtcb_see_edit_ability_by_dept( $shipment_id, 1, @{$dept}{qw/dept canedit/} );
    }

    # NOTE: When we run this test locally we can't connect to UPS so we output
    # some extra documentation due to the shipment not be CA'able, producing a
    # test failure.
    # TODO We expect some files from the above tests: these tests should check them
    my @unexpected_files =
        grep { $_->file_type !~ /^(invoice|retpro|giftmessagewarning)$/ }
        $print_directory->new_files();
    ok(!@unexpected_files, 'should not have any unexpected print files')
        or diag pp \@unexpected_files;
}


# runs repetitve tests after making the changes through the page
sub _test_rtcb_and_log_changes {
    my ( $mech, $shipment, $log, $value, $reason, $user )   = @_;

    $shipment->discard_changes;
    $log->reset;

    my $log_rec = $log->next;

    cmp_ok($shipment->real_time_carrier_booking,"==",$value,"rtcb field set to $value on shipment");
    is($log_rec->operator->name,$user,"Last Log was by $user");
    cmp_ok($log_rec->new_state,"==",$value,"Last Log State was $value");
    is($log_rec->reason_for_change,$reason,"Last Log Reason was $reason");

    ok( $mech->get_table_row( "Carrier Automated:" ), "Found 'Carrier Automated' field in Shipment Details" );
    if ( $value ) {
        isa_ok($mech->find_image( alt => 'Shipment Automated' ),'WWW::Mechanize::Image',"Found 'Tick' next to 'Carrier Automated'");
    }
    else {
        is($mech->find_image( alt => 'Shipment Automated' ),undef,"NOT Found 'Tick' next to 'Carrier Automated'");
    }
}

# runs reptitive tests to decide which departments can see and edit the rtcb field and which can only see it
# when the Edit Shipment page has been displayed
sub _test_rtcb_see_edit_ability_by_dept {
    my ( $self, $ship_nr, $rtcb_val, $department, $can_edit ) = @_;

    my $mech = $self->{mech};

    # TODO: Move these somewhere shared so we can stop doing with_form_fields,
    # which produces a warning whenever it doesn't find the field
    my %xpath = (
        rtcb_radio => q{//div[contains(@class, 'formrow')]//input[@name='rtcb' and @checked]},
        rtcb_readonly => q{id('rtcb_readonly')},
    );

    Test::XTracker::Data->set_department('it.god', $department);
    $mech->test_edit_shipment( $ship_nr );
    $mech->has_tag('h3','Shipment Carrier Automation',
        "Has Carrier Automation Heading under $department department");

    my $el = $mech->find_xpath($xpath{rtcb_radio})->pop;
    if ( $can_edit ) {
        ok($el, "rtcb field editable in the form for $department department");
        ok( ($rtcb_val ? $el->attr('value') : !$el->attr('value')),
            sprintf "rtcb value should be set to %s", $rtcb_val ? 'Yes' : 'No' );
    }
    else {
        ok(!$el, "rtcb field should not be in the form when in $department department");
        is( $mech->find_xpath($xpath{rtcb_readonly})->pop->as_trimmed_text,
            ($rtcb_val ? 'Yes' : 'No'),
            sprintf "rtcb value should be %s", $rtcb_val ? 'Yes' : 'No'
        );
    }
    return;
}

sub setup_user_perms {
    my ( $self ) = @_;
    Test::XTracker::Data->grant_permissions('it.god', 'Customer Care', 'Order Search', 2);
    # Perms needed for the order process
    for (qw/Airwaybill Dispatch Packing Picking Selection Labelling Manifest/ ) {
        Test::XTracker::Data->grant_permissions('it.god', 'Fulfilment', $_, 2);
    }
}

# First time check that we can get the order via search
# Other times go straight to that url
sub gather_order_info {
    my ( $self, $order_nr ) = @_;

    my $mech = $self->{mech};

    $mech->get_ok($mech->order_view_url);

    # On the order view page we need to find the shipment ID

    my $ship_nr = $mech->get_table_value('Shipment Number:');

    my $status = $mech->get_table_value('Order Status:');


    my $category = $mech->get_table_value('Customer Category:');
    return ($ship_nr, $status, $category);
}
