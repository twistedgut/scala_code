package Test::XT::DC::Messaging::Producer::PRL::RouteRequest;

# some of this code was inspired by Test::XTracker::AllocateManager

# NOTE: Be aware of the difference between the message destination (a queue name),
#   and the container destination (a field in the message).

use NAP::policy "tt", "test", "class";
use FindBin::libs;
BEGIN { # at BEGIN time to play nicely with Test::Class
    extends "NAP::Test::Class";
    with "NAP::Test::Class::PRLMQ";
};
use Test::XTracker::RunCondition(
    # Needs <PRL/Conveyor> config, currently only configured for DC2.
    # When configuring for other DCs, deal with the hardcoded route
    # destination values.
    dc        => "DC2",
    prl_phase => "prl",
);

use NAP::DC::Barcode::Container;
use XTracker::Config::Local 'config_var';
use XTracker::Constants::FromDB qw/
    :container_status
/;
use XT::DC::Messaging::Producer::PRL::RouteRequest;

use Test::XTracker::MessageQueue;

BEGIN {

has amq => (
    is      => 'ro',
    default => sub {
        Test::XTracker::MessageQueue->new()
    },
);

};

sub send_route_request__simple : Tests {
    my ($self) = @_;

    # setup
    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        how_many => 1,
        status   => $PUBLIC_CONTAINER_STATUS__AVAILABLE,
    });
    my $container_destination_name = 'PackingOperations/packing_exception';
    my $container_destination_id   = "DA.DP01.0000.DS02";

    my $message_destination = config_var('PRL', 'conveyor_queue')
        or fail("Could not find queue in config");

    $self->amq->clear_destination($message_destination);

    # Get ID of last message
    my $message_id = $self->schema->resultset('Public::ActivemqMessage')->get_column('id')->max;

    lives_ok{
        $self->amq->transform_and_send(
            'XT::DC::Messaging::Producer::PRL::RouteRequest' => {
                container_id          => $container_id,
                container_destination => $container_destination_name,
            }
        );
    } 'Sent a RouteRequest message.';

    # Check for new entry in message log
    my $logged_message = $message_id
        ? $self->schema->resultset('Public::ActivemqMessage')->find( ++$message_id ) # there are previous entries
        : $self->schema->resultset('Public::ActivemqMessage')->first; # this will be the first entry
    ok( $logged_message, 'Message was logged' );
    is( $logged_message->entity_id, $container_id, 'Entity ID was logged' );
    like( $logged_message->content, qr/$container_id/, 'Container ID within message logged correctly' );
    unlike( $logged_message->content, qr/:null,/, 'No null fields in logged message' );
    is( $logged_message->message_type,
        'route_request',
        'Message type logged correctly' );

    $self->amq->assert_messages({
        destination => $message_destination,
        assert_header => superhashof({
            type => 'route_request',
        }),
        assert_body => superhashof({
            container_id => "$container_id",
            destination  => "$container_destination_id",
        }),
    }, 'Check that data structure in sent message is the same as expected.' );

    # clean up
    #$self->amq->clear_destination($message_destination);
}

sub send_route_request__fail_on_bad_destination : Tests {
    my ($self) = @_;

    my ($container_id) = NAP::DC::Barcode::Container->new_from_id("M123");
    my $container_destination_name = 'missing/destination';
    throws_ok(
        sub {
            $self->amq->transform_and_send(
                'XT::DC::Messaging::Producer::PRL::RouteRequest' => {
                    container_id          => $container_id,
                    container_destination => $container_destination_name,
                }
            );
        },
        qr|^\QMissing config value (/PRL/Conveyor/Destinations/missing/destination)|,
        'RouteRequest fails on bad route destination.'
    );
}

sub missing_parameters : Tests {
    my ($self) = @_;

    throws_ok(
        sub {
            $self->amq->transform_and_send( 'XT::DC::Messaging::Producer::PRL::RouteRequest' => { } )
        },
        qr/parameters .+ missing/,
        'Error thrown if required parameters are missing'
    );
}

1;
