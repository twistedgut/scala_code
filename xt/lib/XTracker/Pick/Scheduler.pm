package XTracker::Pick::Scheduler;
use NAP::policy "class", "tt";
with qw(
    XTracker::Role::WithSchema
    XTracker::Role::WithAMQMessageFactory
);
use DateTime::Format::Strptime;
use XTracker::Metrics::Recorder;

=head1 NAME

XTracker::Pick::Scheduler

=head1 DESCRIPTION

This class will select allocations for picking, trigger picks in other
PRLs, and calculate the induction capacity.

This implements this spec:
http://confluence.net-a-porter.com/display/DC2A/PickScheduler


=head2 Overview

Find all Shipments ready to operate on. These will have at least one
Allocation in status:

  * allocated - attempt to pick the allocation

  * allocating_pack_space - attempt to allocate pack space

  * staged - soft allocate pack space and accumulate the sum of these
    in the "induction_capacity"


=head3 Begin

Calculate remaining capacities for packing and all PRL capacities at
the start, and then keep track of a running total for the remaining
capacities as the Shipments are processed.

E.g. when an Allocation is sent to picking, that PRL's
picking_remaining_capacity is reduced.

Or if a Full Allocation is staged, the packing_remaining_capacity is
reduced and the induction_capacity is increased for that PRL.


=head3 Process Shipments

Loop over all Shipments in priority order and attempt to progress them
according to their status. Update statuses, send pick messages,
etc. and also keep track of the running total so we don't have to run
expensive queries in the loop.


=head3 End

At the end, save all capacities to the runtime_property table for
display purposes (except the induction_capacity, which is used to
control the Induction Point, and the ability to induct Containers
there.)



=head2 Classes

    |-- Scheduler.pm
    |-- PrlCapacity.pm
    `-- Scheduler
        `-- TriggeredAllocation.pm


=head3 Pick::Scheduler

Main class that contains the core functionality. It has attributes
e.g. for

* global capacities,
  * like packing_remaining_capacity, current_packing_remaining_capacity

* pack_area
  * To calculate the above packing capacity

* shipments_to_schedule_rs
  * Resultset for which selected Shipments to pick

* prl_capacity
  * hashref with a Pick::PrlCapacity object for each PRL


=head3 Pick::PrlCapacity

The PickScheduler has one Pick::PrlCapacity object for each PRL. A
PrlCapacity object keeps track of initial PRL related capacities and
current versions of each capacity.

e.g. picking_remaining_capacity, and current_picking_remaining_capacity

The picking_remaining_capacity is calculated at the start of the
->schedule_allocations run, and then the
current_picking_remaining_capacity is modified as picking capacity is
used up by bringing Allocations into Picking.

There is more documentation in L<XTracker::Pick::PrlCapacity>, don't
miss it.


=head3 Pick::Scheduler::TriggeredAllocation

This class is used to determine whether an Allocation is triggered by
another Allocation in the same Shipment and whether it's blocked from
picking because of that.

It's a self contained piece of functionality (which is nice, since
it's quite elaborate) that's instantiated as needed by the
Pick::Scheduler for a particular Allocation at a time.

There is more documentation in
L<XTracker::Pick::Scheduler::TriggeredAllocation>, don't miss it.



=head1 SYNOPSIS

    use XTracker::Pick::Scheduler;

    my $pick_scheduler = XTracker::Pick::Scheduler->new;
    $pick_scheduler->schedule_allocations();

=cut

use Carp;
use List::Util qw/
    sum
/;
use Sub::Actions;

use XTracker::Constants ':application';
use XTracker::Constants::FromDB qw/
    :allocation_status
    :shipment_status
    :shipment_item_status
/;

use NAP::Messaging::Timing;

use XT::Data::PRL::PackArea;
use XTracker::Pick::Scheduler::TriggeredAllocation;

use XTracker::Logfile qw/ xt_logger /;


=head1 ATTRIBUTES

=cut

