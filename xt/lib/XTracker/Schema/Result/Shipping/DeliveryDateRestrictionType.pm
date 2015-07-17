use utf8;
package XTracker::Schema::Result::Shipping::DeliveryDateRestrictionType;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("shipping.delivery_date_restriction_type");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "shipping.delivery_date_restriction_type_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "token",
  { data_type => "varchar", is_nullable => 1, size => 50 },
  "description",
  { data_type => "varchar", is_nullable => 1, size => 512 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(
  "shipping_delivery_date_restriction_type_token_unique",
  ["token"],
);
__PACKAGE__->has_many(
  "delivery_date_restrictions",
  "XTracker::Schema::Result::Shipping::DeliveryDateRestriction",
  { "foreign.restriction_type_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:zXPVD9WfnXljoyEB2jbEPQ

# Note: within the checksum protected code, ->table() is changed to be
# prefixed with the schema name.


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
