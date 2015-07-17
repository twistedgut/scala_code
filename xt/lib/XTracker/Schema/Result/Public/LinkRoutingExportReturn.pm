use utf8;
package XTracker::Schema::Result::Public::LinkRoutingExportReturn;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.link_routing_export__return");
__PACKAGE__->add_columns(
  "routing_export_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "return_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("routing_export_id", "return_id");
__PACKAGE__->belongs_to(
  "return",
  "XTracker::Schema::Result::Public::Return",
  { id => "return_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "routing_export",
  "XTracker::Schema::Result::Public::RoutingExport",
  { id => "routing_export_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:1MyN0B4ekpP+D1IQaG3kRQ


# You can replace this text with custom content, and it will be preserved on regeneration
1;
