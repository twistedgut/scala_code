package XT::JQ::DC::Receive::Order::ApplyFraudRules;

use Moose;

use MooseX::Types::Moose        qw( Str Int Maybe ArrayRef );
use MooseX::Types::Structured    qw( Dict Optional );

use XTracker::Logfile           qw( xt_logger );

use XT::FraudRules::Type;
use XT::FraudRules::Engine;

use XT::Cache::Function         qw( :stop );

use Try::Tiny;

use Benchmark       qw( :hireswallclock );

use namespace::clean -except => 'meta';


extends 'XT::JQ::Worker';


has payload => (
    is => 'ro',
    isa => Dict[
        order_number    => Str,     # public facing Order Number
        channel_id      => Int,
        mode            => 'XT::FraudRules::Type::JQMode',
    ],
    required => 1,
);

has logger => (
    is => 'rw',
    default => sub { return xt_logger('XT::JQ::DC'); }
);


sub do_the_task {
    my ($self, $job) = @_;
    my $error    = "";

    my $schema = $self->schema;

    my $order_nr    = $self->payload->{order_number};
    my $channel_id  = $self->payload->{channel_id};

    my $benchmark_log   = xt_logger('Benchmark');

    try {
        $schema->txn_do( sub {
            my $order   = $schema->resultset('Public::Orders')->find( {
                order_nr    => $order_nr,
                channel_id  => $channel_id,
            } );

            if ( !$order ) {
                die "Couldn't Find Order: '${order_nr}' for Channel: '${channel_id}'\n";
            }

            # only call the Engine if the Order is in the correct
            # Status and doesn't already have an Outcome record
            if ( ( $order->is_on_credit_hold || $order->is_accepted )
               && !$order->orders_rule_outcome ) {

                my $t0  = Benchmark->new;
                my $engine  = XT::FraudRules::Engine->new( {
                    order   => $order,
                    mode    => $self->payload->{mode},
                } );
                my $t1  = Benchmark->new;
                $engine->apply_finance_flags;
                my $t2  = Benchmark->new;
                $engine->apply_rules;
                my $t3  = Benchmark->new;

                # log the Benchmarking
                my $log_prefix  = "JQ, Fraud Rules - Channel Id: ${channel_id}, Order Nr: ${order_nr} - BENCHMARK - CONRAD";
                $benchmark_log->info( "${log_prefix}, to Instantiate - '" . timestr( timediff( $t1, $t0 ), 'all' ) . "'" );
                $benchmark_log->info( "${log_prefix}, to Apply Flags - '" . timestr( timediff( $t2, $t1 ), 'all' ) . "'" );
                $benchmark_log->info( "${log_prefix}, to Apply Rules - '" . timestr( timediff( $t3, $t2 ), 'all' ) . "'" );
                $benchmark_log->info( "${log_prefix}, Total Time     = '" . timestr( timediff( $t3, $t0 ), 'all' ) . "'" );
            }
            else {
                # work out the reason why
                my $reason  = (
                    ( !$order->is_on_credit_hold && !$order->is_accepted )
                    ? "Order in Incorrect Status: '" . $order->order_status->status . "'"
                    : "Order already has an 'orders_rule_outcome' record"
                );
                $self->logger->error( "Can't Run Fraud Rules Engine! " .
                                      "Channel: '${channel_id}', Order: '${order_nr}' - " .
                                      $reason );
            }
        } );

        # clear the Cache so that stuff like the Fraud Hotlist
        # doesn't persist, this is in lieu of Cache Expiration
        stop_all_caching();
    }
    catch {
        $error = $_;
        $self->logger->error( qq{Failed job with error: $error} );
        $job->failed( $error );
    };

    return;
}

sub check_job_payload {
    my ($self, $job) = @_;
    return ();
}


1;

__END__

=head1 NAME

XT::JQ::DC::Receive::Order::ApplyFraudRules

=head1 DESCRIPTION

Expected Payload should look like:

    my $job_payload    = {
        order_number    => $order_number,       # Public Facing Order Number
        channel_id      => $channel_id,         # the Order's Sales Channel Id
        mode            => 'parallel',          # Mode to run the Fraud Rules Engine in
    };

=cut
