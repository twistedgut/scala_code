use utf8;
package XTracker::Schema::Result::Public::AuthorisationSubSection;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.authorisation_sub_section");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "authorisation_sub_section_id_seq",
  },
  "authorisation_section_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "sub_section",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "ord",
  { data_type => "smallint", default_value => 1, is_nullable => 0 },
  "acl_controlled",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(
  "authorisation_sub_section_auth_section_id_sub_section_key",
  ["authorisation_section_id", "sub_section"],
);
__PACKAGE__->add_unique_constraint(
  "authorisation_sub_section_authorisation_section_id_ord_key",
  ["authorisation_section_id", "ord"],
);
__PACKAGE__->has_many(
  "link_authorisation_role__authorisation_sub_sections",
  "XTracker::Schema::Result::ACL::LinkAuthorisationRoleAuthorisationSubSection",
  { "foreign.authorisation_sub_section_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "operator_authorisations",
  "XTracker::Schema::Result::Public::OperatorAuthorisation",
  { "foreign.authorisation_sub_section_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "operator_preferences",
  "XTracker::Schema::Result::Public::OperatorPreference",
  { "foreign.default_home_page" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "section",
  "XTracker::Schema::Result::Public::AuthorisationSection",
  { id => "authorisation_section_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->many_to_many(
  "acl_roles",
  "link_authorisation_role__authorisation_sub_sections",
  "authorisation_role",
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ihjvGIKSd7CKCPz+f/UBkA


1;
