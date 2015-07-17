use utf8;
package XTracker::Schema::Result::Public::ReservationSource;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.reservation_source");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "reservation_source_id_seq",
  },
  "source",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "sort_order",
  { data_type => "integer", is_nullable => 0 },
  "is_active",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("reservation_source_sort_order_key", ["sort_order"]);
__PACKAGE__->add_unique_constraint("reservation_source_source_key", ["source"]);
__PACKAGE__->has_many(
  "pre_orders",
  "XTracker::Schema::Result::Public::PreOrder",
  { "foreign.reservation_source_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "reservations",
  "XTracker::Schema::Result::Public::Reservation",
  { "foreign.reservation_source_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:DjDCdbd8emP4RBQKCddM/A


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
