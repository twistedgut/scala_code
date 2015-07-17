use utf8;
package XTracker::Schema::Result::Public::LocalisedEmailAddress;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.localised_email_address");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "localised_email_address_id_seq",
  },
  "email_address",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "locale",
  { data_type => "varchar", is_nullable => 1, size => 10 },
  "localised_email_address",
  { data_type => "varchar", is_nullable => 1, size => 255 },
);
__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:bXP0N20jLaGQwZ8qMYPMUQ

# This is actually on lower() of the columns, which makes
# Schema::Loader not detect it
__PACKAGE__->add_unique_constraint(
  "localised_email_address_email_address_locale_key",
  ["email_address", "locale"],
);

1;
