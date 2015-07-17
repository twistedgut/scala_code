use utf8;
package XTracker::Schema::Result::Promotion::DetailWebsites;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("event.detail_websites");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "event.detail_websites_id_seq",
  },
  "event_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "website_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("detail_websites_detail_id_key", ["event_id", "website_id"]);
__PACKAGE__->belongs_to(
  "detail",
  "XTracker::Schema::Result::Promotion::Detail",
  { id => "event_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "website",
  "XTracker::Schema::Result::Promotion::Website",
  { id => "website_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:lTzwXFgHOsv/QBagciPUFQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
