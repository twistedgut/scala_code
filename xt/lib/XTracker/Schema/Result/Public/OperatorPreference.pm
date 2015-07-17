use utf8;
package XTracker::Schema::Result::Public::OperatorPreference;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.operator_preferences");
__PACKAGE__->add_columns(
  "operator_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "pref_channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "default_home_page",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "packing_station_name",
  { data_type => "text", is_nullable => 1 },
  "printer_station_name",
  { data_type => "text", is_nullable => 1 },
  "packing_printer",
  { data_type => "text", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("operator_id");
__PACKAGE__->belongs_to(
  "default_home_page_sub_section",
  "XTracker::Schema::Result::Public::AuthorisationSubSection",
  { id => "default_home_page" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "operator",
  "XTracker::Schema::Result::Public::Operator",
  { id => "operator_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "pref_channel",
  "XTracker::Schema::Result::Public::Channel",
  { id => "pref_channel_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:StSJKcbnPc5E1sbux8oVWA


__PACKAGE__->belongs_to(
    'channel'   => 'XTracker::Schema::Result::Public::Channel',
    { 'foreign.id' => 'self.pref_channel_id' }
);

__PACKAGE__->belongs_to(
    'authorisation_sub_section' => 'XTracker::Schema::Result::Public::AuthorisationSubSection',
    { 'foreign.id' => 'self.default_home_page' }
);

1;
