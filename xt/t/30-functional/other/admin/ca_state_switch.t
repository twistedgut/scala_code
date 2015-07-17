#!/usr/bin/env perl

use NAP::policy 'test';

=head1 NAME

ca_state_switch.t - Test Carrier Automation page

=head1 DESCRIPTION

Runs in all DCs and all see the carrier automation menu entry.

#TAGS carrier ups admin

=cut


use FindBin::libs;


use XTracker::Constants::FromDB     qw(
                                        :carrier
                                        :channel
                                        :authorisation_level
                                    );
use XTracker::Constants             qw( :carrier_automation );
use Test::XTracker::Data;

use Test::XTracker::Mechanize;
use XTracker::Config::Local         qw( :DEFAULT :carrier_automation config_var );
use XTracker::Config::Parameters qw( sys_param);

my $mech    = Test::XTracker::Mechanize->new;
my $schema  = Test::XTracker::Data->get_schema;

my $current_ups_ca_states = $schema->resultset('Public::Channel')->get_carrier_automation_states();

my $dhl_ca_status = sys_param('dhl_carrier_automation/is_dhl_automated');

test_ca_state_switch($mech,$schema);

Test::XTracker::Data->restore_carrier_automation_state( $current_ups_ca_states ) if config_var( 'UPS', 'enabled' );
sys_param('dhl_carrier_automation/is_dhl_automated',$dhl_ca_status);

done_testing;

=head2 test_ca_state_switch

 $mech  = test_ca_state_switch($mech,$schema);

Test the 'Carrier Automation' page.

Runs in all DCs for DHL and tests channel carrier automation where UPS is enabled.
It sets the DHL automation C<Off> and, where appropriate, all channels' states to
C<Import_Off_Only>. Logs in as a manager, checks that the carrier automation
states are as expected and can be updated. For the channels tests update states
on multiple channels in the same request. Tests updating to an incorrect state(?) errors.

=cut


