use utf8;
package XTracker::Schema::Result::Promotion::CouponGeneration;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("event.coupon_generation");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "event.coupon_generation_id_seq",
  },
  "idx",
  { data_type => "integer", default_value => 9999, is_nullable => 0 },
  "action",
  { data_type => "varchar", is_nullable => 1, size => 50 },
  "description",
  { data_type => "text", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("coupon_generation_action_key", ["action"]);
__PACKAGE__->has_many(
  "details",
  "XTracker::Schema::Result::Promotion::Detail",
  { "foreign.coupon_generation_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:WARWLpHxUR1tmbe0HafIkg

use XTracker::SchemaHelper qw(:records);

1;
