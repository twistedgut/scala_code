use utf8;
package XTracker::Schema::Result::Public::QuarantineProcess;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.quarantine_process");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "quarantine_process_id_seq",
  },
  "variant_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "channel",
  "XTracker::Schema::Result::Public::Channel",
  { id => "channel_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "link_delivery_item__quarantine_processes",
  "XTracker::Schema::Result::Public::LinkDeliveryItemQuarantineProcess",
  { "foreign.quarantine_process_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "variant",
  "XTracker::Schema::Result::Public::Variant",
  { id => "variant_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->many_to_many(
  "delivery_items",
  "link_delivery_item__quarantine_processes",
  "delivery_item",
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:4x74ZFnEKWaNh1GiIOTlUQ


# You can replace this text with custom content, and it will be preserved on regeneration
1;
