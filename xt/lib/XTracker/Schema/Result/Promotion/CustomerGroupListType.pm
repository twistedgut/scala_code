use utf8;
package XTracker::Schema::Result::Promotion::CustomerGroupListType;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("event.customergroup_listtype");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "event.customergroup_listtype_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 50 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("customergroup_listtype_name_key", ["name"]);
__PACKAGE__->has_many(
  "detail_customergroupjoin_listtypes",
  "XTracker::Schema::Result::Promotion::DetailCustomerGroupJoinListType",
  { "foreign.customergroup_listtype_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "detail_customergroups",
  "XTracker::Schema::Result::Promotion::DetailCustomerGroup",
  { "foreign.listtype_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:RMgcS0VupsAepfqLPGY/sw

__PACKAGE__->add_unique_constraint(
    'join_data' => [qw/name/]
);

use XTracker::SchemaHelper qw(:records);

1;
