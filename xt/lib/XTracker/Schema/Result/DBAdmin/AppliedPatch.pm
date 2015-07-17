use utf8;
package XTracker::Schema::Result::DBAdmin::AppliedPatch;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("dbadmin.applied_patch");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "dbadmin.applied_patch_id_seq",
  },
  "created",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "filename",
  { data_type => "text", is_nullable => 0 },
  "basename",
  { data_type => "text", is_nullable => 0 },
  "succeeded",
  { data_type => "boolean", default_value => \"false", is_nullable => 1 },
  "output",
  { data_type => "text", is_nullable => 1 },
  "b64digest",
  { data_type => "text", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:CYnGpMOzqjYFaRSLuRHNew


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
