use utf8;
package XTracker::Schema::Result::SOS::ShipmentClassAttribute;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("sos.shipment_class_attribute");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "sos.shipment_class_attribute_id_seq",
  },
  "name",
  { data_type => "text", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->might_have(
  "processing_time",
  "XTracker::Schema::Result::SOS::ProcessingTime",
  { "foreign.class_attribute_id" => "self.id" },
  undef,
);
__PACKAGE__->might_have(
  "wms_priority",
  "XTracker::Schema::Result::SOS::WmsPriority",
  { "foreign.shipment_class_attribute_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:k1i4Nnq8ClYXtcZBE+yD7w


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
