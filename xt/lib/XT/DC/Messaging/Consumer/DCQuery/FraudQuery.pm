package XT::DC::Messaging::Consumer::DCQuery::FraudQuery;
use NAP::policy "tt", 'class';
use XTracker::Config::Local 'config_var';
extends 'NAP::Messaging::Base::Consumer';
with 'NAP::Messaging::Role::WithModelAccess';
use XT::DC::Messaging::Spec::DCQuery::FraudQuery;
use XT::Domain::Fraud::RemoteDCQuery;

sub routes {
    return {
        inbound_query_queue => {
            dc_fraud_query => {
                code => \&dc_fraud_query,
                spec => XT::DC::Messaging::Spec::DCQuery::FraudQuery->dc_fraud_query(),
            }
        }
    }
}

=head1 NAME

XT::DC::Messaging::Consumer::DCQuery::FraudQuery

=head1 DESCRIPTION

Consume a fraud query message

=cut

sub dc_fraud_query {
    my ( $self, $message ) = @_;

    # Dispatch the question
    try{
        my $rdc = XT::Domain::Fraud::RemoteDCQuery->new(
                    {schema => $self->model('Schema')}
                  );
        $rdc->answer($message);
    }
    catch {
        $self->log->error($_);
    };

    return 1;
}
