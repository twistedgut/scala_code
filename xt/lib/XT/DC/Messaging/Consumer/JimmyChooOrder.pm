package XT::DC::Messaging::Consumer::JimmyChooOrder;
use NAP::policy "tt", 'class';

use XTracker::Config::Local qw( config_var );
use XTracker::Utilities     qw( summarise_stack_trace_error );

use JSON::XS; # for the nice bools
use Data::Dumper; # for 'message' dumps
use DateTime;

extends 'XT::DC::Messaging::ConsumerBase::Order';

sub process_success {
    my ($self, $message, $header) = @_;

    my $duplicate   = delete $message->{duplicate};

    $message    = _get_order_if_in_array( $message );
    my $o_id    = $message->{o_id} // 'COULD_NOT_FIND_ORDER_NUMBER';

    $self->log->info( 'order ' . $o_id . ' processed successfully' );

    # Send to ActiveMQ.
    $self->model('MessageQueue')->transform_and_send(
        'XT::DC::Messaging::Producer::Order::ImportStatus',
        {
            # used by the website / consumer to update order status
            o_id            => $o_id,
            successful      => JSON::XS::true,
            datetime        => DateTime->now( time_zone => 'local' )->datetime(),

            # used by us to determine where to send the response
            message         => $message,
            duplicate       => ( $duplicate ? JSON::XS::true : JSON::XS::false ),
        }
    );
    $self->log->info( 'order ' . $o_id . ' (success) status update sent' );

    return;
}

sub process_failure {
    my ($self, $message, $header, $err) = @_;

    $message    = _get_order_if_in_array( $message );
    my $o_id    = $message->{o_id} // 'COULD_NOT_FIND_ORDER_NUMBER';

    $self->log->warn( 'order ' . $o_id . ' failed to process; ' .  ($err//'unknown_reason_for_failure') );

    my $msg_summary = summarise_stack_trace_error( $err );

    # send response to website
    $self->model('MessageQueue')->transform_and_send(
        'XT::DC::Messaging::Producer::Order::ImportStatus',
        {
            # used by the website / consumer to update order status
            o_id            => $o_id,
            successful      => JSON::XS::false,

            # used by us to determine where to send the response
            message         => $message,
            datetime        => DateTime->now( time_zone => 'local' )->datetime(),

            # used by the poor sod trying to work out what went wrong
            error => {
                original => $err,
                summary  => $msg_summary,
                message  => Data::Dump::pp($message),
            }
        }
    );

    # push a message straight onto a/the DLQ
    $self->model('MessageQueue')->transform_and_send(
        'XT::DC::Messaging::Producer::Order::ImportError',
        {
            original_message => $message,
            errors           => [ $err ],
        }
    );
    $self->log->info( 'order ' . $o_id . ' (failure) status update sent' );

    return;
}

# return back the first element of the 'orders'
# array if indeed it exists and is an array
sub _get_order_if_in_array {
    my $message = shift;
    if ( exists( $message->{orders} ) && ref( $message->{orders} ) eq 'ARRAY' ) {
        $message    = shift @{ $message->{orders} };
    }
    return $message;
}

__END__

=head1 SEE ALSO

L<XT::DC::Messaging::ConsumerBase::Order> for all of the implementation

=cut
