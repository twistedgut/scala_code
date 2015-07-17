use utf8;
package XTracker::Schema::Result::Printer::Type;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("printer.type");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "printer.type_id_seq",
  },
  "name",
  { data_type => "text", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("type_name_key", ["name"]);
__PACKAGE__->has_many(
  "printers",
  "XTracker::Schema::Result::Printer::Printer",
  { "foreign.type_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:or6LlyZZ4yC6OpI688IlSA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
