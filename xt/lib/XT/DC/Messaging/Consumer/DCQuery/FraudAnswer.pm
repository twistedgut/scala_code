package XT::DC::Messaging::Consumer::DCQuery::FraudAnswer;
use NAP::policy "tt", 'class';
use XTracker::Config::Local 'config_var';
extends 'NAP::Messaging::Base::Consumer';
with 'NAP::Messaging::Role::WithModelAccess';
use XT::DC::Messaging::Spec::DCQuery::FraudAnswer;
use XT::Domain::Fraud::RemoteDCQuery;

=head1 NAME

XT::DC::Messaging::Consumer::DCQuery::FraudAnswer

=head1 DESCRIPTION

Consume a fraud query answer message

=cut

sub routes {
    return {
        inbound_answer_queue => {
            dc_fraud_answer => {
                code => \&dc_fraud_answer,
                spec => XT::DC::Messaging::Spec::DCQuery::FraudAnswer->dc_fraud_answer(),
            }
        }
    }
}

sub dc_fraud_answer {
    my ( $self, $message ) = @_;

    my $schema  = $self->model('Schema');
    my $rdc = XT::Domain::Fraud::RemoteDCQuery->new({schema => $schema});

    # Process the answer
    try{
        # Match the message query_id to a single db row
        my $rquery = $schema->resultset('Public::RemoteDcQuery')
                            ->search({ id => $message->{'query_id'}})
                            ->first;

        if(defined $rquery){
            # The query matches a local record.
            if(!$rquery->processed){
                # It's unprocessed - mark query reference as done
                $rquery->update({ processed => 1 });

                # Dispatch to response method
                if($message->{answer}){
                    $self->log->warn('Remote query ok - positive response: '
                                   . $message->{'query_id'});
                    $rdc->positive_action($rquery->query_type, $rquery->orders_id);
                }
                else {
                    $self->log->warn('Remote query not ok - negative response:'
                                   . $message->{'query_id'});
                    $rdc->negative_action($rquery->query_type, $rquery->orders_id);
                }
            }
            else {
                # The record exists but has been previously processed. This is
                # potentially fraudulent so put the order back on credit hold
                $self->log->warn('Remote query ref previously processed - possible fraud:'
                               . $message->{'query_id'});
                $rdc->bogus_action($rquery->query_type, $rquery->orders_id);
            }
        }
        else{
            # The query doesn't match anything - also possibly fraudulent but
            # we have no order so just log it
            $self->log->warn('Remote query ref not found - possible fraud: '
                           . $message->{'query_id'});
        }
    }
    catch {
        $self->log->error($_);
    };

    return 1;
}
