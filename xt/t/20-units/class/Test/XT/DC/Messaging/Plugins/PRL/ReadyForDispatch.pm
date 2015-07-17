package Test::XT::DC::Messaging::Plugins::PRL::ReadyForDispatch;

use NAP::policy "tt", "test", "class";
use FindBin::libs;
BEGIN { # at BEGIN time to play nicely with Test::Class
    extends "NAP::Test::Class";
    with "NAP::Test::Class::PRLMQ";
};
use Test::XTracker::RunCondition prl_phase => 'prl';

=head1 NAME

Test::XT::DC::Messaging::Plugins::PRL::ReadyForDispatch - Unit tests for XT::DC::Messaging::Plugins::PRL::ReadyForDispatch

=cut

use XT::DC::Messaging::Plugins::PRL::ReadyForDispatch;
use Test::XTracker::Data;

sub handler_happy_path : Tests() {
    my $self = shift;

    # Get a box id
    my ($carton_id) = Test::XTracker::Data->get_next_shipment_box_id;

    # Send a message
    lives_ok(sub {
        $self->send_message(
            $self->create_message(
                ReadyForDispatch => {
                    container_id => $carton_id,
                }
            )
        )
    }, "message handled");

    # Nothing actually happens at the moment when XT receives this message,
    # so there's nothing else to test.

}
