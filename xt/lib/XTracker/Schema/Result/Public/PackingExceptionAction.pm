use utf8;
package XTracker::Schema::Result::Public::PackingExceptionAction;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.packing_exception_action");
__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("packing_exception_action_name_key", ["name"]);
__PACKAGE__->has_many(
  "shipment_item_status_logs",
  "XTracker::Schema::Result::Public::ShipmentItemStatusLog",
  { "foreign.packing_exception_action_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:x1mqgA55kM3nQKN8L+hrPg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
