use utf8;
package XTracker::Schema::Result::Public::WelcomePackChange;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.welcome_pack_change");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "welcome_pack_change_id_seq",
  },
  "change",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("welcome_pack_change_change_key", ["change"]);
__PACKAGE__->has_many(
  "log_welcome_pack_changes",
  "XTracker::Schema::Result::Public::LogWelcomePackChange",
  { "foreign.welcome_pack_change_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:XcdcZ/hYaRplZ08ZGCZ0YA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
