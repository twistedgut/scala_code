package XTracker::DHLDeliveryTimes::FFSTATParser;

use NAP::policy 'tt', 'class';
with 'XTracker::Role::WithSchema';

use XTracker::DHLDeliveryTimes::SFTPMonitor;
use XTracker::Config::Local 'config_var';
use XTracker::Logfile 'xt_logger';
use Text::CSV_XS;
use List::MoreUtils 'any';
use DateTime;
use DateTime::Format::Strptime;
use Const::Fast;
use XTracker::Constants::FromDB ':shipment_status';
use XTracker::Constants '$APPLICATION_OPERATOR_ID';

=head1 FFSTATParser

Parses FFSTAT format files from DHL that contain information
about the times that shipments were delivered at.

FFSTAT files are pipe delimited CSV files containing information
about when deliveries were made. Documentation is available here
and also from Warehouse BA:
https://gitosis/cgit/docs-specifications/plain/backend/DHL/MIG_FFTIN_Document_ver3_0.pdf

=cut

has 'sftp_monitor' => (
    is => 'rw',
    isa => 'XTracker::DHLDeliveryTimes::SFTPMonitor',
    default => sub {
        return XTracker::DHLDeliveryTimes::SFTPMonitor->new();
    }
);

=head2 process_files

    1. Looks in the database to see what files on the DHL server we need to process
    2. Choose One
    3. Download it if necesary
    4. Process it
    5. Goto 1 or return if no more work.

=cut

sub process_files {
    my $self = shift;

    my $rs = $self->schema->resultset('Public::DHLDeliveryFile');

    while (my $file = $rs->get_next_file_to_process()) {

        try {

            $self->sftp_monitor->download_file($file)
                if (!$file->file_exists_locally());

            $self->process_file($file);
            $file->mark_as_processed_ok();
        } catch {
            xt_logger->warn(sprintf("Failed to process file. (filename=%s,error=%s",
                $file->filename,
                $_
            ));
            $file->mark_as_failed();
        };

        $file->delete_file();
    }

    xt_logger->info("No more DHL Delivery files to process"); # make the output more consistent
}

=head2 process_file

Given a Pipe delimited FFSTAT version 1 CSV File containing DHL information already downloaded to
the disk, open it up and process it line by line. Leave the actual row interpretation to another
more specialised function.

=cut

sub process_file {
    my ($self, $file) = @_;

    xt_logger->info("Performing CSV Import of ". $file->filename ."\n");

    my $abs_local_file = $file->get_absolute_local_filename();

    my $fh = IO::File->new($abs_local_file, 'r')
        || die(sprintf("Cant process CSV file: (filename=%s,error=%s)",
            $abs_local_file,
            $!
        )
    );

    my $csv = Text::CSV_XS->new({
        binary => 1,
        eol => "\n",
        sep_char => '|'
    });

    while (my $row = $csv->getline($fh)) {
        $self->process_row($row);
    }

    $fh->close();
}

const my $ROW_REC_TYPE               => 0;
const my $ROW_DHL_STATUS_CODE        => 2;
const my $ROW_ORDER_NR               => 9;
const my $ROW_AIR_WAYBILL            => 10;
const my $ROW_EVENT_LOCAL_TIMESTAMP  => 11;
const my $ROW_EVENT_LOCAL_UTC_OFFSET => 12;

=head2 process_row

This function understands the format of the FFSTAT file. E.g. what columns
we care about and what they mean. specialised mapping functions are relied upon
to convert the data from it's FFSTAT format into NAP specific types which are
then handed off to update_shipment_status_log.

=cut

sub process_row {
    my ($self, $row) = @_;

    if ($row->[$ROW_REC_TYPE] eq 'H') {
        $self->process_header_row($row);
        return;
    } elsif ($row->[$ROW_REC_TYPE] eq 'T') {   # trailer row record
        return;
    } elsif ($row->[$ROW_REC_TYPE] ne 'D') {
        xt_logger->warn("CSV File Parser only knows about H, T and D record types. skipping encountered: ". $row->[$ROW_REC_TYPE]);
        return;
    }

    my $dhl_status = $row->[$ROW_DHL_STATUS_CODE];
    my $order_nr = $row->[$ROW_ORDER_NR];
    my $air_waybill = $row->[$ROW_AIR_WAYBILL];
    my $event_timestamp = $self->_expand_timestamp_str(
        $row->[$ROW_EVENT_LOCAL_TIMESTAMP],
        $row->[$ROW_EVENT_LOCAL_UTC_OFFSET]
    );

    $self->update_shipment_status_log(
        $order_nr,
        $dhl_status,
        $air_waybill,
        $event_timestamp
    );

}

