use utf8;
package XTracker::Schema::Result::Public::DesignerChannel;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.designer_channel");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "designer_channel_id_seq",
  },
  "designer_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "page_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "website_state_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "description",
  { data_type => "text", is_nullable => 1 },
  "description_is_live",
  { data_type => "boolean", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(
  "designer_channel_designer_id_key",
  ["designer_id", "channel_id"],
);
__PACKAGE__->belongs_to(
  "channel",
  "XTracker::Schema::Result::Public::Channel",
  { id => "channel_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "designer",
  "XTracker::Schema::Result::Public::Designer",
  { id => "designer_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "page",
  "XTracker::Schema::Result::WebContent::Page",
  { id => "page_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "website_state",
  "XTracker::Schema::Result::Designer::WebsiteState",
  { id => "website_state_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:xsF+zdR/JZFLIx5RJ7I/LA

1;
