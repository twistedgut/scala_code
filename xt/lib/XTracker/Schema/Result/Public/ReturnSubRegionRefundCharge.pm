use utf8;
package XTracker::Schema::Result::Public::ReturnSubRegionRefundCharge;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.return_sub_region_refund_charge");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "return_sub_region_refund_charge_id_seq",
  },
  "sub_region_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "refund_charge_type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "can_refund_for_return",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "no_charge_for_exchange",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(
  "idx_return_sub_region_refund_charge__sub_region_id_type_id",
  ["sub_region_id", "refund_charge_type_id"],
);
__PACKAGE__->belongs_to(
  "refund_charge_type",
  "XTracker::Schema::Result::Public::RefundChargeType",
  { id => "refund_charge_type_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "sub_region",
  "XTracker::Schema::Result::Public::SubRegion",
  { id => "sub_region_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:jxw+TbLdo+CoOM6CZarhAg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
