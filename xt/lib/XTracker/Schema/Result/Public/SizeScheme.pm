use utf8;
package XTracker::Schema::Result::Public::SizeScheme;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.size_scheme");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "size_scheme_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "short_name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "product_attributes",
  "XTracker::Schema::Result::Public::ProductAttribute",
  { "foreign.size_scheme_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "sample_size_scheme_default_sizes",
  "XTracker::Schema::Result::Public::SampleSizeSchemeDefaultSize",
  { "foreign.size_scheme_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "size_scheme_variant_sizes",
  "XTracker::Schema::Result::Public::SizeSchemeVariantSize",
  { "foreign.size_scheme_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "std_size_mappings",
  "XTracker::Schema::Result::Public::StdSizeMapping",
  { "foreign.size_scheme_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "us_size_mappings",
  "XTracker::Schema::Result::Public::UsSizeMapping",
  { "foreign.size_scheme_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:DA3zL/MUq54aeqZFqnVQuA

__PACKAGE__->many_to_many(
    'sizes', size_scheme_variant_sizes => 'size'
);
__PACKAGE__->many_to_many(
    'designer_sizes', size_scheme_variant_sizes => 'designer_size'
);
__PACKAGE__->many_to_many(
    'sample_sizes', sample_size_scheme_default_sizes => 'size'
);

1;
