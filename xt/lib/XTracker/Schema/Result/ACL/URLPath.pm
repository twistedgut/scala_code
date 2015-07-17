use utf8;
package XTracker::Schema::Result::ACL::URLPath;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("acl.url_path");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "acl.url_path_id_seq",
  },
  "url_path",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("url_path_url_path_key", ["url_path"]);
__PACKAGE__->has_many(
  "link_authorisation_role__url_paths",
  "XTracker::Schema::Result::ACL::LinkAuthorisationRoleURLPath",
  { "foreign.url_path_id" => "self.id" },
  undef,
);
__PACKAGE__->many_to_many(
  "authorisation_roles",
  "link_authorisation_role__url_paths",
  "authorisation_role",
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:mVqn4SW5Bsi3ZMtwG6w8XA

1;
