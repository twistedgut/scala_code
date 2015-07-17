package XTracker::Script::Dematic::LogSimReport;

use NAP::policy "tt", qw/class/;
use MooseX::Params::Validate;

extends 'XTracker::Script';

with 'XTracker::Script::Feature::SingleInstance',
     'XTracker::Script::Feature::Schema',
     'XTracker::Script::Feature::CSV',
     'XTracker::Script::Feature::Verbose';

=head1 NAME

XTracker::Script::Dematic::LogSimReport

=head1 DESCRIPTION

Generates shipments related report to be used by LogSim.

Report contains following columns:

    Order Number
    Date/Time placed
    Channel
    Premier
    SKU
    Qty
    Order SLA

=head1 SYNOPSIS

    my $report = XTracker::Script::Dematic::LogSimReport->new({
        csv_directory => '/tmp',
    });

    $report->invoke({
        date_start      => '2012-01-01',
        date_end        => '2012-10-01',
        result_filename => 'report_filename.csv',
    });

=head1 METHODS

=head2 invoke

Save LogSim report for provided start and end date (strings in Postgres date format).
Result goes into file with name provided in parameters.

=cut

sub invoke {
    my ($self, $start, $end, $result_filename) = validated_list(
        \@_,
        date_start => { isa => 'Str' },
        date_end   => { isa => 'Str' },
        result_filename => { isa => 'Str' },
    );

    $self->inform("Setup...\n");
    my $fh = $self->open_file( $result_filename );
    $self->csv->print( $fh, [qw/shipment_id date channel_id premier SKUs quantity SLA/] );


    $self->inform(sprintf "Querying shipments between %s and %s...\n", $start, $end);
    my $current_position = 0;
    my $rs = $self->fetch_shipments({date_start => $start, date_end => $end});
    my $total = $rs->count;
    foreach my $shipment ( $rs->all ) {
        $self->inform(
            "\r"x40, sprintf 'Processing: %10d out of %10d', ++$current_position, $total
        );

        $self->csv->print(
            $fh,
            [
                $shipment->id,
                $shipment->date,
                ($shipment->order ? $shipment->order->channel_id : 'N/A'),
                ($shipment->is_premier ? 'yes' : 'no'),
                $_, # SKU
                1,  # we have one line per SKU, so quantity is always 1
                $shipment->get_sla_cutoff,
            ]
        ) foreach map {$_->get_true_variant->sku} $shipment->shipment_items->all;
    }

    $self->close_file($fh);
    $self->inform(
        sprintf "\nWrote to the file: %s/%s\nDone!\n", $self->csv_directory, $result_filename
    );
}

=head2 fetch_shipments

For passed start and end dates (as string in Postgres date format) returns
arrayref of Shipment DBIC

=cut

sub fetch_shipments {
    my ($self, $start, $end) = validated_list(
        \@_,
        date_start => { isa => 'Str' },
        date_end   => { isa => 'Str' },
    );

    my $shipment_rs = $self->schema->resultset('Public::Shipment')->search({
        date => [
            -and =>
                {'>=' => $start},
                {'<'  => $end},
        ],
    },{
        order_by => 'date',
    });

    return $shipment_rs;
}
