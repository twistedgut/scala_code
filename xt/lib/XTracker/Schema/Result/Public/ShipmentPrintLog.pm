use utf8;
package XTracker::Schema::Result::Public::ShipmentPrintLog;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.shipment_print_log");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "shipment_print_log_id_seq",
  },
  "shipment_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "document",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "file",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "printer_name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "date",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "shipment",
  "XTracker::Schema::Result::Public::Shipment",
  { id => "shipment_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:cankNYLlt4IR9yZNY0FVvA


# You can replace this text with custom content, and it will be preserved on regeneration
1;
