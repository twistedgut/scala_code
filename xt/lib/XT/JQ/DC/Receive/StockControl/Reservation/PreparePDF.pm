package XT::JQ::DC::Receive::StockControl::Reservation::PreparePDF;

use Moose;

use Data::Dump qw/pp/;
use XTracker::Stock::Reservation::Overview;
use XTracker::Logfile qw( xt_logger );

use MooseX::Types::Moose qw( Str Int Maybe ArrayRef );
use MooseX::Types::Structured qw( Dict Optional );


use namespace::clean -except => 'meta';

extends 'XT::JQ::Worker';

has payload => (
    is => 'ro',
    isa => Dict[
        channel_name    => Str,
        channel_id      => Int,
        output_filename => Str,
        upload_date     => Str,
        current_user    => Int,
        filter          => Optional[
            Dict[
                exclude_designer_ids=> Optional[ArrayRef[Int]],
                exclude_pids        => Optional[ArrayRef[Int]],
            ],
        ],
    ],
    required => 1
);

has logger => (
    is => 'rw',
    default => sub { return xt_logger('XT::JQ::DC'); }
);


sub do_the_task {
    my ($self, $job) = @_;
    my $error = "";

    eval {
        $self->logger->info("Preparing " . $self->payload->{output_filename});
        XTracker::Stock::Reservation::Overview::prepare_pdf_template( $self );
    };
    if (my $e=$@) {
        warn(
            $self->payload->{output_filename}
                . ': '
                . $e
            );
        $error = $e;
    }

    $self->logger->info("Completed " . $self->payload->{output_filename});
    return ($error);
}

sub check_job_payload {
    my ($self, $job) = @_;
    return ();
}

1;

__END__

=head1 NAME

XT::JQ::DC::DC::StockControl::Reservation::PreparePDF

=head1 DESCRIPTION

Expected Payload should look like:

    my $job_payload = {
       channel_id      => $channel_id,
       output_filename => $pdf_filename,
       upload_date     => $upload_date,
       current_user    => $handler->operator_id,
    };

=cut
