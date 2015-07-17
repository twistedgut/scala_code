use utf8;
package XTracker::Schema::Result::Public::VariantMeasurement;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.variant_measurement");
__PACKAGE__->add_columns(
  "variant_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "measurement_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "value",
  { data_type => "numeric", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("variant_id", "measurement_id");
__PACKAGE__->belongs_to(
  "measurement",
  "XTracker::Schema::Result::Public::Measurement",
  { id => "measurement_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "variant",
  "XTracker::Schema::Result::Public::Variant",
  { id => "variant_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Zew5hCsFdTSknIuWn3XJgQ
# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
