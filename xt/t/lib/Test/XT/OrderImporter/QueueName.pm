package Test::XT::OrderImporter::QueueName;
use NAP::policy "tt", 'class';

use Test::XTracker::Data;
use Test::XTracker::MessageQueue;

# this package is intended to be used with tests scripts like
#  - t/order/10.nap-group.amq.t

sub queue_name {
    my $queue_name;

    # Should be nap|out|mrp|jc
    my $channel = shift;
    given ($channel) {
        when (m{^(?:nap|out|mrp|jc)$}) {
            # do nothing, it's sane
        }
        default {
            die qq{unexpected channel: $channel};
        }
    }

    # grab the (generated) destination
    $queue_name //= destination_name($channel);
    # strip off the annoying '/queue/'
    $queue_name =~ s{^/queue/}{};

    return $queue_name;
}

sub destination_name {
    my $destination_name;

    my $channel = shift;
    my $function;

    my $amq = Test::XTracker::MessageQueue->new;
    given($channel) {
        when (defined) {
            $function = Test::XTracker::Data->can("${channel}_channel");
        }
        default {
            die 'horribly';
        }
    }

    if (not $function) {
        die 'horribly';
    }
    $destination_name = $amq->make_queue_name( $function->('Test::XTracker::Data'), 'order' );

    return $destination_name;
}

