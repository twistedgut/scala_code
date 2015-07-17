use utf8;
package XTracker::Schema::Result::Promotion::DetailCustomerGroup;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("event.detail_customergroup");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "event.detail_customergroup_id_seq",
  },
  "event_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "customergroup_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "listtype_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(
  "detail_customergroup_detail_id_key",
  ["event_id", "customergroup_id"],
);
__PACKAGE__->belongs_to(
  "customergroup",
  "XTracker::Schema::Result::Promotion::CustomerGroup",
  { id => "customergroup_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "detail",
  "XTracker::Schema::Result::Promotion::Detail",
  { id => "event_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "listtype",
  "XTracker::Schema::Result::Promotion::CustomerGroupListType",
  { id => "listtype_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Q1zIRDBOoPsJddCPCv6uEQ

__PACKAGE__->add_unique_constraint(
    'join_data' => [qw/event_id customergroup_id/]
);

use XTracker::SchemaHelper qw(:records);

1;