sub prl_rs              { shift->schema->resultset("Public::Prl")->filter_active }
sub shipment_rs         { shift->schema->resultset("Public::Shipment") }
sub runtime_property_rs { shift->schema->resultset("Public::RuntimeProperty") }

has logger => (
    is      => 'ro',
    lazy    => 1,
    default => sub { xt_logger(__PACKAGE__) },
);

has operator_id => (
    is      => "ro",
    lazy    => 1,
    default => sub { $APPLICATION_OPERATOR_ID },
);

has pack_area => (
    is      => "ro",
    lazy    => 1,
    default => sub {
        my $self = shift;
        XT::Data::PRL::PackArea->new({ schema => $self->schema });
    },
);

has prl_rows => (
    is      => "ro",
    lazy    => 1,
    default => sub { return [ shift->prl_rs->all ] },
);

has _prl_cache => (
    is => "rw",
    isa => 'HashRef',
    lazy => 1,
    default => sub {
        my $self = shift;
        return { map { $_->id => $_ } @{$self->prl_rows} };
    }
);

sub _get_prl {
    my ($self, $id) = @_;
    return $self->_prl_cache->{$id};
}

has packing_remaining_capacity => (
    is      => "ro",
    lazy    => 1,
    default => sub { shift->pack_area->remaining_capacity },
);

has current_packing_remaining_capacity => (
    is      => "rw",
    lazy    => 1,
    default => sub { shift->packing_remaining_capacity },
    traits  => ["Counter"],
    handles => { reduce_current_packing_remaining_capacity => "dec" },
);

has prl_capacity => (
    is         => "ro",
    isa        => "HashRef[ XTracker::Pick::PrlCapacity ]",
    lazy_build => 1,
    traits     => ['Hash'],
    handles    => { capacities => "values" },
);

sub _build_prl_capacity { shift->prl_rs->prl_capacity() }

has prl_id_order => (
    is      => "ro",
    isa     => "HashRef",
    lazy    => 1,
    default => sub {
        my $self = shift;
        return {
            map { $_->picks_triggered_by_id => $_->trigger_order }
            $self->schema->resultset("Public::PrlPickTriggerOrder")->all
        };
    },
);

=head2 shipment_process_count : $query_limit

The max number of Shipments to select for the main loop.

We can't know in advance how many Shipments' Allocations might be
affected, so we use the sum of all the different parts of the system,
to ensure that even when the warehouse is busy and lots of parts are
at capacity, any extra possible picks are considered.

=cut

has shipment_process_count => (
    is         => "ro",
    lazy_build => 1,
);

sub _build_shipment_process_count {
    my $self = shift;
    return sum(
        $self->pack_area->packing_total_capacity,
        (
            map { $_->total_capacity("picking") }
            @{$self->prl_rows},
        ),
        (
            map { $_->total_capacity("staging") }
            grep { $_->has_staging_area }
            @{$self->prl_rows},
        ),
    );
}

has shipments_to_schedule_rs => (
    is         => "ro",
    lazy_build => 1,
);

sub _build_shipments_to_schedule_rs {
    scalar shift->shipment_selection_rs();
}

# attributes to allow us to store metrics for debugging
# the current pick scheduler run.

has _metric_tree => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { return {}; },
    init_arg => undef
);

has _metric_node => (
    is => 'rw',
    isa => 'HashRef',
    init_arg => undef
);

# helper function to extract datetimes from config
has _cutoff_date_by_type => (
    is => 'rw',
    isa => 'HashRef',
    default => sub {
        my $self = shift;
        return {
            sample   => $self->_get_config_value('exclude_sample_shipments_after'),
            premier  => $self->_get_config_value('exclude_premier_shipments_after'),
            standard => $self->_get_config_value('exclude_standard_shipments_after'),
        };
    }
);

sub _get_config_value {
    my ($self, $config_name) = @_;
    my $result = $self->schema->resultset('SystemConfig::Parameter')->search({
        name => $config_name
    })->first;
    return undef unless $result;
    return $result->value;
}

=head1 METHODS

=cut

