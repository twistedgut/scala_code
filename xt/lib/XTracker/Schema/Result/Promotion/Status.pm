use utf8;
package XTracker::Schema::Result::Promotion::Status;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("event.status");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "event.status_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 50 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("status_name_key", ["name"]);
__PACKAGE__->has_many(
  "details",
  "XTracker::Schema::Result::Promotion::Detail",
  { "foreign.status_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:fJUXtcjxgg7pX8yuZchaBg

use XTracker::SchemaHelper qw(:records);

1;
