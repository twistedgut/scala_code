package XTracker::Schema::ResultSet::Public::Container;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;
use base 'DBIx::Class::ResultSet';

use Lingua::EN::Inflect qw/ PL /;

#
# DANGER WILL ROBINSON!!
#
# These two use statements *must* in the order
#
#    use ...Container
#    use ...FromDB
#
# otherwise you get
#
#   'Undefined subroutine &XTracker::Schema::ResultSet::Public::Container::get_commissioner_name'
#
# when in_commissioner is invoked.  Only Doctor Smith knows why.
#


use XTracker::Database::Container qw( :naming );
use XTracker::Constants::FromDB   qw(
    :allocation_item_status
    :allocation_status
    :container_status
    :shipment_item_status
);

use NAP::DC::Barcode::Container::PigeonHole;

=head1 METHODS

=head2 find_by_container_or_shipment_id($container_or_shipment_id) : $container_row | undef

Find a Container using $container_or_shipment_id.

Return either the specified $container_row, or any Container for the
Shipment, or undef if none was found.

=cut

sub find_by_container_or_shipment_id {
    my ($self, $container_or_shipment_id) = @_;
    my $schema = $self->result_source->schema;

    my $container_row = $schema->find(Container => $container_or_shipment_id);
    return $container_row if $container_row;

    $container_or_shipment_id =~ /^ \d+ $/x or return undef;
    my $shipment_row = $schema->find(Shipment => $container_or_shipment_id)
        or return undef;

    return $shipment_row->containers->search(
        {},
        { order_by => "id" },  # For predictability only
    )->first;                  # Might be undef, and that's fine
}

=head2 contains_packable() : Bool

Whether the Container contains any packable ShipmentItems.

For each container in result set, confirm if it contains any packable
shipment_items. If any packable shipment_items are found in any
container in the resultset, return false.

=cut

sub contains_packable {
    my $self = shift;

    $self->reset;
    while (my $con = $self->next){
        my $sis = $con->shipment_items;
        while (my $si = $sis->next){
            # really of course, anything packable should be in 'picked' state,
            # but we'll be a bit more tolerent here. May need to tighten up
            # if this becomes a problem
            return 1
                if ( $si->shipment_item_status_id == $SHIPMENT_ITEM_STATUS__NEW
                  || $si->shipment_item_status_id == $SHIPMENT_ITEM_STATUS__SELECTED
                  || $si->shipment_item_status_id == $SHIPMENT_ITEM_STATUS__PICKED );
        }
    }
    $self->reset;
    return 0;
}

=head2 filter_has_packlane() : $container_rs

Filter containers that has a PackLane assigned (and are either on
their way there, or has arrived at the pack lane).

=cut

sub filter_has_packlane {
    my $self = shift;
    $self->search({ pack_lane_id => { "!=" => undef } });
}

=head2 filter_has_allocated_pack_space() : $container_rs

Filter Containers that have allocated pack space (on account having a
PackLane assigned).

=cut

sub filter_has_allocated_pack_space {
    my $self = shift;
    $self->filter_has_packlane();
}

=head2 filter_without_container($container_row) : $container_rs | @container_rows

Filter the resultset so it doesn't contain the $container_row

=cut

sub filter_without_container {
    my ($self, $container_row) = @_;
    $self->search({ "me.id" => { "!=" => $container_row->id } });
}

=head2 in_commissioner

Gets all containers currently in the commissioner area. That is all rows of
public.container with place = 'Commissioner'

=cut

sub in_commissioner {
    return shift->search({ place => get_commissioner_name() });
}


sub send_to_commissioner {
    my $self = shift;

    $self->reset;

    while (my $container = $self->next) {
        $container->send_to_commissioner;
    }

    $self->reset;
}

=head2 clear_physical_place() : $row

Update physical_place_id for all the Containers in the ResultSet so
they aren't in any particular Physical Place.

=cut

sub clear_physical_place {
    my $self = shift;
    return $self->update({ physical_place_id => undef });
}

=head2 filter_packing_exception() : $container_rs

Filter the resultset to Containers which contain PackingException items.

(Where status_id is PackingExecptionItems).

=cut

sub filter_packing_exception {
    my $self = shift;
    return $self->search(
        { status_id => $PUBLIC_CONTAINER_STATUS__PACKING_EXCEPTION_ITEMS },
    );
}

=head2 pigeonholes

Return containers that are pigeonholes.

=cut

sub pigeonholes {
    my $self = shift;
    my $sql_like = NAP::DC::Barcode::Container::PigeonHole->valid_sql_like;
    return $self->search({
        id => \"like '$sql_like'",
    });
}

=head2 display_sorted_rs

Return containers that are sorted for display.

=cut

sub display_sorted_rs {
    my ($self) = @_;

    return $self->search_rs(
                    undef,
                    { order_by => [ {'-desc' => 'me.has_arrived'},
                                    'me.routed_at',
                                    'me.id' ],
                    }
                  );
}

=head2 prepare_induction_page_data() : \@sorted_container_data

Return an ordered list of containers for display on the induction
page, including shipment id, SLA and item count information for the
shipments in each container.

Note: The whole induction process is a "temporary" thing for DC2 only while
we're running with the Full PRL and Dematic. See DCA-956 for details.

=cut

