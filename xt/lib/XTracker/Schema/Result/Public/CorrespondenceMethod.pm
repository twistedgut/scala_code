use utf8;
package XTracker::Schema::Result::Public::CorrespondenceMethod;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.correspondence_method");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "correspondence_method_id_seq",
  },
  "method",
  { data_type => "varchar", is_nullable => 0, size => 30 },
  "description",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "can_opt_out",
  { data_type => "boolean", is_nullable => 0 },
  "enabled",
  { data_type => "boolean", default_value => \"true", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("correspondence_method_method_key", ["method"]);
__PACKAGE__->has_many(
  "correspondence_subject_methods",
  "XTracker::Schema::Result::Public::CorrespondenceSubjectMethod",
  { "foreign.correspondence_method_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "customer_correspondence_method_preferences",
  "XTracker::Schema::Result::Public::CustomerCorrespondenceMethodPreference",
  { "foreign.correspondence_method_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:oCI1kdoatPQrnnwkctsBoA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
