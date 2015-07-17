use utf8;
package XTracker::Schema::Result::Public::AuthorisationSection;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.authorisation_section");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "authorisation_section_id_seq",
  },
  "section",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("unique_section_name", ["section"]);
__PACKAGE__->has_many(
  "sub_section",
  "XTracker::Schema::Result::Public::AuthorisationSubSection",
  { "foreign.authorisation_section_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:6JqWFj4tk7OJEceK7cSx/A


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
