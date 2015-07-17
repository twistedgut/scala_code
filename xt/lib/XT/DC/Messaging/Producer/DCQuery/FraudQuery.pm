package XT::DC::Messaging::Producer::DCQuery::FraudQuery;
use NAP::policy "tt", 'class';
with 'XT::DC::Messaging::Role::Producer';
use XT::DC::Messaging::Spec::DCQuery::FraudQuery;

=head1 NAME

XT::DC::Messaging::Producer::DCQuery::FraudQuery

=head1 DESCRIPTION

Producer for remote DC queries related to orders on credit hold

=cut


sub message_spec { return XT::DC::Messaging::Spec::DCQuery::FraudQuery->dc_fraud_query() }

has '+type' => ( default => 'dc_fraud_query' );
has '+destination' => ( default => 'outbound_query_queue' );

sub transform {
    my ($self, $header, $data) = @_;

    # Return the message.
    return ( $header, { %$data } );
}
