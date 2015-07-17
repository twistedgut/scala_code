use utf8;
package XTracker::Schema::Result::Public::StdSizeMapping;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.std_size_mapping");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "std_size_mapping_id_seq",
  },
  "size_scheme_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "size_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "classification_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "product_type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "std_size_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(
  "std_size_mapping_size_scheme_id_key",
  [
    "size_scheme_id",
    "size_id",
    "classification_id",
    "product_type_id",
  ],
);
__PACKAGE__->belongs_to(
  "classification",
  "XTracker::Schema::Result::Public::Classification",
  { id => "classification_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "product_type",
  "XTracker::Schema::Result::Public::ProductType",
  { id => "product_type_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "size",
  "XTracker::Schema::Result::Public::Size",
  { id => "size_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "size_scheme",
  "XTracker::Schema::Result::Public::SizeScheme",
  { id => "size_scheme_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "std_size",
  "XTracker::Schema::Result::Public::StdSize",
  { id => "std_size_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:5LT4fwrJ3hleDDoQz+wdpA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
