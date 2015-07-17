use utf8;
package XTracker::Schema::Result::Promotion::DetailProductTypes;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("event.detail_producttypes");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "event.detail_producttypes_id_seq",
  },
  "event_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "producttype_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(
  "detail_producttypes_detail_id_key",
  ["event_id", "producttype_id"],
);
__PACKAGE__->belongs_to(
  "detail",
  "XTracker::Schema::Result::Promotion::Detail",
  { id => "event_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "producttype",
  "XTracker::Schema::Result::Public::ProductType",
  { id => "producttype_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:JSua7AZXsNtrWY2cMflrYw

__PACKAGE__->add_unique_constraint(
    'join_data' => [qw/event_id producttype_id/]
);

use XTracker::SchemaHelper qw(:records);

1;
