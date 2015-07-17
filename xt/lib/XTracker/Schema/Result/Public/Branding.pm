use utf8;
package XTracker::Schema::Result::Public::Branding;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.branding");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "branding_id_seq",
  },
  "code",
  { data_type => "varchar", is_nullable => 0, size => 50 },
  "description",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("idx_branding__code", ["code"]);
__PACKAGE__->has_many(
  "channel_brandings",
  "XTracker::Schema::Result::Public::ChannelBranding",
  { "foreign.branding_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ohSaWCnHJV+TtGSYNu9Abg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
