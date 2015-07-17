use utf8;
package XTracker::Schema::Result::ACL::AuthorisationRole;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("acl.authorisation_role");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "acl.authorisation_role_id_seq",
  },
  "authorisation_role",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(
  "authorisation_role_authorisation_role_key",
  ["authorisation_role"],
);
__PACKAGE__->has_many(
  "link_authorisation_role__authorisation_sub_sections",
  "XTracker::Schema::Result::ACL::LinkAuthorisationRoleAuthorisationSubSection",
  { "foreign.authorisation_role_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "link_authorisation_role__url_paths",
  "XTracker::Schema::Result::ACL::LinkAuthorisationRoleURLPath",
  { "foreign.authorisation_role_id" => "self.id" },
  undef,
);
__PACKAGE__->many_to_many(
  "authorisation_sub_sections",
  "link_authorisation_role__authorisation_sub_sections",
  "authorisation_sub_section",
);
__PACKAGE__->many_to_many("url_paths", "link_authorisation_role__url_paths", "url_path");


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:K+58HPs8b4FaSVdQFxFHUg

1;
