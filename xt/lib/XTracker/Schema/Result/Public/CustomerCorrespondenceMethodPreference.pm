use utf8;
package XTracker::Schema::Result::Public::CustomerCorrespondenceMethodPreference;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.customer_correspondence_method_preference");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "customer_correspondence_method_preference_id_seq",
  },
  "customer_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "correspondence_method_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "can_use",
  { data_type => "boolean", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(
  "customer_correspondence_metho_customer_id_correspondence_me_key",
  ["customer_id", "correspondence_method_id"],
);
__PACKAGE__->belongs_to(
  "correspondence_method",
  "XTracker::Schema::Result::Public::CorrespondenceMethod",
  { id => "correspondence_method_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "customer",
  "XTracker::Schema::Result::Public::Customer",
  { id => "customer_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Q2uJguU+C+TRDSK7M7WZRA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