=head2 process_header_row

When processing a header row we hand off the work to this function
in order to minimise complexity elsewhere. This just validates one
or two special fields to ensure sanity.

=cut

const my $HROW_MSG_TYPE => 1;
const my $HROW_MSG_VER  => 2;

sub process_header_row {
    my ($self, $row) = @_;

    if ($row->[$HROW_MSG_TYPE] ne 'FFSTAT') {
        die("CSV Parser expected FFSTAT file. This file will be skipped");
    };

    # throw a warning if they upgrade the version of the spec they put out
    # so can get this system retested against and look at the specs to see
    # what's changed.
    if ($row->[$HROW_MSG_VER] != 1) {
        xt_logger->warn("CSV Parser was written for FFSTAT file version 1. This CSV file is version ". $row->[2]);
    }

}

=head2 _expand_timestamp_str

Simple converts a date string that would appear in an FFSTAT file like 201307051300
into a DateTime object and returns it. It takes the offset column and applies that as
the timezone too.

201307051300 and +1:00 becomes 2013-07-05 13:00:00+1:00 (or 2013-07-05 12:00:00 UTC)

=cut

sub _expand_timestamp_str {
    my ($self, $value_str, $utc_offset) = @_;

    my $timestamp_parser = DateTime::Format::Strptime->new(
        pattern   => '%Y%m%d%H%M',
        time_zone => $utc_offset
    );

    my $dt = $timestamp_parser->parse_datetime($value_str);

    return $dt;

}

=head2 update_shipment_status_log

The first and only function in this file that contains any form of
business logic. :-)

First we work out if this is a DHL status maps to an event  we care about.
If it is, we see if it's a shipment we know about.

Assuming both, we then hand off to the relevent functions to create the
entries in the shipment status log table.

It maybe worth pointing out that returning deliveries and deliveries across
all the DCs are listed, so we don't log records we ignore as there can be
quite a few of them.

=cut

sub update_shipment_status_log {
    my ($self, $order_nr, $dhl_status, $air_waybill, $event_time) = @_;

    my $completion_event = $self->_is_completion_event($dhl_status);

    if (!$completion_event) {
        xt_logger->debug("not a completion event (dhl_status=$dhl_status, order_nr=$order_nr)");
        return;
    }

    my $shipment = $self->schema->resultset('Public::Shipment')->search({
        outward_airway_bill => $air_waybill,
        order_nr            => $order_nr
    }, {
        join => { 'link_orders__shipment' => 'orders' },
        rows => 1
    })->single;

    # the shipment not being found is rarely a problem. the file contains information
    # about shipments across other DCs that aren't in our database as well as customer
    # returns which aren't monitored here (hence, specify inward airway bills rather than
    # outward airway bills
    if (!defined($shipment)) {
        xt_logger->debug("shipment not found (dhl_status=$dhl_status, order_nr=$order_nr)");
        return;
    }

    $self->_log_completion_event($shipment, $dhl_status, $event_time)
        if $completion_event;

}

const my $NAP_COMPLETED_STATUS_MAP => {
    $SHIPMENT_STATUS__DELIVERY_ATTEMPTED => [ qw/BA CA CM NH RD RT/ ],
    $SHIPMENT_STATUS__DELIVERED => [ qw/DD OK PD/ ],
};

sub _is_completion_event {
    my ($self, $dhl_status) = @_;
    foreach my $completed_status_id (keys %$NAP_COMPLETED_STATUS_MAP) {
        my $dhl_completion_statuses = $NAP_COMPLETED_STATUS_MAP->{$completed_status_id};
        return 1 if any { $dhl_status eq $_ } @$dhl_completion_statuses;
    }

}

sub _log_completion_event {
    my ($self, $shipment, $dhl_status, $event_time) = @_;

    my $shipment_status_id;
    foreach my $completed_status_id (keys %$NAP_COMPLETED_STATUS_MAP) {
        my $dhl_completion_statuses = $NAP_COMPLETED_STATUS_MAP->{$completed_status_id};
        $shipment_status_id = $completed_status_id if any { $dhl_status eq $_ } @$dhl_completion_statuses;
    }

    $shipment->create_related('shipment_status_logs', {
        shipment_status_id => $shipment_status_id,
        operator_id        => $APPLICATION_OPERATOR_ID,
        date               => $event_time
    });

    xt_logger->info(sprintf("Adding a shipment status log entry to shipment (shipment_id=%d, status=%s, timestamp=%s)",
        $shipment->id,
        $shipment_status_id,
        $event_time
    ));
}