sub prepare_induction_page_data {
    my $self = shift;

    # Get the container ids we're interested in (with associated SLAs).
    return[
        map {
            my $container_row = $_;
            my $shipment_item_count = $container_row->shipment_item_count;

            +{
                id                => $container_row->id,
                has_cage_items    => $container_row->has_cage_items,
                cutoff            => $container_row->get_column('cutoff'),
                cutoff_diff       => $container_row->get_column('cutoff_diff'),
                cutoff_epoch      => $container_row->get_column('cutoff_epoch'),
                shipments_summary =>
                    $self->_shipments_summary($shipment_item_count),
                shipment_ids_key  =>
                    $self->_shipment_ids_key($shipment_item_count),
            };
        }
        $self->filter_is_ready_for_packing->all
    ];
}

=head2 _shipments_summary($shipment_item_count)  : $summary_string

Return summary of the Shipments in the $shipment_item_count along with
how many Shipment Items in each of them.

$shipment_item_count - keys: shipment_ids; values: Shipment Item count

Example:

  "52344: 1 item; 3423: 1 item"
  "233: 4 items"

=cut

sub _shipments_summary {
    my ($self, $shipment_item_count) = @_;

    return join(
        "; ",
        map {
            my $count = $shipment_item_count->{$_};
            "$_: $count " . PL("item", $count);
        }
        sort { $a <=> $b } keys %$shipment_item_count,
     );
}

=head2 _shipment_ids_key($shipment_item_count)  : $shipment_ids_key

Return identifying key for the list of Shipments in
$shipment_item_count (see _shipments_summary).

=cut

sub _shipment_ids_key {
    my ($self, $shipment_item_count) = @_;
    return join("\t", sort keys %$shipment_item_count);
}

=head2 contains_staged_allocations() : Bool

Whether these Containers contain any Shipment Items which has an
Allocation which is in Staged status.

=cut

sub contains_staged_allocations {
    my $self = shift;
    return !! $self->filter_contains_staged_allocations->count();
}

=head2 filter_contains_staged_allocations() : $container_rs | @container_rows

Return Containers which contain any Shipment Items which have an
Allocation which is in Staged status.

=cut

sub filter_contains_staged_allocations {
    my $self = shift;
    return $self->search(
        {
            "allocation.status_id" => $ALLOCATION_STATUS__STAGED,
            "allocation_items.status_id" => $ALLOCATION_ITEM_STATUS__PICKED,
        },
        {
            join => {
                "shipment_items" => {
                    "allocation_items" => "allocation"
                }
            },
        },
    );
}

=head2 contains_pre_integration_allocations() : Bool

Whether these Containers contain any Shipment Items which have an
Allocation which is in a status that means it is awaiting integration.

=cut

sub contains_pre_integration_allocations {
    my $self = shift;
    return !! $self->filter_contains_pre_integration_allocations->count();
}

=head2 filter_contains_pre_integration_allocations() : $container_rs | @container_rows

Return Containers which contain any Shipment Items which have an
Allocation which is in a status that means it is awaiting integration.

=cut

sub filter_contains_pre_integration_allocations {
    my $self = shift;
    return $self->search(
        {
            "allocation.status_id" => [
                $ALLOCATION_STATUS__ALLOCATING_PACK_SPACE,
                $ALLOCATION_STATUS__DELIVERED,
                $ALLOCATION_STATUS__DELIVERING,
                $ALLOCATION_STATUS__PREPARED,
                $ALLOCATION_STATUS__PREPARING,
            ],
            "allocation_items.status_id" => $ALLOCATION_ITEM_STATUS__PICKED,
        },
        {
            join => {
                "shipment_items" => {
                    "allocation_items" => "allocation"
                }
            },
        },
    );
}

=head2 filter_is_ready_for_packing() : $container_rs | @container_rows

Return Containers that are staged (in the Staging Area) and ready for
induction.

Fetch a distinct list of Containers, ordered by the mininum sla_cutoff
value of their associated Shipments.

The query will return the additional columns from the Shipment:

* cutoff
* cutoff_diff
* cutoff_epoch

=cut

sub filter_is_ready_for_packing {
    my $self = shift;
    return $self->search(
        { "allocation.status_id" => $ALLOCATION_STATUS__STAGED },
        {
            join => {
                shipment_items => [
                    { allocation_items => "allocation" },
                    "shipment",
                ],
            },
            distinct  => 1,
            '+select' => [
                {
                    -as => 'cutoff',
                    min => 'shipment.sla_cutoff',
                },
                {
                    -as => 'cutoff_diff',
                    min => \"date_trunc('second',shipment.sla_cutoff - current_timestamp)",
                },
                {
                    -as => 'cutoff_epoch',
                    min => \"extract(epoch from (shipment.sla_cutoff - current_timestamp))",
                },
                {
                    -as => 'min_shipment_id',
                    min => 'shipment.id',
                },
            ],
            order_by => [
                'cutoff',
                'min_shipment_id',
                'me.id',
            ],
        },
    );
}


=head2 shipments : $shipment_rs

Return distinct shipments which have one or all of their items in
these containers.

=cut

sub shipments {
    my $self = shift;
    return $self
        ->related_resultset('shipment_items')
        ->search_related_rs(
            'shipment',
            {},
            {distinct => 1}
        );
}


1;
