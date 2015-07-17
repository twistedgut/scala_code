use utf8;
package XTracker::Schema::Result::Public::CustomerCsmPreference;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.customer_csm_preference");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "customer_csm_preference_id_seq",
  },
  "customer_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "csm_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "can_use",
  { data_type => "boolean", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(
  "customer_csm_preference_customer_id_csm_id_key",
  ["customer_id", "csm_id"],
);
__PACKAGE__->belongs_to(
  "csm",
  "XTracker::Schema::Result::Public::CorrespondenceSubjectMethod",
  { id => "csm_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "customer",
  "XTracker::Schema::Result::Public::Customer",
  { id => "customer_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:/2nPMz7b/p+Y6XQxhcg2vA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
