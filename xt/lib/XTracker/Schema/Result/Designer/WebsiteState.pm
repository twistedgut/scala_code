use utf8;
package XTracker::Schema::Result::Designer::WebsiteState;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("designer.website_state");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "designer.website_state_id_seq",
  },
  "state",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("website_state_state_key", ["state"]);
__PACKAGE__->has_many(
  "designer_channels",
  "XTracker::Schema::Result::Public::DesignerChannel",
  { "foreign.website_state_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "logs_from_state",
  "XTracker::Schema::Result::Designer::LogWebsiteState",
  { "foreign.from_value" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "logs_to_state",
  "XTracker::Schema::Result::Designer::LogWebsiteState",
  { "foreign.to_value" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:xjHCMSwBLy34XO6pOezP0g


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
