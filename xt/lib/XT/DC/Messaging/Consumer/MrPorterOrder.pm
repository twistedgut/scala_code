package XT::DC::Messaging::Consumer::MrPorterOrder;
use NAP::policy "tt", 'class';

use XTracker::Config::Local qw/config_var/;

use JSON::XS; # for the nice bools
use Data::Dumper; # for 'message' dumps

extends 'XT::DC::Messaging::ConsumerBase::Order';

sub process_success {
    my ($self, $message, $headers) = @_;
    $self->log->info( 'order ' . $message->{o_id} . ' processed successfully' );

    # Send to ActiveMQ.
    $self->model('MessageQueue')->transform_and_send(
        'XT::DC::Messaging::Producer::Order::ImportStatus',
        {
            # used by the website / consumer to update order status
            o_id            => $message->{o_id} // 'MISSING-ORDER-ID',
            successful      => JSON::XS::true,

            # used by us to determine where to send the response
            message         => $message,
        }
    );
    $self->log->info( 'order ' . $message->{o_id} . ' (success) status update sent' );
}

sub _error_summary {
    my $e = shift;
    # grab output up to (but not including 'at /path/to/module.pm line 667'
    my $re = qr{\A(.*?)\s+at\s+[^\s]+\s+line\s+\d+};
    # build the summary
    my $summary = $e;
    $summary =~ s{${re}.*}{$1}ms;

    return $summary;
}

sub process_failure {
    my ($self, $message, $headers, $e) = @_;
    $self->log->warn( 'order ' . $message->{o_id} . ' failed to process; ' .  ($e//'unknown_reason_for_failure') );

    my $summary = _error_summary($e);

    # send response to website
    $self->model('MessageQueue')->transform_and_send(
        'XT::DC::Messaging::Producer::Order::ImportStatus',
        {
            # used by the website / consumer to update order status
            o_id            => $message->{o_id} // 'MISSING-ORDER-ID',
            successful      => JSON::XS::false,

            # used by us to determine where to send the response
            message         => $message,

            # used by the poor sod trying to work out what went wrong
            error => {
                original => $e,
                summary  => $summary,
                message  => Data::Dump::pp($message),
            }
        }
    );

    # push a message straight onto a/the DLQ
    $self->model('MessageQueue')->transform_and_send(
        'XT::DC::Messaging::Producer::Order::ImportError',
        {
            original_message => $message,
            errors           => [ $e ],
        }
    );
    $self->log->info( 'order ' . $message->{o_id} . ' (failure) status update sent' );
}

# vim: ts=8 sts=4 et sw=4 sr sta
__END__

=head1 SEE ALSO

L<XT::DC::Messaging::ConsumerBase::Order> for all of the implementation

=cut
