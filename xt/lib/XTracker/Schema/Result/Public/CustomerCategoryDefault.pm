use utf8;
package XTracker::Schema::Result::Public::CustomerCategoryDefault;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.customer_category_defaults");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "customer_category_defaults_id_seq",
  },
  "category_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "email_domain",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(
  "customer_category_defaults_category_id_key",
  ["category_id", "email_domain"],
);
__PACKAGE__->belongs_to(
  "category",
  "XTracker::Schema::Result::Public::CustomerCategory",
  { id => "category_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:cWLwzzjZQxrSFLd/VwmV8w


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
