use utf8;
package XTracker::Schema::Result::Public::Size;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.size");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "size_id_seq",
  },
  "size",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "sequence",
  { accessor => undef, data_type => "integer", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "sample_classification_default_sizes",
  "XTracker::Schema::Result::Public::SampleClassificationDefaultSize",
  { "foreign.size_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "sample_product_type_default_sizes",
  "XTracker::Schema::Result::Public::SampleProductTypeDefaultSize",
  { "foreign.size_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "sample_size_scheme_default_sizes",
  "XTracker::Schema::Result::Public::SampleSizeSchemeDefaultSize",
  { "foreign.size_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "size_scheme_variant_size_designer_size_ids",
  "XTracker::Schema::Result::Public::SizeSchemeVariantSize",
  { "foreign.designer_size_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "size_scheme_variant_size_size_ids",
  "XTracker::Schema::Result::Public::SizeSchemeVariantSize",
  { "foreign.size_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "std_size_mappings",
  "XTracker::Schema::Result::Public::StdSizeMapping",
  { "foreign.size_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "us_size_mappings",
  "XTracker::Schema::Result::Public::UsSizeMapping",
  { "foreign.size_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "variant_designer_size_ids",
  "XTracker::Schema::Result::Public::Variant",
  { "foreign.designer_size_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "variant_size_ids",
  "XTracker::Schema::Result::Public::Variant",
  { "foreign.size_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:RvObdwck88KtbQhU8WwPIg


# You can replace this text with custom content, and it will be preserved on regeneration
1;
