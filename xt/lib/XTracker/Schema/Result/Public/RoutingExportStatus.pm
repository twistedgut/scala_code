use utf8;
package XTracker::Schema::Result::Public::RoutingExportStatus;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.routing_export_status");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "routing_export_status_id_seq",
  },
  "status",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "routing_export_status_logs",
  "XTracker::Schema::Result::Public::RoutingExportStatusLog",
  { "foreign.status_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "routing_exports",
  "XTracker::Schema::Result::Public::RoutingExport",
  { "foreign.status_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:UJSqRe2ZDfDXAQrD1+t/pw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
