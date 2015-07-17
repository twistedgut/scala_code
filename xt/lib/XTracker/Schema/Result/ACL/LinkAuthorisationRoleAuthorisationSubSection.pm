use utf8;
package XTracker::Schema::Result::ACL::LinkAuthorisationRoleAuthorisationSubSection;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("acl.link_authorisation_role__authorisation_sub_section");
__PACKAGE__->add_columns(
  "authorisation_role_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "authorisation_sub_section_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("authorisation_role_id", "authorisation_sub_section_id");
__PACKAGE__->belongs_to(
  "authorisation_role",
  "XTracker::Schema::Result::ACL::AuthorisationRole",
  { id => "authorisation_role_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "authorisation_sub_section",
  "XTracker::Schema::Result::Public::AuthorisationSubSection",
  { id => "authorisation_sub_section_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:o16ksFczPzn9HroUqTzqhg

1;
