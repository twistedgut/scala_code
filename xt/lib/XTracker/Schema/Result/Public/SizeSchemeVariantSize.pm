use utf8;
package XTracker::Schema::Result::Public::SizeSchemeVariantSize;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.size_scheme_variant_size");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "size_scheme_variant_size_id_seq",
  },
  "size_scheme_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "size_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "designer_size_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "position",
  { data_type => "integer", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("size__size_scheme_unique", ["size_id", "size_scheme_id"]);
__PACKAGE__->belongs_to(
  "designer_size",
  "XTracker::Schema::Result::Public::Size",
  { id => "designer_size_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
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


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:h9HNdJXfTAB6UuvT4a9dAA


# You can replace this text with custom content, and it will be preserved on regeneration
1;
