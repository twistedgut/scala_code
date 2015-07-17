use utf8;
package XTracker::Schema::Result::Public::ReservationLog;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.reservation_log");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "reservation_log_id_seq",
  },
  "reservation_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "reservation_status_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "operator_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "date",
  { data_type => "timestamp", is_nullable => 0 },
  "quantity",
  { data_type => "integer", is_nullable => 0 },
  "balance",
  { data_type => "integer", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "operator",
  "XTracker::Schema::Result::Public::Operator",
  { id => "operator_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "reservation",
  "XTracker::Schema::Result::Public::Reservation",
  { id => "reservation_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "reservation_status",
  "XTracker::Schema::Result::Public::ReservationStatus",
  { id => "reservation_status_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:jb62+gfZXco16ZngdpMmxA


# You can replace this text with custom content, and it will be preserved on regeneration
1;
