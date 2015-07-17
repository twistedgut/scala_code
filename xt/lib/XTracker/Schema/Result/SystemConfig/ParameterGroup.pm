use utf8;
package XTracker::Schema::Result::SystemConfig::ParameterGroup;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("system_config.parameter_group");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "system_config.parameter_group_id_seq",
  },
  "name",
  { data_type => "text", is_nullable => 0 },
  "description",
  { data_type => "text", is_nullable => 0 },
  "visible",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("parameter_group_name_key", ["name"]);
__PACKAGE__->has_many(
  "parameters",
  "XTracker::Schema::Result::SystemConfig::Parameter",
  { "foreign.parameter_group_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:jXtVBsPrT4HQeNGdAj/nyA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
