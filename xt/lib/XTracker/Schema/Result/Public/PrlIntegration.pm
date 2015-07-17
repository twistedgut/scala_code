use utf8;
package XTracker::Schema::Result::Public::PrlIntegration;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.prl_integration");
__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_nullable => 0 },
  "source_prl_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "target_prl_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "source_prl",
  "XTracker::Schema::Result::Public::Prl",
  { id => "source_prl_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "target_prl",
  "XTracker::Schema::Result::Public::Prl",
  { id => "target_prl_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:fvWf4E2yaR9n3A4/H908Cw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
