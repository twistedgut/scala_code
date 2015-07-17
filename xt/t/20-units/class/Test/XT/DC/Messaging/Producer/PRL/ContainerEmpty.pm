package Test::XT::DC::Messaging::Producer::PRL::ContainerEmpty;

use FindBin::libs;
use NAP::policy "tt", 'test', 'class';

BEGIN {
    extends "NAP::Test::Class";
}

use Test::XT::Data::Container;
use XT::DC::Messaging::Producer::PRL::ContainerEmpty;
use XTracker::Constants qw/:prl_type/;

=head1 NAME

Test::NAP::MQ::ActiveMQ::Producer::PRL::ContainerEmpty - Unit tests for
NAP::MQ::ActiveMQ::Producer::PRL::ContainerEmpty

=cut

sub send_message_to_more_then_one_queue :Tests() {
    my ($test) = @_;

    my $amq = Test::XTracker::MessageQueue->new;

    my ($container) = Test::XT::Data::Container->create_new_container_rows;

    $amq->clear_destination("queue/test.$_") for 1, 2;

    lives_ok{
        $amq->transform_and_send(
            'XT::DC::Messaging::Producer::PRL::ContainerEmpty' => {
                container => $container,
                destinations => ['queue/test.1', 'queue/test.2']
            }
        );
    } 'Send one ContainerEmpty message to two destinations';

    # check that each queue got a message
    foreach (1, 2) {
        $amq->assert_messages({
            destination => "queue/test.$_",
            assert_count => 1,
        },
        "test.$_ got a message",
        );
    }

    # Check message is correct
    $amq->assert_messages({
       destination   => 'queue/test.1',
       assert_header => superhashof({ type => 'container_empty' }),
       # Note: Force stringification of container id
       assert_body   => superhashof({ container_id => $container->id .'' }),
    } , 'Message content is correct',
    );

    # Get the two messages
    my ($msg1) = $amq->messages('queue/test.1');
    my ($msg2) = $amq->messages('queue/test.2');

    is_deeply(
        $amq->deserializer->($msg1->body),
        $amq->deserializer->($msg2->body),
        'Messages from both queues have same content'
    );

    # clean up
    $amq->clear_destination("queue/test.$_") for 1, 2;
}

sub send_message_to_one_queue :Tests() {
    my ($test) = @_;

    my $amq = Test::XTracker::MessageQueue->new;

    my ($container) = Test::XT::Data::Container->create_new_container_rows;

    $amq->clear_destination("queue/test.3");

    lives_ok{
        $amq->transform_and_send('XT::DC::Messaging::Producer::PRL::ContainerEmpty' => {
            container => $container,
            destinations => 'queue/test.3'
        });
    } 'Send one ContainerEmpty message to one destinations';

    $amq->assert_messages({
            destination => "queue/test.3",
            assert_count => 1,
        },
        "test.3 got a message",
    );

    # Check message is correct
    $amq->assert_messages({
            destination   => 'queue/test.3',
            assert_header => superhashof({ type => 'container_empty' }),
            # Note: Force stringification of container id
            assert_body   => superhashof({ container_id => $container->id . ''}),
        } , 'Message content is correct',
    );

    # clean up
    $amq->clear_destination("queue/test.3");
}

