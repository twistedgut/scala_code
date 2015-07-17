use utf8;
package XTracker::Schema::Result::Promotion::CouponRestriction;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("event.coupon_restriction");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "event.coupon_restriction_id_seq",
  },
  "idx",
  { data_type => "integer", default_value => 9999, is_nullable => 0 },
  "description",
  { data_type => "varchar", is_nullable => 1, size => 50 },
  "group_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "usage_limit",
  { data_type => "integer", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("coupon_restriction_description_key", ["description"]);
__PACKAGE__->has_many(
  "details",
  "XTracker::Schema::Result::Promotion::Detail",
  { "foreign.coupon_restriction_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "group",
  "XTracker::Schema::Result::Promotion::CouponRestrictionGroup",
  { id => "group_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:6MSjM3gmOeGxc5Kqi4SNeA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
