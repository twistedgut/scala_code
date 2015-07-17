use utf8;
package XTracker::Schema::Result::Public::OperatorAuthorisation;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.operator_authorisation");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "operator_authorisation_id_seq",
  },
  "operator_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "authorisation_sub_section_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "authorisation_level_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(
  "operator_authorisation_operator_id_key",
  ["operator_id", "authorisation_sub_section_id"],
);
__PACKAGE__->belongs_to(
  "auth_level",
  "XTracker::Schema::Result::Public::AuthorisationLevel",
  { id => "authorisation_level_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "auth_sub_section",
  "XTracker::Schema::Result::Public::AuthorisationSubSection",
  { id => "authorisation_sub_section_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "operator",
  "XTracker::Schema::Result::Public::Operator",
  { id => "operator_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:GDdSX1dDfZziQlbIaG9J0A



1;
