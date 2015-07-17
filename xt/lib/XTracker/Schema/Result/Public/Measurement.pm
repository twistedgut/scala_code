use utf8;
package XTracker::Schema::Result::Public::Measurement;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.measurement");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "measurement_id_seq",
  },
  "measurement",
  { data_type => "varchar", is_nullable => 1, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("measurement_measurement_key", ["measurement"]);
__PACKAGE__->has_many(
  "product_type_measurements",
  "XTracker::Schema::Result::Public::ProductTypeMeasurement",
  { "foreign.measurement_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "show_measurements",
  "XTracker::Schema::Result::Public::ShowMeasurement",
  { "foreign.measurement_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "variant_measurements",
  "XTracker::Schema::Result::Public::VariantMeasurement",
  { "foreign.measurement_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:tUdT5lmYDWjwMd0icYu5cw


__PACKAGE__->many_to_many(
    'product_types', 'product_type_measurements' => 'product_type'
);

1;