sub test_ca_state_switch {
    my ($mech,$schema)      = @_;

    my $operator    = Test::XTracker::Data->_get_operator( 'it.god' );

    # grant permission with manager level access, to test the read/write version of the page
    Test::XTracker::Data->grant_permissions('it.god', 'Admin', 'Carrier Automation', $AUTHORISATION_LEVEL__MANAGER);
    $mech->do_login;

    note "TESTING DHL CA Automation State Switch";

    my $carrier = $schema->resultset('Public::Carrier')->find( $CARRIER__DHL_EXPRESS );
    #switch off carrier automation to start with
    sys_param('dhl_carrier_automation/is_dhl_automated',0);
    # check the ca state for the carrier DHL
    $mech->get_ok('/Admin/CarrierAutomation');
    my $form    = $mech->form_with_fields( 'dhl_state' );
    is( $mech->value( 'dhl_state' ), sys_param('dhl_carrier_automation/is_dhl_automated'), "Selected Value in field matches what is in the DB" );

    # switch on carrier automation
    $mech->get_ok('/Admin/CarrierAutomation');
    my $fields_to_set   = { 'dhl_state' => 1 };
    $mech->submit_form_ok( {
        with_fields => $fields_to_set,
        button  => 'submit',
    }, "Update State to '1'" );
    $mech->no_feedback_error_ok;
    $mech->has_feedback_success_ok(qr/Updated Carrier Automation State/,"Automation State Updated");
    $carrier->discard_changes;
    $form  = $mech->form_with_fields( 'dhl_state' );
    is( sys_param('dhl_carrier_automation/is_dhl_automated'), 1, "Carrier Automation State updated correctly in DB" );
    is( $mech->value( 'dhl_state' ), 1, "Carrier Automation State set properly in page field" );

    # set the carrier ca to an incorrect state which should fail
    $mech->get_ok('/Admin/CarrierAutomation');
    $mech->submit_form_ok( {
        with_fields => {
                'dhl_state'  => join( '_', @CARRIER_AUTOMATION_STATES ),
        },
        button  => 'submit',
    }, "Set Carrier with an Incorrect State" );
    $mech->has_feedback_error_ok( qr/Unable to update DHL Carrier Automation State Setting/ );
    # check the fields haven't changed
    $carrier->discard_changes;
    is( sys_param('dhl_carrier_automation/is_dhl_automated'), 1, "Carrier DB Field still set to '1'" );

    if ( config_var( 'UPS', 'enabled' ) ) {
        note "TESTING UPS CA Automation State Switch";

        my @channels    = $schema->resultset('Public::Channel')->search( {'is_enabled' => 1}, { order_by => 'me.id' } )->all;
        # set each channel's state to being 'Import_Off_Only'
        Test::XTracker::Data->set_carrier_automation_state( $_->id, 'Import_Off_Only' ) for @channels;

        $mech->get_ok('/Admin/CarrierAutomation');
        # check there are now fields on the page
        foreach my $rec ( @channels ) {
            my $form    = $mech->form_with_fields( 'ups_state_'.$rec->id );
            isa_ok( $form, "HTML::Form", "Form should contain a field for Channel: ".$rec->name );
            is( $mech->value( 'ups_state_'.$rec->id ), $rec->carrier_automation_state, "Selected Value in field matches what is in the DB" );
        }

        # go through each possible state for each channel and test it saves it correctly
        foreach my $state ( @CARRIER_AUTOMATION_STATES ) {
            $mech->get_ok('/Admin/CarrierAutomation');
            my $fields_to_set   = { map { ( 'ups_state_'.$_->id => $state ) } @channels };
            $mech->submit_form_ok( {
                with_fields => $fields_to_set,
                button  => 'submit',
            }, "Update State to '$state'" );
            $mech->no_feedback_error_ok;
            $mech->has_feedback_success_ok(qr/Updated Carrier Automation State/,"Automation State Updated");
            # check each channel has been updated in the page and in the DB
            foreach my $rec ( @channels ) {
                $rec->discard_changes;
                my $form    = $mech->form_with_fields( 'ups_state_'.$rec->id );
                isa_ok( $form, "HTML::Form", "Form should contain a field for Channel: ".$rec->name );
                is( $rec->carrier_automation_state, $state, "Channel State updated correctly in DB" );
                is( $mech->value( 'ups_state_'.$rec->id ), $state, "Channel State set properly in page field" );
            }
        }

        # set the channels states to the middle state
        map { Test::XTracker::Data->set_carrier_automation_state( $_->id, $CARRIER_AUTOMATION_STATES[1] ) } @channels;

        # set on channel to one state and another to another to make sure they are different
        # when updated
        $mech->get_ok('/Admin/CarrierAutomation');
        $mech->submit_form_ok( {
            with_fields => {
                'ups_state_'.$channels[0]->id   => $CARRIER_AUTOMATION_STATES[0],
                'ups_state_'.$channels[-1]->id  => $CARRIER_AUTOMATION_STATES[-1],
            },
            button  => 'submit',
        }, "Update different Channels with different States" );
        $mech->no_feedback_error_ok;
        $mech->has_feedback_success_ok(qr/Updated Carrier Automation State/,"Automation State Updated");
        map { $_->discard_changes } @channels;
        $mech->form_name( 'automationState' );
        # test the first channel
        my $value   = $mech->value( 'ups_state_'.$channels[0]->id );
        is( $channels[0]->carrier_automation_state, $CARRIER_AUTOMATION_STATES[0], "Channel DB Field set correctly: ".$channels[0]->name." - ".$CARRIER_AUTOMATION_STATES[0] );
        is( $value, $CARRIER_AUTOMATION_STATES[0], "Channel Page Field set correctly: ".$channels[0]->name." - ".$CARRIER_AUTOMATION_STATES[0] );
        # test the second channel
        $value   = $mech->value( 'ups_state_'.$channels[-1]->id );
        is( $channels[-1]->carrier_automation_state, $CARRIER_AUTOMATION_STATES[-1], "Channel DB Field set correctly: ".$channels[-1]->name." - ".$CARRIER_AUTOMATION_STATES[-1] );
        is( $value, $CARRIER_AUTOMATION_STATES[-1], "Channel Page Field set correctly: ".$channels[-1]->name." - ".$CARRIER_AUTOMATION_STATES[-1] );

        # set the channels states to the middle state
        map { Test::XTracker::Data->set_carrier_automation_state( $_->id, $CARRIER_AUTOMATION_STATES[1] ) } @channels;

        # set a channel to an incorrect state which should fail
        $mech->get_ok('/Admin/CarrierAutomation');
        $mech->submit_form_ok( {
            with_fields => {
                'ups_state_'.$channels[0]->id   => join( '_', @CARRIER_AUTOMATION_STATES ),
                'ups_state_'.$channels[1]->id   => $CARRIER_AUTOMATION_STATES[0],
            },
            button  => 'submit',
        }, "Set Channel with an Incorrect State" );
        $mech->has_feedback_error_ok( qr/Unable to update UPS Carrier Automation State Setting/ );
        # check the fields haven't changed
        map { $_->discard_changes } @channels;
        $mech->form_name( 'automationState' );
        # test the first channel
        $value   = $mech->value( 'ups_state_'.$channels[0]->id );
        is( $channels[0]->carrier_automation_state, $CARRIER_AUTOMATION_STATES[1], "Channel DB Field still set to '".$CARRIER_AUTOMATION_STATES[1]."' for Channel: ".$channels[0]->name );
        is( $value, $CARRIER_AUTOMATION_STATES[1], "Channel Page Field still set correctly to '".$CARRIER_AUTOMATION_STATES[1]."'" );
        # test the second channel
        $value   = $mech->value( 'ups_state_'.$channels[1]->id );
        is( $channels[1]->carrier_automation_state, $CARRIER_AUTOMATION_STATES[1], "Channel DB Field still set to '".$CARRIER_AUTOMATION_STATES[1]."' for Channel: ".$channels[1]->name );
        is( $value, $CARRIER_AUTOMATION_STATES[1], "Channel Page Field still set correctly to '".$CARRIER_AUTOMATION_STATES[1]."'" );
    }

    return $mech;
}
