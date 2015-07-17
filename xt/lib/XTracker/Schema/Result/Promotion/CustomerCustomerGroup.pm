use utf8;
package XTracker::Schema::Result::Promotion::CustomerCustomerGroup;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("event.customer_customergroup");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "event.customer_customergroup_id_seq",
  },
  "customer_id",
  { data_type => "integer", is_nullable => 0 },
  "customergroup_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "website_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "created",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "created_by",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "modified",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "modified_by",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(
  "customer_customergroup_customer_id_key",
  ["customer_id", "customergroup_id", "website_id"],
);
__PACKAGE__->belongs_to(
  "created",
  "XTracker::Schema::Result::Public::Operator",
  { id => "created_by" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "customergroup",
  "XTracker::Schema::Result::Promotion::CustomerGroup",
  { id => "customergroup_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "modified",
  "XTracker::Schema::Result::Public::Operator",
  { id => "modified_by" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "website",
  "XTracker::Schema::Result::Promotion::Website",
  { id => "website_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:dxeMOBuqfgthllRkU4Ld5w

__PACKAGE__->add_unique_constraint(
    'join_data' => [qw/customer_id customergroup_id website_id/]
);

use XTracker::SchemaHelper qw(:records);

1;
