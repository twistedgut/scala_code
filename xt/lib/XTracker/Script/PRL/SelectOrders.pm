package XTracker::Script::PRL::SelectOrders;

use NAP::policy "tt", qw/class/;
extends 'XTracker::Script';

with 'XTracker::Script::Feature::SingleInstance',
     'XTracker::Script::Feature::Schema',
     'XTracker::Script::Feature::Verbose',
     'XTracker::Role::WithAMQMessageFactory';

use XTracker::Pick::Scheduler;
use XTracker::Logfile qw/ xt_logger /;
use List::Util qw/sum/;
use XTracker::Constants qw/ $APPLICATION_OPERATOR_ID /;
use XTracker::Constants::FromDB qw/:allocation_status :prl :shipment_item_status/;

=head1 NAME

XTracker::Script::PRL::SelectOrders

=head1 DESCRIPTION

Provides utilities to perform shipment or allocation "selection".

=head1 SYNOPSIS

    my $shipment_selector = XTracker::Script::PRL::SelectOrders->new({
        shipment_ids => \@shipment_ids,
        verbose      => 1,
        'dry-run'    => 1
    });
    $shipment_selector->invoke;

OR simply rely on its default values:

    my $shipment_selector = XTracker::Script::PRL::SelectOrders->new({
        shipment_ids => \@shipment_ids,
    });
    $shipment_selector->invoke;

=head1 ATTRIBUTES

=head2 shipment_ids

ArrayRef with shipment IDs to be "selected". Before selecting they are filtered
to include only those suitable for "selection".

=cut

has 'shipment_ids' => (
    is      => 'ro',
    isa     => 'ArrayRef[Str]',
    default => sub {[]},
);

=head2 allocation_ids

ArrayRef with allocation IDs to be "selected".

=cut

has 'allocation_ids' => (
    is      => 'ro',
    isa     => 'ArrayRef[Str]',
    default => sub {[]},
);

=head2 dry-run

Flag that indicate if any changes are committed. By default it is FALSE.

=cut

has 'dry_run' => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

has 'use_pick_scheduler_v2' => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;

    my $args = $_[0];

    # normalize values for 'shipment_ids' and 'allocation_ids': if it was passed
    # as string with comma / space separated values
    $args->{$_} = ref($args->{$_}) ? $args->{$_} : [split /\s*,\s*|\s+/, $args->{$_}||'']
        foreach qw/shipment_ids allocation_ids/;

    die "There should be provided either 'shipment_ids' or 'allocation_ids' or both"
        unless sum map { scalar @$_ } grep {$_} map { $args->{$_} } qw/shipment_ids allocation_ids/;

    die 'Allocation IDs are not supported when using Pick Scheduler version 2 mode'
        if $args->{use_pick_scheduler_v2} && @{$args->{allocation_ids}};

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

    if ($self->dry_run && $self->use_pick_scheduler_v2) {
        $self->inform(
            "'dry-run' and PickScheduler version 2 mode are incompatible. Aborting...\n"
        );

    } elsif ($self->use_pick_scheduler_v2) {

        # Pick Scheduler uses XT logger to report about its progress,
        # whereas current script reports to stdout, hence it is more
        # convenient for end users if both use the same destination.
        # Here we instantiate XT logger and customize it to report
        # to stdout as well as to the default file. Then pass it
        # into Pick Scheduler.
        my $stdout_appender = Log::Log4perl::Appender->new(
            "Log::Log4perl::Appender::Screen",
            name      => "screenlog",
            stderr    => 0,
        );

        my $logger = xt_logger(__PACKAGE__);
        $logger->add_appender($stdout_appender);

        XTracker::Pick::Scheduler->new(
            logger                   => $logger,
            shipments_to_schedule_rs => $self->selection_shipment_rs,
        )->schedule_allocations;
    } else {

        my @allocations = @{$self->get_allocations};
        $self->init_progress( scalar @allocations );

        my $number_of_selected;
        foreach my $allocation (@allocations) {

            $self->update_progress(++$number_of_selected);

            $self->dry_run
                or
            $allocation->pick( $self->msg_factory, $APPLICATION_OPERATOR_ID );
        }
    }

    $self->inform("\nDone!\n");

    return 0;
}

=head2 get_allocations: \@allocation_rows

Based on current object sate - allocation rows to be that should be "selected".

It takes current shipment IDs and allocation IDs as a source.

Only those allocations that are suitable for "selection" are returned.

=cut

sub get_allocations {
    my $self = shift;

    my @allocations;

    if ( scalar @{ $self->allocation_ids } ) {

        @allocations = $self->schema->resultset('Public::Allocation')->search({
            id        => $self->allocation_ids,
            status_id => $ALLOCATION_STATUS__ALLOCATED,
        })->all;
    }

    if ( scalar @{ $self->shipment_ids } ) {

        push @allocations,
            $self->selection_shipment_rs->search_related(
                'allocations',
                {
                    'allocations.status_id' => $ALLOCATION_STATUS__ALLOCATED,
                },
            )->all;
    }

    # make sure that allocations are unique in terms of its IDs
    my %allocations = map { $_->id => $_ } @allocations;

    return [ values %allocations ];
}

=head2 selection_shipment_rs: $shipment_resultset

Filter current shipment IDs and leave only those which are OK to be selected.

=cut

sub selection_shipment_rs {
    my $self = shift;

    my @shipment_ids = @{ $self->shipment_ids };

    if (@shipment_ids) {
        $self->inform("Got some shipment IDs from user, trying to filter ones suitable for selection\n");
    }

    return $self->schema->resultset('Public::Shipment')
        ->get_selection_list({
            exclude_non_prioritised_samples      => 1,
            prioritise_samples                   => 1,
            exclude_held_for_nominated_selection => 1,
        })->search({
            'me.id' => \@shipment_ids,
        })->search_rs;
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

    $self->inform("Found $total allocations\n", ' 'x$self->progress_indicator_string_length);
}

=head2 update_progress

Update progress bar with passed current position, so it reflects current state.

=cut

sub update_progress {
    my ($self, $current_position) = @_;

    $self->inform("\r"x$self->progress_indicator_string_length, sprintf $self->progress_indicator_string, $current_position);
}
