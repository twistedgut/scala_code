use utf8;
package XTracker::Schema::Result::Public::FulfilmentOverviewStage;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.fulfilment_overview_stage");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "fulfilment_overview_stage_id_seq",
  },
  "stage",
  { data_type => "text", is_nullable => 0 },
  "is_active",
  { data_type => "boolean", default_value => \"true", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "shipment_item_statuses",
  "XTracker::Schema::Result::Public::ShipmentItemStatus",
  { "foreign.fulfilment_overview_stage_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:8QvzUjBRM+cW/L0O0gBjyA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
