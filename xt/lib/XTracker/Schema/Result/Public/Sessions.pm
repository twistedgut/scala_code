use utf8;
package XTracker::Schema::Result::Public::Sessions;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.sessions");
__PACKAGE__->add_columns(
  "id",
  { data_type => "text", is_nullable => 0 },
  "session_data",
  { data_type => "text", is_nullable => 1 },
  "last_modified",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "expires",
  { data_type => "integer", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ZBV88MXBiPTeD/uw6QNJPg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
