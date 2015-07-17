use utf8;
package XTracker::Schema::Result::Promotion::PublishMethod;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("event.publish_method");
__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_nullable => 0 },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 20 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("publish_method_name_key", ["name"]);
__PACKAGE__->has_many(
  "details",
  "XTracker::Schema::Result::Promotion::Detail",
  { "foreign.publish_method_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:KkY57u4M+8nDhEJYJxEBug


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
