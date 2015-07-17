use utf8;
package XTracker::Schema::Result::Public::ShippingAccountCountry;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.shipping_account__country");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "shipping_account__country_id_seq",
  },
  "shipping_account_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "country",
  { data_type => "varchar", is_nullable => 0, size => 100 },
  "channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(
  "shipping_account__country_country_key1",
  ["country", "channel_id"],
);
__PACKAGE__->add_unique_constraint(
  "shipping_account__shipping_acc_country_channel_key",
  ["shipping_account_id", "country", "channel_id"],
);
__PACKAGE__->belongs_to(
  "channel",
  "XTracker::Schema::Result::Public::Channel",
  { id => "channel_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "shipping_account",
  "XTracker::Schema::Result::Public::ShippingAccount",
  { id => "shipping_account_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:7Y9N38RyQj4EN2eWbK3Sgg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
