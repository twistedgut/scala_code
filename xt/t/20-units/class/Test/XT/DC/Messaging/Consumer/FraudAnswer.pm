package Test::XT::DC::Messaging::Consumer::FraudAnswer;

use NAP::policy "tt", 'test';
use parent "NAP::Test::Class";

=head1 NAME

Test::XT::DC::Messaging::Consumer::FraudAnswer

=head1 DESCRIPTION

Simple test to check the remote DC fraud answer can be consumed

=cut

use JSON;

use Test::XTracker::Data;
use Test::XTracker::MessageQueue;

sub startup : Test( startup => 1 ) {
    my $self = shift;
    $self->SUPER::startup;

    ($self->{amq}, $self->{consumer}) = Test::XTracker::MessageQueue->new_with_app;
    $self->{inbound} = Test::XTracker::Config->messaging_config->{'Consumer::DCQuery::FraudAnswer'}{routes_map}{inbound_answer_queue};
    $self->{schema} = Test::XTracker::Data->get_schema;
}

sub setup: Test(setup) {
    my $self = shift;
    $self->SUPER::setup;
    $self->{amq}->clear_destination( $self->{inbound} );
}

sub teardown: Test(teardown) {
    my $self    = shift;
    $self->SUPER::teardown;
    $self->{amq}->clear_destination( $self->{inbound} );
}

=head1 TEST METHODS

=head2 test_fraud_query

=cut

sub test_fraud_answer : Tests() {
    my $self = shift;

    # Send a fraud answer to the consumer we're testing
    my $result = $self->{amq}->request(
        $self->{consumer},
        $self->{inbound},
        { query_id => 1,
          answer => JSON::false,
        },
        { type => 'dc_fraud_answer',}
    );

    ok($result->is_success, 'Answer message is consumed');
}

