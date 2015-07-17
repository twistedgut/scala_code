use utf8;
package XTracker::Schema::Result::Public::IntegrationContainer;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.integration_container");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "integration_container_id_seq",
  },
  "container_id",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 0, size => 255 },
  "prl_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "from_prl_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "is_complete",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "completed_at",
  { data_type => "timestamp with time zone", is_nullable => 1 },
  "routed_at",
  { data_type => "timestamp with time zone", is_nullable => 1 },
  "arrived_at",
  { data_type => "timestamp with time zone", is_nullable => 1 },
  "created_at",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "modified_at",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "container",
  "XTracker::Schema::Result::Public::Container",
  { id => "container_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "from_prl",
  "XTracker::Schema::Result::Public::Prl",
  { id => "from_prl_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->has_many(
  "integration_container_items",
  "XTracker::Schema::Result::Public::IntegrationContainerItem",
  { "foreign.integration_container_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "prl",
  "XTracker::Schema::Result::Public::Prl",
  { id => "prl_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:1nFP1xjmUDZRzA8Lk+Eimw


use MooseX::Params::Validate qw( validated_list pos_validated_list );
use List::Util qw( first );
use XT::Data::PRL::Conveyor::Route::ToPacking;
use XTracker::Constants qw(
    :application
);

=head2 allocation_items() : $allocation_item_rs

Return resultset of allocation items associated with current record

=cut

sub allocation_items {
    my $self = shift;

    return $self
        ->integration_container_items
        ->filter_non_missing
        ->search_related(
            allocation_item => undef,
            {
                order_by => {-desc => 'allocation_item.delivery_order'},
            }
        );
}

=head2 mark_has_arrived_at_integration() : 1 | 0

Mark the integration container as having arrived at integration.

Return 0 if arrived_at is already set on the integration_container - if
that's the case then we don't need to do anything and we don't want to
overwrite the arrived_at timestamp.

Return 1 if we have set the timestamp.

=cut

sub mark_has_arrived_at_integration {
    my $self = shift;

    return 0 if $self->arrived_at;

    $self->update({
        arrived_at  => \'now()',
    });

    return 1;
}

=head2 mark_as_complete( :operator_id? ): 1

Mark current integration container record as complete.

Set the allocation status to picked for all allocations in the container,
but ONLY if all items from the allocation have been done,

not if there are still some items on hooks,

not if there are still some items in other uncompleted integration containers.

Operator ID is optional and if it is not defined it defaults to
operator_id attribute on schema object, and if it in its turn
undefined as well - Application operator ID is used.

=cut

sub mark_as_complete {
    my $self = shift;
    my $schema = $self->result_source->schema;
    my ($operator_id) = validated_list(\@_,
        operator_id => {
            isa      => 'Int',
            optional => 1,
            default  => $schema->operator_id || $APPLICATION_OPERATOR_ID,
        },
    );

    my @allocations_in_container = $self->allocation_items
        ->search_related(
            allocation => undef,
            {
                prefetch => 'allocation_items',
            }
        );

    my @allocations_to_update;

    foreach my $allocation (@allocations_in_container) {

        # skip allocations that have items not yet integrated
        next if $allocation
            ->allocation_items
            ->filter_delivered
            ->filter_non_integrated
            ->count;

        # skip allocations that have items in other incomplete
        # integration container
        next if $allocation
            ->allocation_items
            ->filter_delivered
            ->search_related( integration_container_items => {
                'integration_container.is_complete' => 0,
                'integration_container.id' => {'!=' => $self->id},
            },{
                join => 'integration_container',
            })
            ->count;

        push @allocations_to_update, $allocation;

    }

    $schema->txn_do(sub{
        # update complete and completed_at for the integration_container
        $self->update({
            is_complete  => 1,
            completed_at => $schema->db_now_raw,
        });

        $schema->resultset('Public::Allocation')
            ->search({
                id => [map {$_->id} @allocations_to_update],
            })
            ->update_to_picked( $operator_id );
    });

    $self->route_to_packing;

    return 1;
}

=head2 move_items_from_missing_container( :$source_container_row ) : 1

Move content of source_container_row into curent one and mark
source_container_row as complete.

=cut

sub move_items_from_missing_container {
    my ($self, $source_container_row) = validated_list(\@_,
        source_container_row => {
            isa => 'XTracker::Schema::Result::Public::IntegrationContainer',
        },
    );

    my $schema = $self->result_source->schema;

    my @items_to_move = $source_container_row->allocation_items;

    $schema->txn_do(sub{

        $source_container_row->integration_container_items->delete;

        $source_container_row->update({
            is_complete  => 1,
            completed_at => $schema->db_now_raw,
        });

        $_->add_to_integration_container({
            integration_container => $self,
            is_missing            => 1,
        }) for @items_to_move;
    });

    return 1;
}

=head2 route_to_packing() : undef

Route current container to Packing.

=cut

sub route_to_packing {
    my $self = shift;

    my $route = XT::Data::PRL::Conveyor::Route::ToPacking->new({
        container_id => $self->container_id
    });

    $route->send;

    return undef;
}

=head2 mix_group : $integration_mix_group_string | ''

Return picking mix group for stock inside integration
container.

There should be only one mix group within container.

=cut

sub mix_group {
    my $self = shift;

    # If container is empty no way to find mix group
    return '' unless $self->allocation_items->count;

    # Integration container could not contain more than
    # one mix group, so it is enough to get any allocation
    return $self
        ->allocation_items->first
        ->allocation
        ->integration_mix_group;
}

=head2 remove_sku( $sku ) : bool

Remove provided SKU from current integration container.

Return true if item was removed, and false - otherwise.

=cut

sub remove_sku {
    my $self = shift;

    my ($sku) = pos_validated_list(\@_,
        { isa => 'Str'}
    );

    my $allocation_item = first
        {$sku eq $_->shipment_item->get_sku}
        $self->allocation_items->all;

    # SKU is not found in current container
    return undef unless $allocation_item;

    # remove item records
    $self->integration_container_items->search({
        allocation_item_id => $allocation_item->id,
    })->delete;

    # The SKU was removed from the integration container
    # so corresponding shipment item should not relate to the
    # container ID of current integration container ID
    $allocation_item->shipment_item->update({container_id => undef});

    # container is empty: remove its record
    $self->delete unless $self->integration_container_items->count;

    return 1;
}

1;
