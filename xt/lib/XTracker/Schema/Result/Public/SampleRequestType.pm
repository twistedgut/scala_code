use utf8;
package XTracker::Schema::Result::Public::SampleRequestType;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.sample_request_type");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "sample_request_type_id_seq",
  },
  "code",
  { data_type => "varchar", is_nullable => 0, size => 10 },
  "type",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "bookout_location_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "source_location_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("sample_request_type_type_key", ["type"]);
__PACKAGE__->add_unique_constraint("uidx_sample_request_type__code", ["code"]);
__PACKAGE__->belongs_to(
  "bookout_location",
  "XTracker::Schema::Result::Public::Location",
  { id => "bookout_location_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "source_location",
  "XTracker::Schema::Result::Public::Location",
  { id => "source_location_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:BjqD7HguMp63ebKp2UUwOw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
