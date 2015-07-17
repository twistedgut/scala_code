use utf8;
package XTracker::Schema::Result::Promotion::ProductVisibility;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("event.product_visibility");
__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_nullable => 0 },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 20 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("product_visibility_name_key", ["name"]);
__PACKAGE__->has_many(
  "detail_announce_to_start_visibilities",
  "XTracker::Schema::Result::Promotion::Detail",
  { "foreign.announce_to_start_visibility" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "detail_end_to_close_visibilities",
  "XTracker::Schema::Result::Promotion::Detail",
  { "foreign.end_to_close_visibility" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "detail_publish_to_announce_visibilities",
  "XTracker::Schema::Result::Promotion::Detail",
  { "foreign.publish_to_announce_visibility" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "detail_start_to_end_visibilities",
  "XTracker::Schema::Result::Promotion::Detail",
  { "foreign.start_to_end_visibility" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ncs5VyHaf5zPv4aSzw9iyQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