=head2 notify($message) :

Log $message at a suitable log level.

This is currently set to info during the test and bedding-in period;
can be lowered to debug once it's been stable in Live for a while.

=cut

sub notify {
    my ($self, $message) = @_;
    $self->logger->info($message);
}

=head2 sub_timing($sub_name) :

Return timer guard object which logs the duration of $sub_name.

=cut

sub sub_timing {
    my ($self, $name) = @_;
    return NAP::Messaging::Timing->new({
        logger  => $self->logger,
        details => [ sub => $name ],
    });
}

=head2 capacity_for_prl_name($prl_name) : $prl_capacity | die

Return the PrlCapacity object for the $prl_name.

=cut

sub capacity_for_prl_name {
    my ($self, $name) = @_;
    my $capacity = $self->prl_capacity->{ $name }
        or confess("Could not find a Capacity for the PRL ($name)\n");
    return $capacity;
}

=head2 capacity_for_prl($prl_row) : $prl_capacity | die

Return the PrlCapacity object for the $prl_row.

=cut

sub capacity_for_prl {
    my ($self, $prl_row) = @_;
    return $self->capacity_for_prl_name( $prl_row->identifier_name );
}

=head2 capacity_for_allocation($allocation_row) : $prl_capacity | die

Return the PrlCapacity object for the PRL of the $allocation_row.

=cut

sub capacity_for_allocation {
    my ($self, $allocation_row) = @_;
    return $self->capacity_for_prl( $self->_get_prl( $allocation_row->prl_id ));
}

=head2 shipment_selection_rs() :

Return Shipment resultset with Shipments which should be processed by
the Pick::Scheduler for some reason.

Related tables are prefetched.

=cut

sub shipment_selection_rs {
    my ($self) = @_;

    my $shipment_rs = $self->shipment_rs->get_pick_scheduler_selection_list({
        exclude_held_for_nominated_selection => 1,
        exclude_non_prioritised_samples      => 1,
        prioritise_samples                   => 1,
    })->search(
        undef,
        {
            rows     => $self->shipment_process_count,
        },
    );

    return $shipment_rs;
}

=head2 set_induction_capacity($capacity) : $capacity

Set the PackArea induction capacity to C<$capacity>.

=cut

sub set_induction_capacity {
    my ( $self, $capacity ) = @_;
    return $self->pack_area->induction_capacity( $capacity );
}

=head2 schedule_allocations() :

Process all Allocations in the shipments in
->shipments_to_schedule_rs.

Run each Shipment in its own transaction and report errors on the same
level.

=cut

sub _log_shipment_error {
    my ($self, $shipment_row, $e) = @_;
    my $shipment_id = $shipment_row->id;
    my $error = "Error when scheduling Allocations for Shipment ($shipment_id): $e";
    $self->logger->error($error),
}

sub _notify_shipments {
    my ($self, $shipment_rows) = @_;
    $self->notify("*** schedule_allocations for " . (@$shipment_rows + 0) . " Shipments ***");
}

sub _notify_no_action_taken {
    my ($self, $shipment_row, $reason) = @_;
    my $reason_msg = $reason ? " reason: $reason" : "";
    $self->notify("No action taken for shipment_id (" . $shipment_row->id . ") $reason_msg");
    $self->_metric_node->{result} = "no action taken. $reason_msg";
}

sub _notify_actions_taken {
    my ($self, $shipment_rows, $no_action_taken_count) = @_;

    $self->notify("*** Shipments processed (" . (@$shipment_rows + 0) . "), no action taken for ($no_action_taken_count) of them");

    if ($no_action_taken_count && @$shipment_rows == $no_action_taken_count) {
        $self->logger->error(
            "(!) None of the $no_action_taken_count Shipments had any action taken",
        );
    }
}

