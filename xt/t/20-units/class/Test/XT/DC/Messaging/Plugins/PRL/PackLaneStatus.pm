package Test::XT::DC::Messaging::Plugins::PRL::PackLaneStatus;

use NAP::policy "tt", "test", "class";
use FindBin::libs;
BEGIN { # at BEGIN time to play nicely with Test::Class
    extends "NAP::Test::Class";
    with "NAP::Test::Class::PRLMQ";
};

use Test::XTracker::RunCondition prl_phase => 'prl';
use Test::XTracker::Data;

use Test::XTracker::Data::PackRouteTests;

sub startup :Tests(startup) {
    my $self = shift;

    $self->SUPER::startup;
    my $plt = Test::XTracker::Data::PackRouteTests->new;

    $plt->reset_and_apply_config($plt->like_live_packlane_configuration());

}

# Test receiving a pack_lane_status message
sub consume_pack_lane_status : Tests() {
    my $test = shift;

    ok( my $packlane = $test->schema->resultset('Public::PackLane')->first,
        "get a pack lane" );
    note "Will update the count for pack lane " . $packlane->human_name;
    $packlane->update( { container_count => 0 } );

    # Create a message and send
    my $newcount = 37;
    ok(my $template = $test->message_template( PackLaneStatus => {
          spur            => $packlane->status_identifier,
          count           => 37,
          date_time_stamp => '2013-02-05T17:43:00+0000',
          prl             => 'Dematic',
    }), "create pack_lane_status message");

    my $message = $template->();
    note "Send the message";
    $test->send_message($message);

    # Ensure messsage processed correctly
    $packlane->discard_changes;
    is( $packlane->container_count, $newcount, 'container_count updated correctly in DB' );
}
