use utf8;
package XTracker::Schema::Result::Public::LegacyDesignerSupplier;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.legacy_designer_supplier");
__PACKAGE__->add_columns(
  "designer_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "supplier_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("designer_id");
__PACKAGE__->belongs_to(
  "designer",
  "XTracker::Schema::Result::Public::Designer",
  { id => "designer_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "supplier",
  "XTracker::Schema::Result::Public::Supplier",
  { id => "supplier_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:IFKqMQPTyjnI3vXAdLTbsA

1;