sub schedule_allocations {
    my $self = shift;
    my $metric = XTracker::Metrics::Recorder->new();
    my $timing = $self->sub_timing("schedule_allocations");

    # Load lazy attribute defaults
    $self->packing_remaining_capacity();
    $self->prl_capacity();

    my $no_action_taken_count = 0;

    my @shipment_rows = $self->shipments_to_schedule_rs->all;

    $self->_notify_shipments(\@shipment_rows);

    $self->_metric_tree->{shipments_to_schedule} = [];

    for my $shipment_row (@shipment_rows) {

        my $cur_ship = {
            shipment_id => $shipment_row->id,
            created_date => $shipment_row->date->strftime("%F %R %z"),
            is_premier => $shipment_row->is_premier ? "true" : "false",
            is_sample => $shipment_row->is_sample_shipment ? "true" : "false",
            single_classifier => $self->_single_type_classifier($shipment_row)
        };

        push(@{ $self->_metric_tree->{shipments_to_schedule} }, $cur_ship);
        $self->_metric_node($cur_ship);

        # potentially skip if we are winding down warehouse processing
        # to bring the warehouse to rest.
        if ($self->_after_wind_down_cutoffs($shipment_row)) {
            $self->_notify_no_action_taken(
                $shipment_row,
                sprintf("skipped due to cutoffs. shipment date: %s",
                $shipment_row->date->strftime("%F %R %z")
            ));
            $no_action_taken_count++;
            next;
        }

        try {

            $self->schema->txn_do(
                sub {
                    if ( ! $self->process_shipment($shipment_row) ) {
                        $self->_notify_no_action_taken($shipment_row);
                        $no_action_taken_count++;
                    }
                },
            );
        }
        catch {
            $self->_log_shipment_error($shipment_row, $_ // "Unknown");
            $cur_ship->{'result'} = "exception: $_";
        };
    }

    $self->_notify_actions_taken(\@shipment_rows, $no_action_taken_count);

    $self->set_runtime_properties();
    $metric->store_metric('pick_scheduler', $self->_metric_tree);
    $metric->store_metric('pick_scheduler_cutoffs',
        $metric->dt_to_json_in_struct($self->_cutoff_date_by_type)
    );

    $self->notify_cutoff_values;

    return;
}

# we can wind down warehouse operations by skipping certain types
# of shipments after a certain date. So we can stop processing
# standard/samples from the last two hours whilst still accepting
# new premier orders.. this method controls whether we skip
# this shipment or not.

sub _after_wind_down_cutoffs {
    my ($self, $shipment_row) = @_;

    my $cutoff_type = $self->_single_type_classifier($shipment_row);
    my $cutoff_datetime = $self->_cutoff_date_by_type->{$cutoff_type};

    return 0 unless defined($cutoff_datetime);

    return ($shipment_row->date >= $cutoff_datetime);

}

# given a shipment return a single exclusive definition of
# premier, sample or standard.

sub _single_type_classifier {
    my ($self, $shipment_row) = @_;

    my $single_classifier = $shipment_row->is_premier ? 'premier' : 'standard';
    $single_classifier = 'sample' if $shipment_row->is_sample_shipment;
    return $single_classifier;
}

=head2 container_has_triggered_allocations($container_row) : Bool

Return true if $container_row contains any Shipment with an Allocation
that is triggered by another Allocation.

(If it does, it means the current Container will have to wait a little
at the pack lane before the other allocations have been picked. For
containers in the Cage, that means they'll need to keep the Container
in the Cage instead of bringing it to packing)

=cut

sub container_has_triggered_allocations {
    my ($self, $container_row) = @_;

    my @shipment_rows = $container_row->related_shipment_rs->search(
        undef,
        { prefetch => { allocations => "prl" } },
    )->all;
    for my $shipment_row (@shipment_rows) {
        return 1 if $self->is_any_allocation_blocked_by_triggering_allocation([
            $shipment_row->allocations->all,
        ]);
    }

    return 0;
}

=head2 is_any_allocation_blocked_by_triggering_allocation($allocation_rows) : Bool

Return true if any of $allocation_rows is triggered by another
Allocation.

=cut

sub is_any_allocation_blocked_by_triggering_allocation {
    my ($self, $allocation_rows) = @_;

    for my $allocation_row ( @$allocation_rows ) {
        next unless $allocation_row->is_allocated;

        my $triggered_allocation
            = XTracker::Pick::Scheduler::TriggeredAllocation->new({
                pick_scheduler  => $self,
                allocation_row  => $allocation_row,
                allocation_rows => $allocation_rows,
            });
        next unless $triggered_allocation->is_blocked_by_triggering_allocation();

        return 1;
    }

    return 0;
}



=head2 process_shipment($shipment_row) : $shipment_was_processed

Process the allocations in $shipment_row and depending on the state of
the Shipment and its Allocations:

  * pick
  * allocate pack space
  * count towards induction capacity

$shipment_row should have prefetched everything that's needed.

Return true if any action was taken for any of the Allocations, else
false.

(It's possible that the initial query will match a combination of
statuses that can't be processed. This is normal, but can be harmful
if none of the many shipments are actually progressed)

=cut

my $shipment_status_id_name = {};
sub _shipment_status {
    my ($self, $shipment_row) = @_;
    my $status_id = $shipment_row->shipment_status_id;
    return $shipment_status_id_name->{ $status_id } //= do {
        my $status = $shipment_row->shipment_status->status;
        "$status_id:$status";
    };
}

