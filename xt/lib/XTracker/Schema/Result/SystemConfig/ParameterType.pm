use utf8;
package XTracker::Schema::Result::SystemConfig::ParameterType;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("system_config.parameter_type");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "system_config.parameter_type_id_seq",
  },
  "type",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("parameter_type_type_key", ["type"]);
__PACKAGE__->has_many(
  "parameters",
  "XTracker::Schema::Result::SystemConfig::Parameter",
  { "foreign.parameter_type_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:FpL0M2iMe2H9A/aEDHSnEg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
