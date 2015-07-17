use utf8;
package XTracker::Schema::Result::Public::AuthorisationLevel;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.authorisation_level");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "authorisation_level_id_seq",
  },
  "description",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "operator_authorisations",
  "XTracker::Schema::Result::Public::OperatorAuthorisation",
  { "foreign.authorisation_level_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:f3Fl9OVIJluOIaWDH7cOrQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;