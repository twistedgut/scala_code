use utf8;
package XTracker::Schema::Result::Printer::Section;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("printer.section");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "printer.section_id_seq",
  },
  "name",
  { data_type => "text", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("section_name_key", ["name"]);
__PACKAGE__->has_many(
  "locations",
  "XTracker::Schema::Result::Printer::Location",
  { "foreign.section_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:WoFa5LtBAt/kbVsmjp+ASw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
