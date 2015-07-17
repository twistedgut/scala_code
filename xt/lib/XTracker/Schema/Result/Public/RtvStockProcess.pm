use utf8;
package XTracker::Schema::Result::Public::RtvStockProcess;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.rtv_stock_process");
__PACKAGE__->add_columns(
  "stock_process_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "originating_uri_path",
  { data_type => "varchar", is_nullable => 0, size => 100 },
  "originating_sub_section_id",
  { data_type => "integer", is_nullable => 0 },
  "notes",
  { data_type => "varchar", is_nullable => 1, size => 2000 },
);
__PACKAGE__->set_primary_key("stock_process_id");
__PACKAGE__->belongs_to(
  "stock_process",
  "XTracker::Schema::Result::Public::StockProcess",
  { id => "stock_process_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:PQFM1T9tP24C7teUO0soMQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
