use utf8;
package XTracker::Schema::Result::Public::GenerationCounter;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.generation_counter");
__PACKAGE__->add_columns(
  "name",
  { data_type => "text", is_nullable => 0 },
  "counter",
  {
    data_type         => "bigint",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "generation_counter_seq",
  },
);
__PACKAGE__->set_primary_key("name");


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ZtVhCEsHhFwaIQXeVaNPgg

# Needs to happen after inheritance is set up, but before the
# ->table() call above
BEGIN { __PACKAGE__->table_class("XTracker::Schema::ResultSource::Public::GenerationCounter"); }

1;
