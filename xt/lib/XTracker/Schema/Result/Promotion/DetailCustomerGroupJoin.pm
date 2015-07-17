use utf8;
package XTracker::Schema::Result::Promotion::DetailCustomerGroupJoin;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("event.detail_customergroup_join");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "event.detail_customergroup_join_id_seq",
  },
  "type",
  { data_type => "varchar", is_nullable => 0, size => 10 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("detail_customergroup_join_type_key", ["type"]);
__PACKAGE__->has_many(
  "detail_customergroupjoin_listtypes",
  "XTracker::Schema::Result::Promotion::DetailCustomerGroupJoinListType",
  { "foreign.detail_customergroup_join_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:laHq9lqpn/VRe4QCnttRvQ

__PACKAGE__->add_unique_constraint(
    'join_data' => [qw/type/]
);

use XTracker::SchemaHelper qw(:records);


1;
