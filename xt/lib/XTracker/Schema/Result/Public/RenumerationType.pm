use utf8;
package XTracker::Schema::Result::Public::RenumerationType;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.renumeration_type");
__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_nullable => 0 },
  "type",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "renumerations",
  "XTracker::Schema::Result::Public::Renumeration",
  { "foreign.renumeration_type_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "tenders",
  "XTracker::Schema::Result::Orders::Tender",
  { "foreign.type_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:qOiHMU0o8z7D8mNUZ03ewg


# You can replace this text with custom content, and it will be preserved on regeneration
1;
