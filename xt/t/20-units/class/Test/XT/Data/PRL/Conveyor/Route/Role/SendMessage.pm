package Test::XT::Data::PRL::Conveyor::Route::Role::SendMessage;
use NAP::policy "tt", "test", "class";
use FindBin::libs;
BEGIN { # at BEGIN time to play nicely with Test::Class
    extends "NAP::Test::Class";
};
use Test::XTracker::RunCondition(
    # Needs <PRL/Conveyor> config, currently only configured for DC2.
    # When configuring for other DCs, deal with the hardcoded route
    # destination values.
    dc        => 'DC2',
    prl_phase => 'prl',
);

use XTracker::Config::Local 'config_var';

use XT::Data::PRL::Conveyor::Route::ToPackingException;
use Test::XT::Data::Container;
use Test::XTracker::Artifacts::RAVNI;

use Test::XT::Fixture::Route::Container;

sub startup : Tests(startup) {
    my $self = shift;
    $self->SUPER::startup();

    # Clear any debris messages from earlier tests
    my $amq = Test::XTracker::MessageQueue->new;
    $amq->clear_destination();
}

sub test_send : Tests() {
    my $self = shift;

    # This fixture sends an 'Allocate' message when it sets up an order:
    my $fixture = Test::XT::Fixture::Route::Container->new();

    # Start checking for messages *after* fixture setup:
    my $ravni = Test::XTracker::Artifacts::RAVNI->new("xt_to_prls");

    # Send message
    my $route = XT::Data::PRL::Conveyor::Route::ToPackingException->new({
        schema       => $self->schema,
        container_id => $fixture->container_id,
    });
    my $destination = "PackLanes/pack_lane_1";
    $route->send_message($fixture->container_row->id, $destination);

    # Was message sent?
    $ravni->expect_messages({
        messages => [
            { '@type' => "route_request" },
        ],
    });
}

