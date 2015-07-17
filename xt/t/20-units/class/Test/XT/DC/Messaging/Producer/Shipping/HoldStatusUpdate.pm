package Test::XT::DC::Messaging::Producer::Shipping::HoldStatusUpdate;
use NAP::policy "tt", 'class', 'test';

BEGIN {
    extends 'NAP::Test::Class';
};

use Test::XTracker::Data;
use Test::XTracker::MessageQueue;
use Test::MockObject;
use Test::XT::Data::Container;

=head1 NAME

Test::XT::DC::Messaging::Producer::Shipment::HoldStatusUpdate

Tests the messages being sent to mercury for shipment status updates.

=head1 DESCRIPTION

Tries to send a Shipment Update message and check actual message content.

=head1 SYNOPSIS

    # Run all tests
    prove t/20-units/class/Test/XT/DC/Messaging/Producer/Shipment/HoldStatusUpdate.pm

=cut


sub test__transform :Tests {
    my ($self) = @_;
    my $message_queue = Test::XTracker::MessageQueue->new();

    isa_ok($message_queue, 'Test::XTracker::MessageQueue');

    my $msg_type = 'XT::DC::Messaging::Producer::Shipping::HoldStatusUpdate';

    my $shipment_update = $self->_create_mock_status_update();


    #Clear the queue before starting the test
    $message_queue->clear_destination();

    #make sure there aren't any messages in the queue
    $message_queue->assert_messages({
        assert_count => 0
    });

    lives_ok { $message_queue->transform_and_send($msg_type, $shipment_update)};

    $message_queue->assert_messages({
        destination     => '/topic/shipment_updates',
        assert_count    => 1,
        assert_header   => superhashof({type => 'shipment_hold_status_info'}),
        assert_body     => superhashof({shipment_id     => '100',
                                        order_number    => '200',
                                        shipment_status => 'HOLD',
                                        brand           => 'NAP',
                                        region          => 'INTL',
                                        hold_reason     => 'INVALID_PAYMENT',
                                        comment         => 'We don\'t currently accept Dogecoin' })
    });
}

sub _create_mock_status_update {
    my $self = @_;

    my $export_ok_data = {
        shipment_id     => "100",
        order_number    => "200",
        shipment_status => "HOLD",
        brand           => "NAP",
        region          => "INTL",
        hold_reason     => 'INVALID_PAYMENT',
        comment         => 'We don\'t currently accept Dogecoin'
   };

    return $export_ok_data;
}
