use utf8;
package XTracker::Schema::Result::Public::RenumerationTender;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.renumeration_tender");
__PACKAGE__->add_columns(
  "renumeration_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "tender_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "value",
  { data_type => "numeric", is_nullable => 0, size => [10, 3] },
);
__PACKAGE__->set_primary_key("renumeration_id", "tender_id");
__PACKAGE__->belongs_to(
  "renumeration",
  "XTracker::Schema::Result::Public::Renumeration",
  { id => "renumeration_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "tender",
  "XTracker::Schema::Result::Orders::Tender",
  { id => "tender_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:B4Ey7EX2RxmzvK4a4aaYxQ


1;
