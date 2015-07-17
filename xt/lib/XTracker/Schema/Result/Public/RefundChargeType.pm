use utf8;
package XTracker::Schema::Result::Public::RefundChargeType;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.refund_charge_type");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "refund_charge_type_id_seq",
  },
  "type",
  { data_type => "varchar", is_nullable => 0, size => 20 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("idx_refund_charge_type__type", ["type"]);
__PACKAGE__->has_many(
  "return_country_refund_charges",
  "XTracker::Schema::Result::Public::ReturnCountryRefundCharge",
  { "foreign.refund_charge_type_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "return_sub_region_refund_charges",
  "XTracker::Schema::Result::Public::ReturnSubRegionRefundCharge",
  { "foreign.refund_charge_type_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:CTSZQi6l+xFK34Bg4Z8atw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
