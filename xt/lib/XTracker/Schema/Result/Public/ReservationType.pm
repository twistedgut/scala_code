use utf8;
package XTracker::Schema::Result::Public::ReservationType;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.reservation_type");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "reservation_type_id_seq",
  },
  "type",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "sort_order",
  { data_type => "integer", is_nullable => 0 },
  "is_active",
  { data_type => "boolean", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("reservation_type_sort_order_key", ["sort_order"]);
__PACKAGE__->add_unique_constraint("reservation_type_type_key", ["type"]);
__PACKAGE__->has_many(
  "pre_orders",
  "XTracker::Schema::Result::Public::PreOrder",
  { "foreign.reservation_type_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "reservations",
  "XTracker::Schema::Result::Public::Reservation",
  { "foreign.reservation_type_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Ng/EOacZmHDKHMzN1mwONg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
