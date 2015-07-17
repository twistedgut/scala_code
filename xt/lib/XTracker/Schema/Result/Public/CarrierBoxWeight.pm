use utf8;
package XTracker::Schema::Result::Public::CarrierBoxWeight;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.carrier_box_weight");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "carrier_box_weight_id_seq",
  },
  "carrier_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "box_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "service_name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "weight",
  { data_type => "numeric", is_nullable => 0, size => [6, 2] },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(
  "cbw_unique_idx",
  ["carrier_id", "box_id", "channel_id", "service_name"],
);
__PACKAGE__->belongs_to(
  "box",
  "XTracker::Schema::Result::Public::Box",
  { id => "box_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "carrier",
  "XTracker::Schema::Result::Public::Carrier",
  { id => "carrier_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "channel",
  "XTracker::Schema::Result::Public::Channel",
  { id => "channel_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:JROxkZPgv40JFWrYTbByKQ

# gives us $self->data_as_hash() for Public::ShipmentBox error messages
use XTracker::SchemaHelper qw(:records);

1;