sub _notify_shipment {
    my ($self, $shipment_row, $allocation_rows) = @_;
    $self->notify(
        "-- processing shipment_id (" . $shipment_row->id . ") in status (" . $self->_shipment_status($shipment_row) . ") with (" . (@$allocation_rows + 0) . ") allocations",
    );
}

my $allocation_status_id_name = {};
sub _allocation_status {
    my ($self, $allocation_row) = @_;
    my $status_id = $allocation_row->status_id;
    return $allocation_status_id_name->{ $status_id } //= do {
        my $status = $allocation_row->status->status;
        "$status_id:$status";
    };
}

sub _notify_allocation {
    my ($self, $allocation_row) = @_;

    my $prl = $self->_get_prl($allocation_row->prl_id);

    $self->notify("  processing (" . $prl->identifier_name . ") allocation_id (" . $allocation_row->id . ") in allocation_status (" . $self->_allocation_status($allocation_row) . ")");
    $self->notify("    capacities:");
    $self->notify("      packing_remaining_capacity (" . $self->current_packing_remaining_capacity . ")");
    $self->_metric_node->{capacity_at_evaluation}->{"packing"} = $self->current_packing_remaining_capacity;

    my $capacity = $self->capacity_for_allocation( $allocation_row );
    for my $property ("picking", "staging", "induction") {
        my $property_string = $capacity->property_as_string($property) // next;
        $self->notify("      $property_string");
        $self->_metric_node->{capacity_at_evaluation}->{$property} = $property_string;
    }

}

sub process_shipment {
    my ($self, $shipment_row) = @_;
    my $timing = $self->sub_timing("process_shipment");

    my @allocation_rows = $self->ordered_allocations([
        $shipment_row->allocations->all,
    ]);

    $self->_notify_shipment($shipment_row, \@allocation_rows);

    my $shipment_metric = $self->_metric_node;
    $shipment_metric->{allocations} = [];

    my $no_action_taken_count = 0;
    for my $allocation_row (@allocation_rows) {

        my $allocation_metric = {
            allocation_id => $allocation_row->id,
            prl => $self->_get_prl($allocation_row->prl_id)->name
        };
        push(@{ $shipment_metric->{allocations} }, $allocation_metric);
        $self->_metric_node($allocation_metric);

        $self->_notify_allocation($allocation_row);

        if ($allocation_row->is_allocated) {
            # Full, GOH, DCD
            $self->attempt_pick_allocation($allocation_row, \@allocation_rows);
        }
        elsif ($allocation_row->is_allocating_pack_space) {
            # GOH, after pick_complete
            $self->attempt_allocate_pack_space($allocation_row);
        }
        elsif ($allocation_row->is_staged) {
            # Full, at induction point
            $self->attempt_claim_induction_capacity($allocation_row);
        }
        else {
            $self->notify("(-) no action taken in process_allocation");
            $no_action_taken_count++;
            $self->_metric_node->{result} = 'No action taken';
        }
    }

    return ! (@allocation_rows == $no_action_taken_count);
}

