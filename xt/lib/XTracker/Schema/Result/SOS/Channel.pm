use utf8;
package XTracker::Schema::Result::SOS::Channel;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("sos.channel");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "sos.channel_id_seq",
  },
  "name",
  { data_type => "text", is_nullable => 0 },
  "api_code",
  { data_type => "text", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("channel_api_code_key", ["api_code"]);
__PACKAGE__->add_unique_constraint("channel_name_key", ["name"]);
__PACKAGE__->might_have(
  "processing_time",
  "XTracker::Schema::Result::SOS::ProcessingTime",
  { "foreign.channel_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:lXnQA3T+XMeUFkFzCLs3Xw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
