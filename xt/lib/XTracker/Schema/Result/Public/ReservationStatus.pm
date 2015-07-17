use utf8;
package XTracker::Schema::Result::Public::ReservationStatus;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.reservation_status");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "reservation_status_id_seq",
  },
  "status",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "reservation_auto_change_log_post_status_ids",
  "XTracker::Schema::Result::Public::ReservationAutoChangeLog",
  { "foreign.post_status_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "reservation_auto_change_log_pre_status_ids",
  "XTracker::Schema::Result::Public::ReservationAutoChangeLog",
  { "foreign.pre_status_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "reservation_logs",
  "XTracker::Schema::Result::Public::ReservationLog",
  { "foreign.reservation_status_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "reservation_operator_logs",
  "XTracker::Schema::Result::Public::ReservationOperatorLog",
  { "foreign.reservation_status_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "reservations",
  "XTracker::Schema::Result::Public::Reservation",
  { "foreign.status_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:EQCxvTp2MrFT7vrng+XqJg


# You can replace this text with custom content, and it will be preserved on regeneration
1;