=head2 prl_ordinal() : $ordering_number

Return the ordinal of the PRL according to which order they trigger
each other. PRLs which don't trigger other PRLs are put last.

=cut

sub prl_ordinal {
    my ($self, $prl_id) = @_;
    return $self->prl_id_order->{$prl_id} // 9999; # put dcd last
}

=head2 ordered_allocations($allocation_rows) : @allocation_rows

Return list of Allocations in the order by which they trigger other
PRLs' Allocations.

=cut

sub ordered_allocations {
    my ($self, $allocation_rows) = @_;

    my @allocation_rows = sort {
        $self->prl_ordinal($a->prl_id) <=> $self->prl_ordinal($b->prl_id)
            ||
        $a->id <=> $b->id
    }
    @$allocation_rows;

    return @allocation_rows;
}

=head2 attempt_pick_allocation($allocation_row, $shipment_allocation_rows) : $is_picked

Attempt to pick $allocation_row if there is enough capacity (of
various kinds), by sending a pick message and adjusting the current
capacities.

Don't pick $allocation_row if it's blocked by any other Allocation in
this $shipment_allocation_rows (includes this $allocation_row).

Return 1 if the pick was sent, else 0.

=cut

sub _notify_no_pick {
    my ($self, $reason) = @_;
    $self->notify("(!) allocated, attempted pick failed: $reason");
    $self->_metric_node->{result} = "allocated, attempted pick failed: $reason";
    return 0;
}

sub _notify_pick {
    my ($self) = @_;
    $self->notify("(+) allocated, attempted pick successful!");
    $self->_metric_node->{result} = 'allocated, pick successful';
}

sub attempt_pick_allocation {
    my ($self, $allocation_row, $shipment_allocation_rows) = @_;

    # Collection subrefs to execute if all checks pass
    my $pick_actions = Sub::Actions->new();

    my $capacity = $self->capacity_for_allocation( $allocation_row );
    $capacity->ensure_pick_capacities( $pick_actions )
        or return $self->_notify_no_pick("no pick capacity");

    my $triggered_allocation
        = XTracker::Pick::Scheduler::TriggeredAllocation->new({
            pick_scheduler  => $self,
            allocation_row  => $allocation_row,
            allocation_rows => $shipment_allocation_rows,
        });

    if( $capacity->prl_row->allocates_pack_space_at_pick() ) {

        # Check if packing area is capable to accept more goods
        $self->current_packing_remaining_capacity > 0

            # ...tolerate lack of packing capacity if current
            # allocation belongs to shipment with all siblings from
            # slow PRLs being ready to be packed
            or $triggered_allocation->am_i_fast_with_all_slow_siblings_picked
            or return $self->_notify_no_pick("no packing capacity");

        $pick_actions->add(
            # Reduce packing_capacity with 1 Allocation, since we
            # don't know how many Containers it will end up in yet
            sub { $self->reduce_current_packing_remaining_capacity() },
        );
    }

    return $self->_notify_no_pick("blocked by triggering allocation")
        if $triggered_allocation->is_blocked_by_triggering_allocation();

    # We can pick the allocation
    $self->_notify_pick();
    $allocation_row->pick( $self->msg_factory, $self->operator_id );
    $pick_actions->perform(); # Update the current capacities

    return 1;
}

=head2 attempt_allocate_pack_space($allocation_row) : $is_picked

Attempt to allocate pack space for $allocation_row if there is enough
packing capacity, by transitioning to the next status and reducing the
current packing capacity.

Currently, this is only called for Allocations in
"allocating_pack_space", which only GOH does. GOH allocations are
still on Hooks at this point, and therefore not yet in their final
Container, so we don't know the size of the pick in Containers.

