use utf8;
package XTracker::Schema::Result::Promotion::Coupon;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("event.coupon");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "event.coupon_id_seq",
  },
  "prefix",
  { data_type => "varchar", is_nullable => 0, size => 8 },
  "suffix",
  { data_type => "varchar", is_nullable => 0, size => 8 },
  "code",
  { data_type => "varchar", is_nullable => 0, size => 17 },
  "event_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "restrict_by_email",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "email",
  { data_type => "text", is_nullable => 1 },
  "customer_id",
  { data_type => "integer", is_nullable => 1 },
  "usage_count",
  { data_type => "integer", default_value => 0, is_nullable => 1 },
  "usage_limit",
  { data_type => "integer", is_nullable => 1 },
  "usage_type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "valid",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("coupon_code_key", ["code"]);
__PACKAGE__->add_unique_constraint("coupon_prefix_key", ["prefix", "suffix"]);
__PACKAGE__->belongs_to(
  "promotion_detail",
  "XTracker::Schema::Result::Promotion::Detail",
  { id => "event_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "usage_type",
  "XTracker::Schema::Result::Promotion::CouponRestrictionGroup",
  { id => "usage_type_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:RlbUur7r0iETdhvkH39vYQ

use XTracker::SchemaHelper qw(:records);

1;
