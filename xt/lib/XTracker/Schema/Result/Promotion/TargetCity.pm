use utf8;
package XTracker::Schema::Result::Promotion::TargetCity;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("event.target_city");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "event.target_city_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 50 },
  "timezone",
  {
    data_type => "varchar",
    default_value => "UTC",
    is_nullable => 0,
    size => 50,
  },
  "display_order",
  { data_type => "integer", default_value => 9999, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("target_city_name_key", ["name"]);
__PACKAGE__->has_many(
  "details",
  "XTracker::Schema::Result::Promotion::Detail",
  { "foreign.target_city_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:69FXvZnyW2QSZMYqQ/QNcg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
