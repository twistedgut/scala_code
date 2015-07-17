package XTracker::Script::PRL::AllocateShipment;

use NAP::policy qw/class tt/;
extends 'XTracker::Script';

with 'XTracker::Script::Feature::SingleInstance',
     'XTracker::Script::Feature::Schema',
     'XTracker::Script::Feature::Verbose',
     'XTracker::Role::WithAMQMessageFactory';

use XTracker::Constants qw/ $APPLICATION_OPERATOR_ID /;
use XTracker::Constants::FromDB qw/:shipment_status/;

=head1 NAME

XTracker::Script::PRL::AllocateShipment

=head1 DESCRIPTION

Provides utilities to perform shipment allocation. It should be used just
after XT switched from non-PRL to PRL-enabled mode.

=head1 ATTRIBUTES

=head2 shipment_ids

ArrayRef with shipment IDs to be "allocated".

=cut

has 'shipment_ids' => (
    is      => 'ro',
    isa     => 'ArrayRef[Str]',
    default => sub{[]},
);

=head2 dry-run

Flag that indicate if any changes are committed. By default it is FALSE.

=cut

has 'dry_run' => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;

    my $args = $_[0];

    # normalize values for 'shipment_ids': if they were passed
    # as string with comma / space separated values
    $args->{shipment_ids} = ref($args->{shipment_ids})
        ? $args->{shipment_ids}
        : [split /\s*,\s*|\s+/, $args->{shipment_ids}||''];

    $class->$orig(@_)
};

=head1 METHODS

=head2 invoke: 0

Main entry point for the script. It uses object state as parameters.

=cut

sub invoke {
    my $self = shift;

    $self->inform("Setting up...\n");

    $self->dry_run and $self->inform("It is 'dry-run' mode: harmless for XTracker\n");

    my @shipment_rows = @{$self->get_shipments};

    $self->init_progress( scalar @shipment_rows );

    my $number_of_processed;
    my %failed_shipments;
    foreach my $shipment_row (@shipment_rows) {

        $self->update_progress(++$number_of_processed);

        try {
            $self->dry_run
                or
            $shipment_row->allocate({
                factory     => $self->msg_factory,
                operator_id => $APPLICATION_OPERATOR_ID,
            });
        }
        catch {
            $failed_shipments{ $shipment_row->id } = { shipment_row => $shipment_row, error => $_ };
        };
    }

    if ( my $failed_shipments_number = keys %failed_shipments ) {
        $self->inform(
            sprintf "\n\nFailed to process %s shipments\n", $failed_shipments_number
        );
        $self->inform(
            sprintf "    Shipment ID: %s, error: %s\n",
            $_->{shipment_row}->id, $_->{error}
        ) foreach values %failed_shipments;
    }

    $self->inform("\nDone!\n");

    return 0;
}

=head2 get_shipments: \@shipment_rows

Return shipment rows that are going to be allocated. The result bases on
current object state:

* if no shipmen IDs were provided - it returns ALL shipments
suitable for allocation,

* if there are provided shipment IDs - only correspondent shipments are return.

=cut

sub get_shipments {
    my $self = shift;

    my @shipment_rows;

    my %shipment_filter = (
        'me.shipment_status_id' => [
            $SHIPMENT_STATUS__PROCESSING, # majority of shipments should be in this state
            $SHIPMENT_STATUS__RECEIVED,

            # no harm for reallocating shipments on hold
            $SHIPMENT_STATUS__FINANCE_HOLD,
            $SHIPMENT_STATUS__HOLD,
            $SHIPMENT_STATUS__RETURN_HOLD,
            $SHIPMENT_STATUS__EXCHANGE_HOLD,
            $SHIPMENT_STATUS__DDU_HOLD,
            $SHIPMENT_STATUS__PRE_DASH_ORDER_HOLD,
        ],
    );

    if ( scalar @{ $self->shipment_ids } ) {

        $self->inform(
            "Got shipment IDs from user\n"
        );

        @shipment_rows = $self->schema->resultset('Public::Shipment')
            ->search({
                id => $self->shipment_ids,
            })
            ->all;

    } else {

        $self->inform(
            "No shipment IDs were provided: going to find ALL suitable for allocation\n"
        );

        @shipment_rows = $self->schema->resultset('Public::Shipment')
            ->search({
                %shipment_filter
            })
            ->all;
    }

    return \@shipment_rows;
}

=head2 progress_indicator_string: $string

Returns line that is shown while updating script progress. It is suitable for "sprintf".

=cut

sub progress_indicator_string {
    my $self = shift;

    return 'Processing: %10d';
}

=head2 progress_indicator_string_length

Returns length of line with progress indication.

=cut

sub progress_indicator_string_length {
    my $self = shift;

    return length sprintf $self->progress_indicator_string, 1;
}

=head2 init_progress

For passed total initiates progress bar.

=cut

sub init_progress {
    my ($self, $total) = @_;

    $total ||= '0';

    $self->inform("Found $total shipments\n", ' 'x$self->progress_indicator_string_length);
}

=head2 update_progress

Update progress bar with passed current position, so it reflects current state.

=cut

sub update_progress {
    my ($self, $current_position) = @_;

    $self->inform("\r"x$self->progress_indicator_string_length, sprintf $self->progress_indicator_string, $current_position);
}