So, until that changes with another PRL, reduce the packing capacity
with 1 here.

Return 1 if pack space was allocated, else 0.

=cut

sub _notify_no_pack_space {
    my ($self, $reason) = @_;
    $self->notify("(!) allocating_pack_space, attempted allocation failed: $reason");
    $self->_metric_node->{result} = "allocating pack space failed: $reason";
    return 0;
}

sub _notify_pack_space {
    my ($self) = @_;
    $self->notify("(+) allocating_pack_space, attempted allocation successful!");
    $self->_metric_node->{result} = "pack space assigned";
}

sub attempt_allocate_pack_space {
    my ($self, $allocation_row) = @_;

    return $self->_notify_no_pack_space("no packing capacity")
        if ( $self->current_packing_remaining_capacity <= 0 );

    $self->_notify_pack_space();
    $allocation_row->allocate_pack_space();

    $self->reduce_current_packing_remaining_capacity();

    return 1;
}

=head2 attempt_claim_induction_capacity($allocation_row) : $is_induction_capacity_claimed

Attempt to claim induction capacity for $allocation_row if this PRL
has an induction capacity, and there is enough packing capacity

Do this by increasing the current remaining induction capacity and
reducing the current packing capacity.

Return 1 if pack space was claimed, else 0.

=cut

sub _notify_no_induction {
    my ($self, $reason) = @_;
    $self->notify("(!) staged, attempt to claim induction capacity failed: $reason");
    $self->_metric_node->{result} = "staged, attempt to claim induction capacity failed: $reason";
    return 0;
}

sub _notify_induction {
    my ($self) = @_;
    $self->notify("(+) staged, attempt to claim induction capacity successful!");
    $self->_metric_node->{result} = "staged, induction space allocated";
}

sub _notify_induction_not_needed {
    my ($self, $related_container_rows) = @_;
    my $containers = join(", ", map { $_->id } @$related_container_rows);
    $self->notify("(+) staged, attempt to claim induction capacity not needed. Containers already claimed induction capacity: ($containers).");
    $self->_metric_node->{result} = "staged, induction capacity not required. containers already claimed induction capacity";
}

sub attempt_claim_induction_capacity {
    my ($self, $allocation_row) = @_;

    return $self->_notify_no_induction("no packing capacity")
        if ( $self->current_packing_remaining_capacity <= 0 );

    my $capacity = $self->capacity_for_allocation( $allocation_row );
    my $related_container_rows = [ $allocation_row->related_containers ]; ###JLP: can we prefetch this?
    my $claimed_container_count = $capacity->maybe_claim_induction_capacity(
        $related_container_rows,
    );
    if( ! $claimed_container_count) {
        $self->_notify_induction_not_needed( $related_container_rows );
        return 1;
    }

    $self->_notify_induction();
    $self->reduce_current_packing_remaining_capacity( $claimed_container_count );

    return 1;
}

=head2 set_runtime_properties() :

Set (save to the runtime_property table) all relevant capacities.

=cut

sub set_runtime_properties {
    my ($self) = @_;

    for my $capacity ($self->capacities) {
        $capacity->set_runtime_properties();
    }

    $self->runtime_property_rs->set_property (
        packing_remaining_capacity => $self->current_packing_remaining_capacity,
    );
    $self->_metric_tree->{packing_remaining_capacity} = $self->current_packing_remaining_capacity;
}

=head2 notify_cutoff_values

Record cut off values to the log.

=cut

sub notify_cutoff_values {
    my $self = shift;

    my @types_and_dates;

    foreach my $type (keys %{ $self->_cutoff_date_by_type }) {
        my $cutoff = $self->_cutoff_date_by_type->{$type};
        my $cutoff_str = defined($cutoff) ?
            $cutoff->strftime("%F %R %z") :
            "undef";
        push(@types_and_dates, "[type: $type, cutoff: $cutoff_str ]");
    }

    $self->notify("pick scheduler cutoffs: ". join(', ', @types_and_dates));
}
