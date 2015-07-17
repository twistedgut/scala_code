use utf8;
package XTracker::Schema::Result::Public::RenumerationReasonType;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.renumeration_reason_type");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "renumeration_reason_type_id_seq",
  },
  "type",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("renumeration_reason_type_type_key", ["type"]);
__PACKAGE__->has_many(
  "renumeration_reasons",
  "XTracker::Schema::Result::Public::RenumerationReason",
  { "foreign.renumeration_reason_type_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:jbTlkfLVsqMhi6lLdlTO4A


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
