use utf8;
package XTracker::Schema::Result::Public::Supplier;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.supplier");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "supplier_id_seq",
  },
  "code",
  { data_type => "varchar", is_nullable => 1, size => 7 },
  "description",
  { data_type => "varchar", is_nullable => 1, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "legacy_designer_suppliers",
  "XTracker::Schema::Result::Public::LegacyDesignerSupplier",
  { "foreign.supplier_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "voucher_purchase_orders",
  "XTracker::Schema::Result::Voucher::PurchaseOrder",
  { "foreign.supplier_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Ff9juukE5shhzpFMI3SAxw


# You can replace this text with custom content, and it will be preserved on regeneration
1;
