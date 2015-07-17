use utf8;
package XTracker::Schema::Result::ACL::LinkAuthorisationRoleURLPath;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("acl.link_authorisation_role__url_path");
__PACKAGE__->add_columns(
  "authorisation_role_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "url_path_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("authorisation_role_id", "url_path_id");
__PACKAGE__->belongs_to(
  "authorisation_role",
  "XTracker::Schema::Result::ACL::AuthorisationRole",
  { id => "authorisation_role_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "url_path",
  "XTracker::Schema::Result::ACL::URLPath",
  { id => "url_path_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:JxuFUzCyeC7bX2Rv8W0cZw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
