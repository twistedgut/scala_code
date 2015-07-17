use utf8;
package XTracker::Schema::Result::SOS::ProcessingTimeOverride;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("sos.processing_time_override");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "sos.processing_time_override_id_seq",
  },
  "major_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "minor_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "major",
  "XTracker::Schema::Result::SOS::ProcessingTime",
  { id => "major_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "minor",
  "XTracker::Schema::Result::SOS::ProcessingTime",
  { id => "minor_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:rXR6owB1nxCSWzCFfFJvgA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
