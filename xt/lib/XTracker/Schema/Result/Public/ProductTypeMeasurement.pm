use utf8;
package XTracker::Schema::Result::Public::ProductTypeMeasurement;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.product_type_measurement");
__PACKAGE__->add_columns(
  "product_type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "measurement_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "sort_order",
  { data_type => "integer", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("product_type_id", "measurement_id", "channel_id");
__PACKAGE__->belongs_to(
  "channel",
  "XTracker::Schema::Result::Public::Channel",
  { id => "channel_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "measurement",
  "XTracker::Schema::Result::Public::Measurement",
  { id => "measurement_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "product_type",
  "XTracker::Schema::Result::Public::ProductType",
  { id => "product_type_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ipcHbLJe97AWqF8L5mT/nA

1;
