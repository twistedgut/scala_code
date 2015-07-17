use utf8;
package XTracker::Schema::Result::Public::IntegrationContainerItem;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.integration_container_item");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "integration_container_item_id_seq",
  },
  "integration_container_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "allocation_item_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
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
  "status_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "allocation_item",
  "XTracker::Schema::Result::Public::AllocationItem",
  { id => "allocation_item_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "integration_container",
  "XTracker::Schema::Result::Public::IntegrationContainer",
  { id => "integration_container_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "status",
  "XTracker::Schema::Result::Public::IntegrationContainerItemStatus",
  { id => "status_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:gQ6YhbV57cO9XIec4Q+3Ug

use XTracker::Constants::FromDB qw/
    :integration_container_item_status
/;

=head2 is_picked() : bool

Return true if current item was picked by DCD prl.

=cut

sub is_picked {
    my $self = shift;

    return $self->status_id == $INTEGRATION_CONTAINER_ITEM_STATUS__PICKED;
}

=head2 is_integrated() : bool

Return true if current item was integrated at GOH Integration for instance.

=cut

sub is_integrated {
    my $self = shift;

    return $self->status_id == $INTEGRATION_CONTAINER_ITEM_STATUS__INTEGRATED;
}

=head2 is_missing() : bool

Return true if current item was marked as missing at Integration point (GOH).

=cut

sub is_missing {
    my $self = shift;

    return $self->status_id == $INTEGRATION_CONTAINER_ITEM_STATUS__MISSING;
}


1;
