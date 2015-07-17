use utf8;
package XTracker::Schema::Result::Flow::Status;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("flow.status");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "flow.status_id_seq",
  },
  "name",
  { data_type => "text", is_nullable => 0 },
  "type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "is_initial",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("status_name_key", ["name", "type_id"]);
__PACKAGE__->has_many(
  "location_allowed_statuses",
  "XTracker::Schema::Result::Public::LocationAllowedStatus",
  { "foreign.status_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "next_status",
  "XTracker::Schema::Result::Flow::NextStatus",
  { "foreign.current_status_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "prev_status",
  "XTracker::Schema::Result::Flow::NextStatus",
  { "foreign.next_status_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "quantities",
  "XTracker::Schema::Result::Public::Quantity",
  { "foreign.status_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "rtv_quantities",
  "XTracker::Schema::Result::Public::RTVQuantity",
  { "foreign.status_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "type",
  "XTracker::Schema::Result::Flow::Type",
  { id => "type_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->many_to_many("list_next_status", "next_status", "next_status");
__PACKAGE__->many_to_many("list_prev_status", "prev_status", "current_status");
__PACKAGE__->many_to_many("locations", "location_allowed_statuses", "location");


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:J2FSwajB7ytcHAYaF3d6tQ

use Scalar::Util 'blessed';
use XTracker::Constants::FromDB qw( :flow_status );

sub is_valid_next {
    my ($self, $id) = @_;

    $id=$id->id if blessed($id) && $id->can('id');

    return $self if $self->id == $id; # staying the same is a valid next status

    return $self->search_related('next_status',{next_status_id => $id})->count;
}

{
my %iws_stock_status=(
    $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS   => 'main',
    $FLOW_STATUS__SAMPLE__STOCK_STATUS       => 'sample',
    $FLOW_STATUS__RTV_GOODS_IN__STOCK_STATUS => 'faulty',
    $FLOW_STATUS__RTV_PROCESS__STOCK_STATUS  => 'rtv',
    $FLOW_STATUS__DEAD_STOCK__STOCK_STATUS   => 'dead',
    $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS => 'sample',
);
sub iws_name {
    return $iws_stock_status{shift->id};
}
}

1;
