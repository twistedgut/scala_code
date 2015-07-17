use utf8;
package XTracker::Schema::Result::Public::PutawayPrepGroup;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.putaway_prep_group");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "putaway_prep_group_id_seq",
  },
  "status_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "group_id",
  { data_type => "integer", is_nullable => 1 },
  "recode_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "putaway_prep_cancelled_group_id",
  { data_type => "integer", is_nullable => 1 },
  "putaway_prep_migration_group_id",
  { data_type => "integer", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "putaway_prep_inventories",
  "XTracker::Schema::Result::Public::PutawayPrepInventory",
  { "foreign.putaway_prep_group_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "recode",
  "XTracker::Schema::Result::Public::StockRecode",
  { id => "recode_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "status",
  "XTracker::Schema::Result::Public::PutawayPrepGroupStatus",
  { id => "status_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:moo/3c9j6RYn4E9uIy5s/A

=head1 NAME

XTracker::Schema::Result::Public::PutawayPrepGroup - A process group used for Putaway Prep

=head1 DESCRIPTION

Represents a process group (PGID or Recode ID).

The group_id column in this table matches the group_id column
in the stock_process table. The relationship is maintained by application code.

=cut

use Carp qw( confess );
use MooseX::Params::Validate qw/validated_list/;
use Moose::Util::TypeConstraints 'duck_type';
use List::Util qw/ min sum /;
use List::MoreUtils qw/all any/;

use XTracker::Constants qw(
    :prl_type
    $APPLICATION_OPERATOR_ID
);
use XTracker::Constants::FromDB qw(
    :business
    :stock_process_type
    :stock_process_status
    :putaway_prep_container_status
    :putaway_prep_group_status
    :shipment_item_status
    :stock_action
    :pws_action
);
use XTracker::Database::StockProcess qw/get_process_group_total/;
use XTracker::Database::StockProcessCompletePutaway ();
use XTracker::Database::Stock;
use XTracker::Database::FlowStatus qw/:stock_process/;
use XTracker::Database::Recode;

use XTracker::Config::Local;
use XTracker::Logfile qw(xt_logger);
use XT::Domain::PRLs;

my $log = xt_logger(__PACKAGE__);

__PACKAGE__->many_to_many(
    "putaway_prep_containers",  # name of relationship I'm creating
    "putaway_prep_inventories", # the relationship I have to the link table
    "putaway_prep_container",   # the relationship the link table has to the thing I want
); # NOTE: This returns duplicate container rows, one for each inventory

# only valid if group is associated with stock process, i.e. group_id is not null:
__PACKAGE__->has_many(
  "stock_processes",
  "XTracker::Schema::Result::Public::StockProcess",
  { "foreign.group_id" => "self.group_id" },
  {},
);

=head1 METHODS

=head2 canonical_group_id

Returns group ID that include correspondent prefix. It depends on if current
record stand for PGID (process group) or recode group.

=cut

sub canonical_group_id {
    my ($self) = @_;

    if ($self->is_stock_recode){
        return 'r' . $self->recode_id;
    } elsif ($self->is_cancelled_group) {
        return 'c' . $self->putaway_prep_cancelled_group_id;
    } elsif ($self->is_migration_group) {
        return 'm' . $self->putaway_prep_migration_group_id;
    } else {
        return 'p' . $self->group_id;
    }
}

=head2 notice_advice_message

B<Description>

Comments correspondent recode group with container IDs used to put away related stock.

If this method is called on process group related instance - nothing happens.

B<Parameters>

=over

=item container_id

Container ID to be recorded.

=back

B<Returns>

1 - in case of success,

undef - otherwise, e.g. "container_id" was not passed.

=cut

sub notice_advice_message {
    my ($self, $args) = @_;

    my $container_id = $args->{container_id};

    return unless $container_id;

    if (my $stock_recode = $self->recode) {
        my $recode_notes = $stock_recode->notes || '';

        # add one item to the container list if it exists,
        # otherwise start new list
        unless ($recode_notes =~ s/(Putaway in .+)\.$/$1, $container_id./ ) {
            $recode_notes .= "Putaway in $container_id.";
        }

        # if in any case comments overflow limitation - cut them
        $recode_notes =~ s/^(.{250,251}).*$/$1.../;

        $stock_recode->update({notes => $recode_notes});
    }

    return 1;
}

=head2 get_stock_process_type_id

Returns ID of stock process type for current instance of putaway prep group.

It works with both types of putaway prep group: based on Process group and
based on Recode groups.

=cut

sub get_stock_process_type_id {
    my $self = shift;

    my $type_id;
    if ($self->is_stock_recode) {
        $type_id = $STOCK_PROCESS_TYPE__MAIN;

    } elsif ($self->is_cancelled_group) {
        $type_id = $STOCK_PROCESS_TYPE__MAIN;

    } elsif ($self->is_migration_group) {
        $type_id = $STOCK_PROCESS_TYPE__MAIN;

    } else {
        $type_id = $self->stock_processes->first->type_id;
    }

    return $type_id;
}

=head2 get_stock_process_type

Returns Public::StockProcessType DBIC object for current group instance.

=cut

sub get_stock_process_type {
    my ($self) = @_;

    return
        $self->result_source->schema->resultset('Public::StockProcessType')
            ->find( $self->get_stock_process_type_id );
}

=head2 get_stock_status_id: $stock_process_type_id

=cut

sub get_stock_status_id {
    my $self = shift;

    return flow_status_from_stock_process_type( $self->get_stock_process_type_id );
}

=head2 get_stock_status_row: $flow_status_row

Returns Stock status row object for current group.

=cut

sub get_stock_status_row {
    my $self = shift;

    return $self->result_source->schema->resultset('Flow::Status')
        ->find( $self->get_stock_status_id );
}

=head2 get_stock_status_row_from_cache

Given a hash containing id -> flow status records, this
query returns the stock_status_row, just like the above
function, but without hitting the database.

=cut

sub get_stock_status_row_from_cache {
    my ($self, $all_flow_statuses) = @_;

    return $all_flow_statuses->{ $self->get_stock_status_id };
}

=head2 expected_quantity

Returns the number of items expected to be scanned for this group.

=cut

sub expected_quantity {
    my $self = shift;

    return sum( values %{ $self->expected_quantities } ) // 0;
}

=head2 cached_expected_quantity

Same as ->expected_quantity, but cached.

=cut

sub cached_expected_quantity {
    my $self = shift;
    return $self->{__expected_quantity} //= $self->expected_quantity;
}

=head2 expected_quantities:\%hash_with_statistics

Returns hash ref where keys are variant IDs and values are quantities expected
for current group.

=cut

sub expected_quantities {
    my $self = shift;

    my %expected_quantities;

    if ($self->is_stock_recode) {
        my $recode = $self->recode;
        $expected_quantities{ $recode->variant_id } = $recode->quantity;
    }
    elsif ($self->is_stock_process) {

        foreach my $stock_process_row ( $self->stock_processes ) {
            unless ($stock_process_row->cached_variant_id) {
                $log->error(sprintf(
                    'Missing variant for stock process row %d for putaway prep group %d',
                    $stock_process_row->id, $self->id
                ));
                next;
            }
            $expected_quantities{$stock_process_row->cached_variant_id} += $stock_process_row->quantity;
        }
    }
    elsif ($self->is_cancelled_group) {

        # we have one "cancelled group" per putaway container, so we expect
        # "cancelled groups" as much items as we scanned during putaway prep
        %expected_quantities = %{ $self->scanned_quantities };
    }
    elsif ($self->is_migration_group) {
       %expected_quantities = %{ $self->scanned_quantities };
    } else {
        $self->whatami;
    }

    return \%expected_quantities;
}

sub cached_expected_quantities {
    my $self = shift;

    return $self->{__expected_quantities} //= $self->expected_quantities;
}

=head2 inventory_quantity

Returns the number of items already scanned into containers for this
group.

=cut

sub inventory_quantity {
    my ($self) = @_;

    my $inventory_quantity = sum( values %{$self-> scanned_quantities} ) // 0;

    $log->trace(sprintf('Putaway prep inventory quantity: %s',
        ($inventory_quantity ? $inventory_quantity : 'n/a') ));

    return $inventory_quantity;
}

=head2 cached_inventory_quantity

Same as ->inventory_quantity, but cached.

=cut

sub cached_inventory_quantity {
    my ($self) = @_;
    return $self->{__inventory_quantity} //= $self->inventory_quantity();
}

=head2 scanned_quantities:\%hash_with_statistics

Returns hash ref where keys are variant IDs and values are number scanned.

=cut

sub scanned_quantities {
    my $self = shift;

    my %scanned_quantities;
    foreach my $ppi ($self->putaway_prep_inventories) {
        $scanned_quantities{$ppi->variant_with_voucher_id } += $ppi->quantity;
    }

    return \%scanned_quantities;
}

sub cached_scanned_quantities {
    my $self = shift;

    return $self->{__scanned_quantities} //= $self->scanned_quantities;
}


=head2 is_problem_on_putaway_admin: Boolean

Determine if we have a "Putaway problem" for current group: if we scanned more than expected
of particular SKU _AND_ all other SKUs are also scanned.

=cut

sub is_problem_on_putaway_admin {
    my $self = shift;

    my $expected_quantities = $self->cached_expected_quantities;
    my $scanned_quantities  = $self->cached_scanned_quantities;

    my $everything_expected_is_scanned =
        all
            {$expected_quantities->{$_} <= ($scanned_quantities->{$_} // 0) }
            keys %$expected_quantities;

    my $at_least_one_sku_was_overscanned =
        any
            {$expected_quantities->{$_} < ($scanned_quantities->{$_} // 0) }
            keys %$expected_quantities;

    return
        $everything_expected_is_scanned
            &&
        $at_least_one_sku_was_overscanned;
}

=head2 is_part_complete_on_putaway_admin_page: Boolean

Determines if it is "Part complete" on Putaway admin page: whether or not current group
has SKUs that are not scanned yet.

=cut

sub is_part_complete_on_putaway_admin_page {
    my $self = shift;

    my $expected_quantities = $self->cached_expected_quantities;
    my $scanned_quantities  = $self->cached_scanned_quantities;

    return any
        { $expected_quantities->{$_} > ($scanned_quantities->{$_} // 0) }
        %$expected_quantities;
}

=head2 is_scanned_matches_expected: Boolean

Check if current group has same amount scanned as it is expected.

=cut

sub is_scanned_matches_expected {
    my $self = shift;

    my $expected_quantities = $self->cached_expected_quantities;
    my $scanned_quantities  = $self->cached_scanned_quantities;

    return
        scalar(keys %$expected_quantities) == scalar(keys %$scanned_quantities)
            &&
        all
            {$expected_quantities->{$_} == ($scanned_quantities->{$_} // 0) }
            keys %$expected_quantities;
}

=head2 is_at_least_one_sku_is_underscanned: Boolean

Determine if at least one SKU is underscanned.

=cut

sub is_at_least_one_sku_is_underscanned {
    my $self = shift;

    my $expected_quantities = $self->cached_expected_quantities;
    my $scanned_quantities  = $self->cached_scanned_quantities;

    return
        any
            {$expected_quantities->{$_} > ($scanned_quantities->{$_} // 0) }
            keys %$expected_quantities;
}

=head2 is_stock_recode

True if this group's based on a stock_recode row.

=cut

sub is_stock_recode {
    my ($self) = @_;
    return defined $self->recode_id;
}

=head2 is_stock_process

True if this group's based on stock_process rows.

=cut

sub is_stock_process {
    my ($self) = @_;
    return defined $self->group_id;
}

=head2 is_cancelled_group

True if this group's based on stock that comes from "Putaway cancelled" location.

=cut

sub is_cancelled_group {
    my ($self) = @_;
    return defined $self->putaway_prep_cancelled_group_id;
}

=head2 is_migration_group

True if this group is based on stock that is being migrated.

=cut

sub is_migration_group {
    my ($self) = @_;
    return defined $self->putaway_prep_migration_group_id;
}

=head2 variants

Returns an arrayref of Variant objects associated with the group

=cut

sub variants {
    my ($self) = @_;

    my @variants;
    if ($self->is_stock_recode) {
        my $stock_recode = $self->result_source->schema->resultset('Public::StockRecode')
            ->find($self->recode_id);
        @variants = ( $stock_recode->variant ); # there will only be one
    } elsif ($self->is_stock_process) {
        # there can be several.
        #  includes vouchers
        my @stock_processes = $self->stock_processes->all;

        foreach my $stock_process (@stock_processes) {
            if (my $variant = $stock_process->variant) {
                push @variants, $variant;
            } else {
                $log->error(sprintf('No variant found for group ID "%s"', $self->group_id));
            }
        }
    } elsif ($self->is_cancelled_group) {

        # the variants for current pp_groups are those which were scanned into
        # container during Putaway prep process
        @variants = map { $_->variant } $self->putaway_prep_inventories->all;
    } elsif ($self->is_migration_group) {
        @variants = map { $_->variant } $self->putaway_prep_inventories->all;
    } else {
        $self->whatami;
    }

    return \@variants;
}

=head2 variants_as_hash: \%hash

Returns hash ref with variant IDs as keys and variant rows as values.

=cut

sub variants_as_hash {
    my $self = shift;

    my $variants = $self->variants;

    return { map { $_->id => $_ } @$variants };
}

=head2 delivery

For stock_process groups, returns the associated row from the delivery table.
For stock_recode groups, always returns undef.

=cut

sub delivery {
    my ($self) = @_;

    if ($self->is_stock_process) {
        return $self->stock_processes->first->delivery_item->delivery;
    }
    else {
        # recodes aren't associated with any delivery
        return;
    }
}

=head2 resolve_problem( :$message_factory ) :

Resolve the problem by completing the putaway (if possible) and
marking it as resolved.

* For groups with 'Problem' status (stock surplus), the stock will
  have already been putaway in the AdviceResponse message.

* For groups that are 'In Progress' (stock deficit), we putaway them
  here This assumes all the inventory in a group can only be putaway
  to a single location

=cut

sub resolve_problem {
    my ($self, $message_factory) = validated_list(\@_,
        message_factory => { isa => duck_type(['transform_and_send']) },
    );

    $self->complete_putaway({
        message_factory => $message_factory,
        location_row    => $self->destination_location_row,
    }) unless $self->status_id == $PUTAWAY_PREP_GROUP_STATUS__PROBLEM;

    $self->mark_resolved;

    $self->send_stock_check_to_prl($message_factory);

    return;
}

=head2 mark_resolved

Change status to 'Resolved'.

=cut

sub mark_resolved {
    my ($self) = @_;
    $self->update({ status_id => $PUTAWAY_PREP_GROUP_STATUS__RESOLVED });
}

=head2 is_active

=cut

sub is_active {
    my ($self) = @_;
    return ($self->status_id == $PUTAWAY_PREP_GROUP_STATUS__PROBLEM
        || $self->status_id == $PUTAWAY_PREP_GROUP_STATUS__IN_PROGRESS) ? 1 : 0;
}

=head2 assert_is_active() : $self | die

Ensure the group is active: return $self if it is active, else die.

=cut

sub assert_is_active {
    my $self = shift;
    $self->is_active or die("pp_group " . $self->id . " is not active\n");
    return $self;
}

=head2 can_mark_resolved

Can this group be marked as resolved and removed from the Putaway Prep Admin page
without any futher action being required?

See Putaway Resolution page for groups that require further actions in order
to resolve.

=cut

sub can_mark_resolved {
    my $self = shift;

    $log->trace("Can group ".$self->canonical_group_id." be marked resolved?");

    # Can't mark inactive groups as resolved
    $log->trace("checking if group is active");
    return unless $self->is_active;

    # Must have at least some containers
    $log->trace("checking if group has containers");
    return unless $self->number_of_containers > 0;

    # All containers must be complete
    $log->trace("checking if all containers are complete");
    return unless $self->number_of_containers == $self->advices_completed;

    # Can be resolved only if:
    $log->trace("checking if too much or too little inventory was putaway");

    # Too much inventory was putaway
    if ($self->is_problem_on_putaway_admin) {
        return 1;
    }

    my $atleast_one_sku = $self->is_at_least_one_sku_is_underscanned;
    my $atleast_one_advice_sent = ($self->advices_sent > 0);
    my $all_advices_done = ($self->advices_sent == $self->advices_completed);

    return 1 if ($atleast_one_sku && $atleast_one_advice_sent && $all_advices_done);

    $log->trace("group cannot be marked resolved");
    return;
}

sub advices_sent {
    my ($self) = @_;
    return $self->_container_status_summary->{advices_sent};
}

sub advices_completed {
    my ($self) = @_;
    return $self->_container_status_summary->{advices_completed};
}

sub containers_in_progress {
    my ($self) = @_;
    return $self->_container_status_summary->{containers_in_progress};
}

sub containers_in_transit {
    my ($self) = @_;
    return $self->_container_status_summary->{containers_in_transit};
}

sub containers_failed {
    my ($self) = @_;
    return $self->_container_status_summary->{containers_failed};
}

sub number_of_containers {
    my ($self) = @_;
    return $self->putaway_prep_containers->count;
}

sub _container_status_summary {
    my ($self) = @_;

    return $self->{__cached_container_status_summary} //= do {

        # See also similar logic in templates:
        #   root/base/stocktracker/goods_in/putaway_admin_group_status.inc

        return unless $self->number_of_containers > 0;

        my $advices_sent           = 0;
        my $advices_completed      = 0;
        my $containers_in_progress = 0;
        my $containers_in_transit  = 0;
        my $containers_failed      = 0;

        foreach my $container ($self->putaway_prep_containers) {
            if ($container->is_failure) {
                $containers_failed++;
            }
            if ($container->is_in_progress) {
                $containers_in_progress++;
            }
            if ($container->is_in_transit) {
                $advices_sent++;
                $containers_in_transit++;
            }
            # Finished is either complete or resolved
            if ($container->is_finished) {
                $advices_sent++;
                $advices_completed++;
            }
        }

        return {
            advices_sent           => $advices_sent,
            advices_completed      => $advices_completed,
            containers_in_progress => $containers_in_progress,
            containers_in_transit  => $containers_in_transit,
            containers_failed      => $containers_failed,
        };
    };
}

=head2 destination_location_row() : $location_row | undef

Return a Location row for any of the Group's Container destinations,
or undef if there is no Container.

Choose any Container, as we assume they're all bound for the same PRL.

=cut

sub destination_location_row {
    my $self = shift;
    my $container_row = $self->putaway_prep_containers->first or return undef;
    return $container_row->destination;
}

=head2 can_complete_putaway() : Bool

Return true if this PP Group is ready to complete putaway.

It can't be a in a PROBLEM state, and all the PP Containers must be
finished.

There can also not be any remaining Inventory quantities to scan
compared to the expcected StockProcess quantities.

=cut

sub can_complete_putaway {
    my $self = shift;
    $log->info( sprintf("DCA-2625: pprep_group(%s)->can_complete_putaway", $self->id) );

    # If group is already in 'Problem' status, don't put it away again
    return 0 if $self->status_id == $PUTAWAY_PREP_GROUP_STATUS__PROBLEM;
    $log->info( "DCA-2625:     not in problem status");

    # Are all containers finished (i.e. complete or resolved)?
    return 0 unless
        all {
            $log->info( sprintf(
                "DCA-2625:     In pp_group(%s)->can_complete_putaway checking pprep_container (%s) (%s): (%s)",
                $self->id,
                $_->id,
                $_->container_id,
                $_->is_finished,
            ));
            $_->is_finished;
        }
        $self->putaway_prep_containers->all;

    my $expected_quantities = $self->expected_quantities;
    my $scanned_quantities  = $self->scanned_quantities;

    $log->info(sprintf(
        "DCA-2625:     not all pprep containers are finished yet. Checking all skus are scanned: expected(%s), scanned(%s)",
        Dumper( $expected_quantities ),
        Dumper( $scanned_quantities ),
    )); use Data::Dumper;

    # we cannot complete putaway until all expected variants/SKUs are scanned
    return 0
        if any
            { ($scanned_quantities->{$_} // 0) < $expected_quantities->{$_} }
            keys %$expected_quantities;

    $log->info( "DCA-2625:     all expected (or more) skus scanned ==> we can complete the putaway");

    return 1;
}

=head2 attempt_complete_putaway( :$message_factory, :$location_row ) : $is_completed

If it's possible (according to the state of the PP Group and its
Containers), complete this putaway into $location_row

Send messages using $message_factory.

=cut

sub attempt_complete_putaway {
    my ($self, $message_factory, $location_row) = validated_list(\@_,
        message_factory => { isa => duck_type(['transform_and_send']) },
        location_row    => { isa => 'XTracker::Schema::Result::Public::Location' },
    );

    $log->info( sprintf("DCA-2625: pprep_group(%s)->attempt_complete_putaway. location_row(%s)", $self->id, $location_row->id) );
    my $can_complete_putaway = $self->can_complete_putaway;
    $log->info( sprintf("DCA-2625:     pprep_group(%s)->attempt_complete_putaway. can_complete_putaway returned ($can_complete_putaway)", $self->id) );
    $can_complete_putaway or return 0;
    $log->info("DCA-2625:         calling ->update_complete_status, ->complete_putaway");
    $self->update_complete_status();

    $self->complete_putaway({
        message_factory => $message_factory,
        location_row    => $location_row,
    });

    return 1;
}

=head2 update_complete_status() :

Update the status_id to PROBLEM | COMPLETED according to how much was
put away.

Here is our graph for pp_group status: # Groups start life as IN_PROGRESS

    Where "all containers are complete"
      Where sum( inventories.quantity ) == sum( sp/sr.quantity ) -> COMPLETE
      Where sum( inventories.quantity ) >  sum( sp/sr.quantity ) -> PROBLEM

    NOTE: it is variant aware

=cut

sub update_complete_status {
    my $self = shift;

    my $expected_quantities = $self->expected_quantities;
    my $scanned_quantities  = $self->scanned_quantities;
    $log->info( sprintf(
        "DCA-2625: pprep_group(%s)->update_complete_status. current status_id(%s), expected_quantities(%s), scanned_quantities(%s)",
        $self->id,
        $self->status_id,
        Dumper( $expected_quantities ),
        Dumper( $scanned_quantities ),
    ) ); use Data::Dumper;

    # We might have the right number or too many. Both cause us to
    # complete the putaway, but we do different things to the pp_group
    # status first, as per the graph above.
    if (
        any
        { ($scanned_quantities->{$_} // 0) > $expected_quantities->{$_} }
        keys %$expected_quantities
    ){
        $log->info("DCA-2625:    update to PROBLEM");
        $log->debug('problem');
        $self->update({ status_id => $PUTAWAY_PREP_GROUP_STATUS__PROBLEM });
    }
    else {
        $log->info("DCA-2625:    update to COMPLETED");
        $log->debug('completed');
        $self->update({ status_id => $PUTAWAY_PREP_GROUP_STATUS__COMPLETED });
    }

    return;
}

=head2 variant_total_inventory_quantity() : $variant_id__scanned_quantity

Group the Inventories by variant (sum the quantities per variant).

Return hashref with (keys: variant_id; value: total_quantity)

=cut

sub variant_total_inventory_quantity {
    my $self = shift;
    $self->is_stock_process or return { };

    my $variant_total_quantity = {};
    for my $inventory_row ( $self->putaway_prep_inventories ) {
        my $variant_id = $inventory_row->variant_with_voucher_id;
        $variant_total_quantity->{ $variant_id } += $inventory_row->quantity;
    }

    return $variant_total_quantity;
}

sub _allocate_quantity_from_remaining {
    my ($self, $variant_remaining_quantity, $stock_process_row) = @_;

    my $variant_id = $stock_process_row->cached_variant->id;
    my $remaining_quantity = $variant_remaining_quantity->{ $variant_id } //= 0;

    my $allocation_quantity = $stock_process_row->quantity;
    my $actual_quantity = min( $allocation_quantity, $remaining_quantity );
    $variant_remaining_quantity->{ $variant_id } -= $actual_quantity;

    return $actual_quantity;
}

=head2 stock_process_recs(:$location_row) : $stock_process_recs

Compare how much reported StockProcess stock quantities are fulfilled
by actually scanned Inventory stock quantities.

Return $stock_process_recs arrayref of hashref records with
StockProcess data, suitable to pass on to &complete_putaway().

The records contain the StockProcess info for this Group, with
expected (from StockProcess rows) "quantity" and actually scanned
"ext_quantity" (from Inventory rows), per Variant.

Unexpectedly small Inventory quantities that can't be used to fulfill
StockProcess quantities are reported as a deficit on each
StockProcess.

Unexpectedly large Inventory quantities are reported as a surplus on
the last StockProcess.

=cut

sub stock_process_recs {
    my ($self, $location_row) = validated_list( \@_,
        location_row => { isa => 'XTracker::Schema::Result::Public::Location' },
    );

    my $variant_remaining_quantity = $self->variant_total_inventory_quantity();

    # For each stock process, allocate an actual quantity from the
    # remaining quantity for that variant
    my @inventory_sp_recs;
    my %variant_stock_process_rec;
    for my $stock_process_row ( $self->stock_processes->all_ordered ) {
        my $actual_quantity = $self->_allocate_quantity_from_remaining(
            $variant_remaining_quantity,
            $stock_process_row,
        );

        my $stock_process_rec = $stock_process_row->stock_process_rec(
            actual_quantity => $actual_quantity,
            location_row    => $location_row,
        );

        my $variant_id = $stock_process_row->cached_variant->id;
        $variant_stock_process_rec{ $variant_id } = $stock_process_rec;
        push(@inventory_sp_recs, $stock_process_rec);
    }

    # Anything left in remaining quantity is surplus; assign it to any
    # stock_process_rec for the variant
    for my $variant_id (sort keys %$variant_remaining_quantity) {
        my $remaining_quantity = $variant_remaining_quantity->{$variant_id} or next;
        my $stock_process_rec = $variant_stock_process_rec{$variant_id};
        $stock_process_rec->{ext_quantity} += $remaining_quantity;
    }

    return [ @inventory_sp_recs ];
}

sub complete_putaway {
    my ($self, $message_factory, $location_row) = validated_list( \@_,
        message_factory => { isa => duck_type(['transform_and_send']) },
        location_row    => { isa => 'XTracker::Schema::Result::Public::Location' },
    );
    my $schema = $self->result_source->schema;

    # Close off this group
    if ($self->is_stock_process) {

        my $stock_process_recs = $self->stock_process_recs({
            location_row => $location_row,
        });

        $log->trace("PUTAWAY: Completing putaway for pgid ".$self->group_id);
        XTracker::Database::StockProcessCompletePutaway::complete_putaway(
            $schema,                  # DB Schema
            undef,                    # Stock Manager, will default to something sensible
            $self->group_id,          # The PGID
            $APPLICATION_OPERATOR_ID, # Who we'll log this action as
            $message_factory,         # A message factory
            undef,                    # Putaway type, will be looked up later
            # Crucially, contains the groups' expected quantity
            # (quantity) and actually scanned quantity (ext_quantity)
            $stock_process_recs,
        );
    } elsif ($self->is_stock_recode) {
        # Putaway the recode
        XTracker::Database::Recode::putaway_stock_recode({
            schema      => $schema,
            location    => $location_row,
            stock_recode=> $self->recode,
        });
        $self->recode->update({ complete => 1 });

    } elsif ($self->is_cancelled_group) {

        # update related shipment items
        $self->cancel_shipment_items_in_cancel_pending;

        $self->putaway_cancelled_group({
            location => $location_row,
        });

    } elsif ($self->is_migration_group) {

        $self->putaway_migration_group({
            location => $location_row,
        });

    } else {
        $self->whatami;
    }
}

=head2 putaway_cancelled_group(:$location_row) : 1 | undef

If current group is "Cancelled group" one - putaway related stock.

=cut

sub putaway_cancelled_group {
    my ($self, $location) = validated_list( \@_,
        location => {isa => 'XTracker::Schema::Result::Public::Location'},
    );
    return unless $self->is_cancelled_group;

    my $schema = $self->result_source->schema;

    foreach my $ppi ($self->putaway_prep_inventories->all){

        my $variant = $ppi->variant_with_voucher;

        XTracker::Database::Stock::putaway_via_variant_and_quantity({
            schema           => $schema,
            channel          => $variant->current_channel,
            variant          => $variant,
            location         => $location,
            notes            => 'Putaway stock from Cancelled location',
            quantity         => $ppi->quantity,
            stock_action     => $STOCK_ACTION__PUT_AWAY,
            pws_stock_action => $PWS_ACTION__PUTAWAY,
        });
    }
}

=head2 putaway_migration_group(:$location_row) : 1 | undef

If current group is "Migration group" - putaway related stock.

=cut

sub putaway_migration_group {
    my ($self, $location) = validated_list( \@_,
        location => {isa => 'XTracker::Schema::Result::Public::Location'},
    );
    return unless $self->is_migration_group;

    my $schema = $self->result_source->schema;

    foreach my $ppi ($self->putaway_prep_inventories->all){

        my $variant = $ppi->variant_with_voucher;

        XTracker::Database::Stock::putaway_via_variant_and_quantity({
            schema           => $schema,
            channel          => $variant->current_channel,
            variant          => $variant,
            location         => $location,
            notes            => 'Putaway stock from Migration location',
            quantity         => $ppi->quantity,
            stock_action     => $STOCK_ACTION__PUT_AWAY,
            pws_stock_action => $PWS_ACTION__PUTAWAY,
        });
    }
}

=head2 cancel_shipment_items_in_cancel_pending: 1

Go through all related pp_inventories and for correspondent SKUs
search for shipment items in "cancelled pending" status and move
them to "cancelled" one.

Change statuses as one update per physical item in PP_INVENTORY.

For shipment items related to same SKU consider one created earlier to have priority.

=cut

sub cancel_shipment_items_in_cancel_pending {
    my ($self) = @_;

    my $shipment_item_rs = $self->result_source->schema->resultset('Public::ShipmentItem');
    $_->set_cancelled( $APPLICATION_OPERATOR_ID ) for map
        {
            $shipment_item_rs
                ->search_by_sku_and_item_status(
                    $_->variant_with_voucher->sku,
                    $SHIPMENT_ITEM_STATUS__CANCEL_PENDING
                )
                ->search(undef, { order_by => { -asc => 'id'} })
                ->slice(0, $_->quantity - 1)
        }
        $self->putaway_prep_inventories->all;

    return 1;
}

sub whatami {
    my ($self) = @_;
    confess "Group ".$self->canonical_group_id." is not stock process or stock recode! What is it?";
}

sub send_stock_check_to_prl {
    my ($self, $message_factory) = @_;

    # No need to send "stock_check" message to PRLs for groups related
    # to stock from "cancelled stock locations".
    # Each such group has as many items as were scanned into correspondent
    # container, so there isn't ground to raise "stock check".
    # For more details refer to DCA-1602 Jira ticket
    return 0 if $self->is_cancelled_group;

    my $prls = $self->prls or return;

    my $stock_check_data = {
        pgid   => $self->canonical_group_id,
        client => $self->client,
    };
    my $destinations = [
        map {
            XT::Domain::PRLs::get_amq_queue_from_prl_name({
                prl_name => $_,
            }) } keys %{$prls//{}}
    ];
    $message_factory->transform_and_send(
        'XT::DC::Messaging::Producer::PRL::StockCheck' => {
            stock_check  => $stock_check_data,
            destinations => $destinations,
        },
    );

    return 1;
}

sub client {
    my ($self) = @_;

    # PP Groups can't mix businesses, so we're safe just getting
    # the first inventory
    my $variant = $self->putaway_prep_inventories->first->variant_with_voucher;
    my $business = $variant->product->get_product_channel->channel->business;

    return $PRL_TYPE__CLIENT__JC if $business->id == $BUSINESS__JC;
    return $PRL_TYPE__CLIENT__NAP;
}

sub prls {
    my ($self) = @_;

    my $storage_types_for_group = {};
    my $stock_status_row = $self->get_stock_status_row;

    foreach my $papi ($self->putaway_prep_inventories) {
        my $variant = $papi->variant_with_voucher;
        my $storage_type = $variant->product->storage_type;
        $storage_types_for_group->{ $storage_type->name }{ $stock_status_row->name } = 1;
    }

    my $acceptable_prls = XT::Domain::PRLs::get_prls_for_storage_types_and_stock_statuses({
        prl_configs                        => config_var('PRL', 'PRLs'),
        storage_type_and_stock_status_hash => $storage_types_for_group,
    });

    return $acceptable_prls;
}

=head get_return_items( $variant_id? ): @return_item_rows

If this putaway prep group includes return items, return a list of them.
Otherwise, return an empty list.

Optionally accepts a variant_id. In that case, only returns return items that
match that variant.

=cut

sub get_return_items {
    my ($self, $variant_id) = @_;

    my @return_items = map  { $_->return_item }
                       grep { $_->is_returns }  $self->stock_processes;

    if ($variant_id) {
        @return_items = grep { $_->variant_id == $variant_id } @return_items;
    }

    return @return_items;
}

1;
