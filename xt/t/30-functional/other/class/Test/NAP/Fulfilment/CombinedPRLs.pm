package Test::NAP::Fulfilment::CombinedPRLs;

use NAP::policy qw/test class/;

BEGIN { # at BEGIN time to play nicely with Test::Class
    extends "NAP::Test::Class";
    with 'Test::Role::WithGOHIntegration';
};

use FindBin::libs;
use Test::XTracker::RunCondition prl_phase => 2;
use Test::XT::Flow;
use XTracker::Constants::FromDB qw(
    :allocation_status
    :authorisation_level
    :prl
    :prl_delivery_destination
);

use XT::Data::Fulfilment::GOH::Integration;

use XTracker::Constants qw(
    :application
);
use vars qw/
    $PRL__DEMATIC
    $PRL__FULL
    $PRL__GOH
    $PRL_DELIVERY_DESTINATION__GOH_INTEGRATION
    $PRL_DELIVERY_DESTINATION__GOH_DIRECT
/;

BEGIN {

has flow => (
    is => "ro",
    default => sub {
        my $self = shift;
        my $flow = Test::XT::Flow->new_with_traits(
            traits => [
                'Test::XT::Feature::AppMessages',
                'Test::XT::Flow::Fulfilment',
            ],
        );

        return $flow;
    }
);

}

sub startup : Test(startup) {
    my $self = shift;
    $self->SUPER::startup();

    $self->flow->login_with_permissions({
        perms => { $AUTHORISATION_LEVEL__MANAGER => [
            'Fulfilment/Induction',
            'Fulfilment/Packing',
        ]},
        dept => 'Customer Care'
    });
}

sub full_and_goh_fixture {
    my $self = shift;

    # Create shipment with one pid picked from Full prl and
    # one from GOH. The Full allocation is staged awaiting
    # induction, and the GOH allocation is delivered awaiting
    # integration.

    my $fixture = Test::XT::Fixture::Fulfilment::Shipment
        ->new({
            flow           => $self->flow,
            prl_pid_counts => {'Full' => 1, 'GOH' => 1},
            channel_name   => "nap",
        })
        ->with_normal_sla();

    # Select both parts
    Test::XTracker::Data::Order->select_shipment($fixture->shipment_row);

    # Pick both parts
    my @container_ids = $fixture->shipment_pick_complete();

    # Deliver the GOH allocation
    Test::XTracker::Data::Order->deliver_goh_allocations($fixture->shipment_row);

    return $fixture;

}

sub integrate_goh_allocation {
    my $self = shift;
    my ($allocation_row) = @_;

    my ($container_row, $integration_process) = $self->place_goh_allocation_in_container($allocation_row);
    $self->complete_integration_container($integration_process);
    return $container_row;
}

sub place_goh_allocation_in_container {
    my $self = shift;
    my ($allocation_row) = @_;

    my ($container_row) = Test::XT::Data::Container->create_new_container_rows;
    my $integration_container = $self->schema
        ->resultset('Public::IntegrationContainer')
        ->create({
            container_id => $container_row->id,
            prl_id       => $PRL__GOH,
        });

    my $process = XT::Data::Fulfilment::GOH::Integration->new({
        $self->process_constructor_params_integration
    });
    $process->set_container( $container_row->id );

    note "Put the GOH item(s) into the container at integration";
    foreach my $goh_allocation_item_row ($allocation_row->allocation_items->all) {
        $goh_allocation_item_row->add_to_integration_container({
            integration_container => $integration_container,
        });
    }
    return ($container_row, $process);

}

sub complete_integration_container {
    my $self = shift;
    my ($integration_process) = @_;

    note 'Mark GOH Integration container as completed';
    $integration_process->mark_container_full({
        operator_id => $APPLICATION_OPERATOR_ID,
    });
}

sub induct_full_allocation {
    my $self = shift;
    my ($tote_id) = @_;

    note 'Go to induction page and induct the Full tote';
    $self->flow->flow_mech__fulfilment__induction;
    $self->flow->flow_mech__fulfilment__induction_submit(
        $tote_id->as_barcode
    );
    return $self->flow->flow_mech__fulfilment__induction_answer_submit('yes');
}

