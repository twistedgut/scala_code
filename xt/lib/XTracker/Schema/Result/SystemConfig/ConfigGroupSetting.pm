use utf8;
package XTracker::Schema::Result::SystemConfig::ConfigGroupSetting;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("system_config.config_group_setting");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "system_config.config_group_setting_id_seq",
  },
  "config_group_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "setting",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "value",
  { data_type => "text", is_nullable => 1 },
  "sequence",
  {
    accessor      => undef,
    data_type     => "integer",
    default_value => 0,
    is_nullable   => 0,
  },
  "active",
  { data_type => "boolean", default_value => \"true", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(
  "config_group_setting_uniq",
  ["config_group_id", "setting", "sequence"],
);
__PACKAGE__->belongs_to(
  "config_group",
  "XTracker::Schema::Result::SystemConfig::ConfigGroup",
  { id => "config_group_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:jeHrSrZhqGIctzvqdO1FYg


# You can replace this text with custom content, and it will be preserved on regeneration
1;
