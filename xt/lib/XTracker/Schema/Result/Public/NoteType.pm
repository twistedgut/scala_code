use utf8;
package XTracker::Schema::Result::Public::NoteType;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.note_type");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "note_type_id_seq",
  },
  "code",
  { data_type => "varchar", is_nullable => 0, size => 3 },
  "description",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "customer_notes",
  "XTracker::Schema::Result::Public::CustomerNote",
  { "foreign.note_type_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "order_notes",
  "XTracker::Schema::Result::Public::OrderNote",
  { "foreign.note_type_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "return_notes",
  "XTracker::Schema::Result::Public::ReturnNote",
  { "foreign.note_type_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "shipment_notes",
  "XTracker::Schema::Result::Public::ShipmentNote",
  { "foreign.note_type_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:yfD1j9sNoJNI7T13fRXUqQ


# You can replace this text with custom content, and it will be preserved on regeneration
1;
