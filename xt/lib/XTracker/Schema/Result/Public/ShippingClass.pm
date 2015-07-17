use utf8;
package XTracker::Schema::Result::Public::ShippingClass;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.shipping_class");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "shipping_class_id_seq",
  },
  "name",
  { data_type => "text", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "shipping_accounts",
  "XTracker::Schema::Result::Public::ShippingAccount",
  { "foreign.shipping_class_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "ups_service_availabilities",
  "XTracker::Schema::Result::Public::UpsServiceAvailability",
  { "foreign.shipping_class_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:KV8XjX6Mrp7OLF46UmmVSg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
