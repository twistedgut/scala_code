use utf8;
package XTracker::Schema::Result::Fraud::LiveList;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("fraud.live_list");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "fraud.live_list_id_seq",
  },
  "list_type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 50 },
  "description",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "archived_list_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("live_list_name_key", ["name"]);
__PACKAGE__->belongs_to(
  "archived_list",
  "XTracker::Schema::Result::Fraud::ArchivedList",
  { id => "archived_list_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "list_type",
  "XTracker::Schema::Result::Fraud::ListType",
  { id => "list_type_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->has_many(
  "live_list_items",
  "XTracker::Schema::Result::Fraud::LiveListItem",
  { "foreign.list_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "staging_lists",
  "XTracker::Schema::Result::Fraud::StagingList",
  { "foreign.live_list_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Qij61+FsrJuxP6stuj/iNw

__PACKAGE__->has_many(
  'list_items',
  "XTracker::Schema::Result::Fraud::LiveListItem",
  { "foreign.list_id" => "self.id" },
  {},
);

use Moose;
with 'XTracker::Schema::Role::Result::FraudList';

1;
