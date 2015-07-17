use utf8;
package XTracker::Schema::Result::Public::DistribCentre;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.distrib_centre");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "distrib_centre_id_seq",
  },
  "name",
  { data_type => "text", is_nullable => 0 },
  "alias",
  { data_type => "varchar", is_nullable => 0, size => 10 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("distrib_centre_alias_key", ["alias"]);
__PACKAGE__->add_unique_constraint("distrib_centre_name_key", ["name"]);
__PACKAGE__->has_many(
  "channels",
  "XTracker::Schema::Result::Public::Channel",
  { "foreign.distrib_centre_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:0zNvcqAfkIxy2zTCnFJdmQ

__PACKAGE__->has_many(
    'channel'   => 'XTracker::Schema::Result::Public::Channel',
    { 'foreign.distrib_centre_id' => 'self.id' }
);

1;
