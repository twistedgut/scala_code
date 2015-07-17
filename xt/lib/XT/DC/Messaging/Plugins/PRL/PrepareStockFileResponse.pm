package XT::DC::Messaging::Plugins::PRL::PrepareStockFileResponse;

use strict;
use warnings;
use Data::Dumper;
use NAP::policy "tt", 'class';

use XT::JQ::DC;

=head1 NAME

XT::DC::Messaging::Consumer::Plugins::PRL::PrepareStockFileResponse -
Handle prepare_stock_file_response message from PRL

=head1 DESCRIPTION

Handle prepare_stock_file_response from PRL

=head1 METHODS

=head2 message_type

Returns the name of the message

=cut

sub message_type { 'prepare_stock_file_response' }

=head2 handler

Receives the class name, context, and pre-validated payload.

=cut

sub handler {
    my ( $self, $c, $message ) = @_;
    $c->log->debug('Received ' . $self->message_type . ' with: ' . Dumper( $message ) );

    # Get the PRL and file name from the message
    my $prl = $message->{prl};
    my $file_name = $message->{file_name};

    # Create TheSchwartz job to perform the stock reconciliation
    my $payload = { function => 'reconcile', prl => $prl, file_name => $file_name };
    my $job_rq = XT::JQ::DC->new({ funcname => 'Receive::StockControl::ReconcilePrlInventory' });
    $job_rq->set_payload( $payload );
    my $result = $job_rq->send_job();

    return;
}

1;
