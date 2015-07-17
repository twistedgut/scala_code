package XT::JQ::DC::Receive::Customer::CustomerValue;

use Moose;

use MooseX::Types::Moose        qw( Str Int Maybe ArrayRef );
use MooseX::Types::Structured    qw( Dict Optional );

use XTracker::Logfile           qw( xt_logger );


use Try::Tiny;

use namespace::clean -except => 'meta';

extends 'XT::JQ::Worker';


has payload => (
    is => 'ro',
    isa => Dict[
        customer_number => Int,     # public facing Customer Number
        channel_id      => Int,
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

    my $customer_nr = $self->payload->{customer_number};
    my $channel_id  = $self->payload->{channel_id};


    try {
        $schema->txn_do( sub {
            my $customer   = $schema->resultset('Public::Customer')->find( {
                is_customer_number => $customer_nr,
                channel_id         => $channel_id,
            } );

            if ( !$customer ) {
                die "Couldn't Find Customer: '${customer_nr}' for Channel: '${channel_id}'\n";
            }

            # send customer_vaue to seaview
            $customer->update_customer_value_in_service();
        });

    }
    catch {
        $error = $_;
        $self->logger->error( qq{Failed CustomerValue job with error: $error} );
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

XT::JQ::DC::Receive::Order::CustomerValue

=head1 DESCRIPTION

Expected Payload should look like:

    my $job_payload    = {
        customer_number => $customer_number,    # Customer Number
        channel_id      => $channel_id,         # the customer's Sales Channel Id
    };

=cut
