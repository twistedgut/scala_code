use utf8;
package XTracker::Schema::Result::Public::ShowMeasurement;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.show_measurement");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "show_measurement_id_seq",
  },
  "product_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "measurement_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("show_measurement_uix", ["product_id", "measurement_id"]);
__PACKAGE__->belongs_to(
  "measurement",
  "XTracker::Schema::Result::Public::Measurement",
  { id => "measurement_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "product",
  "XTracker::Schema::Result::Public::Product",
  { id => "product_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:jz0V1Vmn8j9xRcqQY1PRAg

__PACKAGE__->add_unique_constraint(
    show_measurement_product_id_measurement_id =>
        [
            qw{ product_id measurement_id }
        ],
  );

1;
