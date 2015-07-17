package Test::XT::DC::Messaging::Producer::DCQuery::FraudQuery;

use NAP::policy "tt", 'test';

use parent "NAP::Test::Class";
use Test::XTracker::Data;
use XTracker::Config::Local qw( config_var );

use Data::UUID;
use XT::DC::Messaging::Producer::DCQuery::FraudQuery;

=head1 NAME

Test::XT::DC::Messaging::Producer::DCQuery::FraudQuery

=head1 DESCRIPTION

Sends a fraud query message

=cut

sub send_message : Tests {
    my $self = shift;

    my $amq = Test::XTracker::MessageQueue->new;

    my $queue = config_var('Producer::DCQuery::FraudQuery','routes_map')
        ->{outbound_query_queue};

    my $body = {
        account_urn => 'urn:nap:account:test',
        query_id    => Data::UUID->new()->create_str(),
        query       => 'CustomerHasGenuineOrderHistory?',
    };

    $amq->clear_destination($queue);

    lives_ok{
        $amq->transform_and_send(
            'XT::DC::Messaging::Producer::DCQuery::FraudQuery' => $body,
        );
    } 'Try to send one fraud query';

    $amq->assert_messages({
        destination => $queue,
        assert_header => superhashof({
            type => 'dc_fraud_query',
        }),
        assert_body => superhashof($body),
    },'message sent correctly');
}
