use utf8;
package XTracker::Schema::Result::Public::ItemFaultType;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.item_fault_type");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "item_fault_type_id_seq",
  },
  "fault_type",
  { data_type => "varchar", is_nullable => 0, size => 50 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("item_fault_type_fault_type_key", ["fault_type"]);
__PACKAGE__->has_many(
  "rma_request_details",
  "XTracker::Schema::Result::Public::RmaRequestDetail",
  { "foreign.fault_type_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "rtv_quantities",
  "XTracker::Schema::Result::Public::RTVQuantity",
  { "foreign.fault_type_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:lu7BHI1qN0O9+mXI8eqcaw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
