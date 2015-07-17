package XTracker::Script::PRL::InFlight;

use NAP::policy qw/class/;
extends 'XTracker::Script';

with 'XTracker::Script::Feature::SingleInstance',
     'XTracker::Script::Feature::Schema';

use XTracker::Constants::FromDB qw(
    :putaway_prep_group_status
);

use List::Util qw/first/;

=head1 NAME

XTracker::Script::PRL::InFlight

=head1 DESCRIPTION

Shows details of fulfilment and goods in processes that are still in progress
according to XT's database. For use during migration between PRLs, to make sure
things are in a clean state before migration happens.

=head1 METHODS

=head2 invoke

Run the queries to show all processes in flight.

=cut

sub invoke {
    my $self = shift;

    $self->show_shipments;
    $self->show_allocations;
    $self->show_orphan_containers;
    $self->show_putaway_prep;
    $self->show_channel_transfers;
}


=head2 show_shipments

Show shipments that are being processed.

=cut

sub show_shipments {
    my $self = shift;
    my $shipment_rs = $self->schema->resultset('Public::Shipment');

    my $shipments_being_processed = $shipment_rs->yet_to_be_dispatched->search(
        {},
        { prefetch => [ {'shipment_items'=> 'shipment_item_status' },'shipment_status' ] },
    );

    my $shipments_after_picking = $shipments_being_processed->with_items_between_picking_and_dispatch;
    $self->display_shipment_group('(at least partially) picked and not dispatched',$shipments_after_picking);

    my $shipments_partially_picked = $shipments_being_processed->with_items_selected;
    $self->display_shipment_group('selected and not completely picked',$shipments_partially_picked);
}

=head2 show_allocations

Show allocations that have started picking in any PRL and aren't yet complete.

=cut

sub show_allocations {
    my $self = shift;
    # The shipments check we already did should cover all these, but in case there's
    # anything in a strange state, check allocations too. Anything in "picking" status
    # is potentially still in progress in a PRL.
    my $allocations_in_picking = $self->schema->resultset('Public::Allocation')->
                                    filter_picking->
                                    search({}, {'order_by' => 'id'});
    say '';
    say 'Allocations being picked';
    while (my $a = $allocations_in_picking->next) {
        # If it doesn't have any active items (e.g. they're all short/cancelled), we don't care
        next if ($a->allocation_items->filter_active->count == 0);
        say sprintf 'Allocation %s (%s PRL, shipment %s)', $a->id, $a->prl->name, $a->shipment_id;
    }

    # We want the staging area to be empty
    my $allocations_in_staging = $self->schema->resultset('Public::Allocation')->
                                    filter_staged->
                                    search({}, {'order_by' => 'id'});
    say '';
    say 'Allocations in Full PRL staging area';
    while (my $a = $allocations_in_staging->next) {
        next if ($a->allocation_items->count == 0);
        say sprintf 'Allocation %s (shipment %s)', $a->id, $a->shipment_id;
    }

}

=head2 show_orphan_containers

Show containers that have orphan items in them (items not associated with
any shipment).

=cut

sub show_orphan_containers {
    my $self = shift;
    # We should have cleaned up containers with orphaned items too
    my $containers_with_orphans = $self->schema->resultset('Public::OrphanItem')->
                                    containers->
                                    search({}, {order_by => 'id'});
    say '';
    say 'Containers with orphaned items in them';
    while (my $c = $containers_with_orphans->next) {
        say '  Container ',$c->id;
    }

}

=head2 show_putaway_prep

Show anything that is still in progress at the putaway prep stage.

=cut

sub show_putaway_prep {
    my $self = shift;
    # Putaway prep:
    # During migration we don't mind what has happened in the goods in process
    # prior to the putaway prep stage, because it's only at putaway prep that we
    # assign anything to a particular PRL.

    # All active containers, sorted by when they were created
    my $active_putaway_prep_containers = $self->schema->resultset('Public::PutawayPrepContainer')->filter_active->search({},{order_by => 'created'});;

    # Find all active putaway prep containers with groups
    say '';
    say 'Putaway prep containers in progress';
    while (my $putaway_prep_container = $active_putaway_prep_containers->next) {
        # if it has no groups in it, we don't care
        next unless $putaway_prep_container->putaway_prep_groups->count;

        my ($group_column, $group_type) = $self->find_group_type($putaway_prep_container->putaway_prep_groups->first);
        say sprintf "%s (%ss): %s",
            $putaway_prep_container->container_id,
            $group_type,
            join(', ', map {$_->$group_column} $putaway_prep_container->putaway_prep_groups)
        ;
    }

    # Find any putaway prep groups in progress that don't have any active containers,
    # and so wouldn't be in the list above
    say '';
    say 'Putaway prep groups in progress with no active container';
    my $putaway_prep_groups = $self->schema->resultset('Public::PutawayPrepGroup')->search({
        status_id => {-in => [$PUTAWAY_PREP_GROUP_STATUS__IN_PROGRESS, $PUTAWAY_PREP_GROUP_STATUS__PROBLEM]},
        id        => {-not_in => $active_putaway_prep_containers->search_related('putaway_prep_inventories')->get_column('putaway_prep_group_id')->as_query},
    },{
        order_by => 'id'
    });
    while (my $putaway_prep_group = $putaway_prep_groups->next) {
        my ($group_column, $group_type) = $self->find_group_type($putaway_prep_group);
        say sprintf "%s (%s %s)",
            $putaway_prep_group->id,
            $group_type,
            $putaway_prep_group->$group_column
        ;
    }

}

=head2 show_putaway_prep

Show incomplete channel transfers.

=cut

sub show_channel_transfers {
    my $self = shift;
    # Complete all channel transfers before we start
    my $in_transfer = $self->schema->resultset('Public::ChannelTransfer')->between_selected_and_completed->product_ids;
    say '';
    say 'Products in channel transfers selected and not completed';
    while (my $t = $in_transfer->next) {
        say '  PID ',$t->product_id;
    }
}

sub display_shipment_group {
    my $self = shift;
    my ($heading,$shipment_rs) = @_;

    say '';
    say "Shipments $heading";
    $shipment_rs->reset;
    while (my $shipment_row = $shipment_rs->next) {
        my $shipment_details = sprintf 'Shipment %d (%s):',$shipment_row->id,$shipment_row->shipment_status->status;
        my @items;
        my $shipment_item_rs = $shipment_row->shipment_items;
        while (my $shipment_item_row = $shipment_item_rs->next) {
            push @items, sprintf 'item %d (%s)',$shipment_item_row->id,$shipment_item_row->shipment_item_status->status;
            if ($shipment_item_row->container_id) {
                $items[-1] .= sprintf ' in container %s',$shipment_item_row->container_id;
            }
        }
        say '  ',$shipment_details,' ',join ', ',@items;
    }
}

sub find_group_type {
    my $self = shift;
    my ($putaway_prep_group_row) = @_;

    # The putaway_prep_group table has a value in one of 4 columns for the group, depending
    # on the type (yes, this is a bit weird, and yes, we have a story to change that, but for
    # now this is what we have to deal with).
    my @putaway_prep_column_options = ('group_id', 'recode_id', 'putaway_prep_cancelled_group_id', 'putaway_prep_migration_group_id');

    my $group_column = first { $putaway_prep_group_row->$_ } @putaway_prep_column_options;
    my $group_type = ($group_column =~ /(.*)_id/)[0];
    return ($group_column, $group_type);

}
