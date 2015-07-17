package XT::DC::Messaging::Producer::DCQuery::FraudAnswer;
use NAP::policy "tt", 'class';
with 'XT::DC::Messaging::Role::Producer';
use XT::DC::Messaging::Spec::DCQuery::FraudAnswer;

=head1 NAME

XT::DC::Messaging::Producer::DCQuery::FraudAnswer

=head1 DESCRIPTION

Producer for remote DC responses to fraud related queries

=cut

sub message_spec { return XT::DC::Messaging::Spec::DCQuery::FraudAnswer->dc_fraud_answer() }

has '+type' => ( default => 'dc_fraud_answer' );
has '+destination' => ( default => 'outbound_answer_queue' );

sub transform {
    my ($self, $header, $data) = @_;

    # Return the message.
    return ( $header, { %$data } );
}
