use utf8;
package XTracker::Schema::Result::Promotion::CouponRestrictionGroup;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("event.coupon_restriction_group");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "event.coupon_restriction_group_id_seq",
  },
  "idx",
  { data_type => "integer", default_value => 9999, is_nullable => 0 },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 50 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("coupon_restriction_group_name_key", ["name"]);
__PACKAGE__->has_many(
  "coupon_restrictions",
  "XTracker::Schema::Result::Promotion::CouponRestriction",
  { "foreign.group_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "coupons",
  "XTracker::Schema::Result::Promotion::Coupon",
  { "foreign.usage_type_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:MLfl8XANSLMHZlH55MisFQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
