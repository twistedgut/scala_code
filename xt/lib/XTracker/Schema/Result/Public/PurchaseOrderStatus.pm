use utf8;
package XTracker::Schema::Result::Public::PurchaseOrderStatus;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.purchase_order_status");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "purchase_order_status_id_seq",
  },
  "status",
  { data_type => "varchar", is_nullable => 1, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "purchase_orders",
  "XTracker::Schema::Result::Public::PurchaseOrder",
  { "foreign.status_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "super_purchase_orders",
  "XTracker::Schema::Result::Public::SuperPurchaseOrder",
  { "foreign.status_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "voucher_purchase_orders",
  "XTracker::Schema::Result::Voucher::PurchaseOrder",
  { "foreign.status_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:GsL8ezKars0PKABDtY/QBQ

# You can replace this text with custom content, and it will be preserved on regeneration
1;