sub test_packing_when_full_not_inducted :Tests {
    my $self = shift;
    my $flow = $self->flow;

    note 'SETUP: Full+GOH allocation, GOH part integrated';
    my $fixture = $self->full_and_goh_fixture;

    my $goh_tote = $self->integrate_goh_allocation($fixture->goh_allocation_row);
    my $full_tote = $fixture->full_allocation_row->allocation_items->first->shipment_item->container;

    note 'Go to Packing and scan the GOH integration tote id';
    $flow->mech__fulfilment__set_packing_station( $fixture->shipment_row->get_channel->id );
    $flow->flow_mech__fulfilment__packing;

    note 'Error should say the Full PRL tote needs to be inducted';
    my $full_tote_id = $full_tote->id->as_id;
    $flow->catch_error(
        qr/Full\sPRL.*$full_tote_id.*induct/,
        'Tell user which tote needs induction',
        flow_mech__fulfilment__packing_submit => ( $goh_tote->id->as_barcode )
    );

    note 'Go to Packing and scan the shipment id';
    $flow->flow_mech__fulfilment__packing;

    note 'Error should say the Full PRL tote needs to be inducted';
    $flow->catch_error(
        qr/Full\sPRL.*$full_tote_id.*induct/,
        'Tell user which tote needs induction',
        flow_mech__fulfilment__packing_submit => ( $fixture->shipment_row->id )
    );

    $self->induct_full_allocation($full_tote->id);

    note 'Go to Packing and scan GOH tote again, this time no error';
    $flow->flow_mech__fulfilment__packing;
    $flow->flow_mech__fulfilment__packing_submit ( $goh_tote->id->as_barcode );

    note 'Check that Full and GOH totes are both included in list for packing';
    my $app_info_message = $flow->mech->app_info_message;
    foreach my $tote ($full_tote, $goh_tote) {
        my $tote_id = $tote->id->as_id;
        note $tote->id->as_id;

        like ($app_info_message, qr/$tote_id/, "message contains id [$tote_id]");
    }
    note $app_info_message;
}

sub test_packing_when_goh_not_integrated :Tests {
    my $self = shift;
    my $flow = $self->flow;

    note 'SETUP: Full+GOH allocation, Full part inducted, GOH still on hooks';
    my $fixture = $self->full_and_goh_fixture;

    my $full_tote = $fixture->full_allocation_row->allocation_items->first->shipment_item->container;
    my $goh_hook = $fixture->goh_allocation_row->allocation_items->first->shipment_item->container;

    $self->induct_full_allocation($full_tote->id);

    note 'Go to Packing and scan the Full tote id';
    $flow->mech__fulfilment__set_packing_station( $fixture->shipment_row->get_channel->id );
    $flow->flow_mech__fulfilment__packing;

    my $goh_hook_id = $goh_hook->id->as_id;
    note 'Error should say there is a GOH portion waiting';
    $flow->catch_error(
        qr/There is a GOH portion of this shipment that is waiting to be processed/,
        'Tell user there is a GOH portion waiting',
        flow_mech__fulfilment__packing_submit => ( $full_tote->id->as_barcode )
    );

    note 'Go to Packing and scan the shipment id';
    $flow->flow_mech__fulfilment__packing;

    note 'Error should say there is a GOH portion waiting';
    $flow->catch_error(
        qr/There is a GOH portion of this shipment that is waiting to be processed/,
        'Tell user there is a GOH portion waiting',
        flow_mech__fulfilment__packing_submit => ( $fixture->shipment_row->id )
    );

    note "Place the GOH items in a container, but don't complete it";
    my ($goh_tote, $integration_process) = $self->place_goh_allocation_in_container($fixture->goh_allocation_row);

    note 'Go to Packing and scan the Full tote id';
    $flow->mech__fulfilment__set_packing_station( $fixture->shipment_row->get_channel->id );
    $flow->flow_mech__fulfilment__packing;

    note 'Error should say there is a GOH portion waiting';
    $flow->catch_error(
        qr/There is a GOH portion of this shipment that is waiting to be processed/,
        'Tell user there is a GOH portion waiting',
        flow_mech__fulfilment__packing_submit => ( $full_tote->id->as_barcode )
    );

    note 'Go to Packing and scan the shipment id';
    $flow->flow_mech__fulfilment__packing;

    note 'Error should say there is a GOH portion waiting';
    $flow->catch_error(
        qr/There is a GOH portion of this shipment that is waiting to be processed/,
        'Tell user there is a GOH portion waiting',
        flow_mech__fulfilment__packing_submit => ( $fixture->shipment_row->id )
    );

    note 'Complete the integration container';
    $self->complete_integration_container($integration_process);

    note 'Go to Packing and scan Full tote again, this time no error';
    $flow->flow_mech__fulfilment__packing;
    $flow->flow_mech__fulfilment__packing_submit ( $full_tote->id->as_barcode );

    note 'Check that Full and GOH totes are both included in list for packing';
    my $app_info_message = $flow->mech->app_info_message;
    foreach my $tote ($full_tote, $goh_tote) {
        my $tote_id = $tote->id->as_id;
        like ($app_info_message, qr/$tote_id/, "message contains id [$tote_id]");
    }
    note $app_info_message;
}
