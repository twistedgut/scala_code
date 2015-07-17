use utf8;
package XTracker::Schema::Result::SOS::Region;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("sos.region");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "sos.region_id_seq",
  },
  "country_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 0 },
  "api_code",
  { data_type => "text", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("region_api_code_key", ["country_id", "api_code"]);
__PACKAGE__->belongs_to(
  "country",
  "XTracker::Schema::Result::SOS::Country",
  { id => "country_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->might_have(
  "processing_time",
  "XTracker::Schema::Result::SOS::ProcessingTime",
  { "foreign.region_id" => "self.id" },
  undef,
);
__PACKAGE__->might_have(
  "wms_priority",
  "XTracker::Schema::Result::SOS::WmsPriority",
  { "foreign.region_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:14cOU+JWRbbJaSX/+SVQ6A


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
