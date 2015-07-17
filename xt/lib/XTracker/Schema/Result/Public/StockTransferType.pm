use utf8;
package XTracker::Schema::Result::Public::StockTransferType;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.stock_transfer_type");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "stock_transfer_type_id_seq",
  },
  "type",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("stock_transfer_type_type_key", ["type"]);
__PACKAGE__->has_many(
  "stock_transfers",
  "XTracker::Schema::Result::Public::StockTransfer",
  { "foreign.type_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:+R7XTLjtAsJ9xRm6RP620Q


# You can replace this text with custom content, and it will be preserved on regeneration
1;