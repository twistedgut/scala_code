use utf8;
package XTracker::Schema::Result::Public::ReturnRemovalReason;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.return_removal_reason");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "return_removal_reason_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("return_removal_reason_name_uniq", ["name"]);
__PACKAGE__->has_many(
  "return_arrivals",
  "XTracker::Schema::Result::Public::ReturnArrival",
  { "foreign.return_removal_reason_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:umaqT1R/RLy7vOGeauoJVA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
