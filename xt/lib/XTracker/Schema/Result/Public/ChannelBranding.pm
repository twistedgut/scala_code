use utf8;
package XTracker::Schema::Result::Public::ChannelBranding;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.channel_branding");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "channel_branding_id_seq",
  },
  "channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "branding_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "value",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(
  "idx_channel_branding__channel_id__branding_id",
  ["channel_id", "branding_id"],
);
__PACKAGE__->belongs_to(
  "branding",
  "XTracker::Schema::Result::Public::Branding",
  { id => "branding_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "channel",
  "XTracker::Schema::Result::Public::Channel",
  { id => "channel_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:A27oeZ6dbN4SllKTopxdOg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
