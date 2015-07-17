use utf8;
package XTracker::Schema::Result::Public::LogSampleAdjustment;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.log_sample_adjustment");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "log_sample_adjustment_id_seq",
  },
  "sku",
  { data_type => "text", is_nullable => 0 },
  "location_name",
  { data_type => "text", is_nullable => 0 },
  "operator_name",
  { data_type => "text", is_nullable => 0 },
  "channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "notes",
  { data_type => "text", is_nullable => 0 },
  "delta",
  { data_type => "integer", is_nullable => 0 },
  "balance",
  { data_type => "integer", is_nullable => 0 },
  "timestamp",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "channel",
  "XTracker::Schema::Result::Public::Channel",
  { id => "channel_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:wa53gkofz2QRMnPSdHcAUw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
