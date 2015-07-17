use utf8;
package XTracker::Schema::Result::Promotion::ShippingOption;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("event.shipping_option");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "event.shipping_option_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 100 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("shipping_option_name_key", ["name"]);
__PACKAGE__->has_many(
  "detail_shippingoptions",
  "XTracker::Schema::Result::Promotion::DetailShippingOptions",
  { "foreign.shippingoption_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:tNoxYUc5zdshCoRitvxjuA

__PACKAGE__->many_to_many(
    shippingoptions => 'detail_shippingoptions' => 'detail'
);

1;
