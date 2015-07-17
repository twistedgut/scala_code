use utf8;
package XTracker::Schema::Result::Public::SalesConversionRate;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.sales_conversion_rate");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "sales_conversion_rate_id_seq",
  },
  "source_currency",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "destination_currency",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "conversion_rate",
  { data_type => "double precision", is_nullable => 0 },
  "date_start",
  { data_type => "timestamp", is_nullable => 0 },
  "date_finish",
  { data_type => "timestamp", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "destination_currency",
  "XTracker::Schema::Result::Public::Currency",
  { id => "destination_currency" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "source_currency",
  "XTracker::Schema::Result::Public::Currency",
  { id => "source_currency" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:DyEG6DQ3+jMICFHIcPdStA


# You can replace this text with custom content, and it will be preserved on regeneration
1;
