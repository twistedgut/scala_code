package Test::NAP::CustomerCare::OrderSearch::CreateShipment;

use NAP::policy "tt", qw/class test/;

BEGIN { # at BEGIN time to play nicely with Test::Class
    extends "NAP::Test::Class";
};

use FindBin::libs;
use Test::XTracker::RunCondition prl_phase => 'prl';
use XTracker::Constants::FromDB qw/
    :authorisation_level
    :shipment_item_status
    :shipment_status
/;
use XTracker::Database::Department qw/customer_care_department_group/;
use XTracker::Config::Local qw/config_var/;
use Test::XT::Flow;

sub check_that_allocation_message_is_sent_to_prl :Tests {
    my $self = shift;

    # get local currency - to update the Order with to keep things proper
    my $currency = $self->schema->resultset('Public::Currency')
        ->search({ currency => config_var( Currency => 'local_currency_code') })
        ->first;

    my $framework = Test::XT::Flow->new_with_traits(
        traits => [
            'Test::XT::Flow::Fulfilment',
            'Test::XT::Flow::CustomerCare',
            'Test::XT::Data::Channel',
        ],
    );

    note 'Make sure current user is logged in and belongs to Distibution Management';
    Test::XTracker::Data->set_department( 'it.god', 'Distribution Management' );
    $framework->login_with_permissions( {
        perms => {
            $AUTHORISATION_LEVEL__OPERATOR => [
                'Customer Care/Customer Search',
            ]
        }
    } );

    my $order_details = $framework->flow_db__fulfilment__create_order(
        channel  => $framework->channel,
        products => 1,
    );
    my $order    = $order_details->{order_object};
    my $shipment = $order_details->{shipment_object};
    $order->update({
        currency_id => $currency->id,
    });

    note 'Set the Shipment & Shipment Items as Dispatched';
    $shipment->update({
        shipment_status_id => $SHIPMENT_STATUS__DISPATCHED,
        signature_required => 0,
    });
    $shipment->shipment_items->update({
        shipment_item_status_id => $SHIPMENT_ITEM_STATUS__DISPATCHED,
    });

    note 'Prepare to capture AMQ messages';
    my $factory = Test::XTracker::MessageQueue->new;
    my $msg_dir = Test::XTracker::Artifacts::RAVNI->new('xt_to_prls');

    $framework->flow_mech__customercare__orderview( $order->id )
        ->flow_mech__customercare__create_shipment
        ->flow_mech__customercare__create_shipment_submit( 'Replacement' )
        ->flow_mech__customercare__create_shipment_item_submit( [ map { $_->id } $shipment->shipment_items->all ] )
        ->flow_mech__customercare__create_shipment_final_submit;

    note 'Check that Allocate message was sent';
    for my $message ( $msg_dir->new_files ) {
        is(
            $message->{payload_parsed}{'@type'},
            'allocate',
            'Allocation message was sent for newly created shipment'
        );

        ok(
            $self->schema->resultset('Public::Allocation')->find($message->{payload_parsed}{allocation_id}),
            'Allocation was created in the Database'
        );
    }
}
