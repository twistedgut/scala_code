use utf8;
package XTracker::Schema::Result::Public::StockProcessType;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.stock_process_type");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "stock_process_type_id_seq",
  },
  "type",
  { data_type => "varchar", is_nullable => 1, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "log_deliveries",
  "XTracker::Schema::Result::Public::LogDelivery",
  { "foreign.type_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "stock_processes",
  "XTracker::Schema::Result::Public::StockProcess",
  { "foreign.type_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ZoIKk4esqakDUHjouOWBqQ


# You can replace this text with custom content, and it will be preserved on regeneration
1;
