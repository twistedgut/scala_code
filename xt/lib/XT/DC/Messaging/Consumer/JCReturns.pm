package XT::DC::Messaging::Consumer::JCReturns;
use NAP::policy "tt", 'class';
extends 'XT::DC::Messaging::ConsumerBase::Returns';

use XTracker::Config::Local qw/config_var/;

use JSON::XS;

sub routes {
    return {
        destination => XT::DC::Messaging::ConsumerBase::Returns->base_route,
    };
}


sub process_failure {
    my ($self, $message, $headers, $e) = @_;

    $e //= 'Unknown_reason_for_failure';
    $self->log->warn( 'Returns failed to process; ' . ( ref( $e ) eq 'ARRAY' ? join( ' ', @{ $e } ) : $e ) );


    # push a message straight onto a/the DLQ
    $self->model('MessageQueue')->transform_and_send(
         'XT::DC::Messaging::Producer::Return::RequestError::JC',
        {
            original_message => $message,
            errors           => $e ,
        }
    );
    $self->log->info( 'Return (failure) status update sent' );
    return;
}

=head1 SEE ALSO

L<XT::DC::Messaging::ConsumerBase::Returns> for all of the implementation

=cut

