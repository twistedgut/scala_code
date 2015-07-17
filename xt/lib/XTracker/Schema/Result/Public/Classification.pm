use utf8;
package XTracker::Schema::Result::Public::Classification;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.classification");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "classification_id_seq",
  },
  "classification",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("classification_classification_key", ["classification"]);
__PACKAGE__->has_many(
  "products",
  "XTracker::Schema::Result::Public::Product",
  { "foreign.classification_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "sample_classification_default_sizes",
  "XTracker::Schema::Result::Public::SampleClassificationDefaultSize",
  { "foreign.classification_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "std_size_mappings",
  "XTracker::Schema::Result::Public::StdSizeMapping",
  { "foreign.classification_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:HhafNJvdH5Q9IjO2zYfEwg

{
# See also ProductType Result class, which is one level more general
my $labels_per_item = {
    Shoes => {
        small => 2,
        large => 0,
    }
};

=head2 small_labels_per_item_override() : $labels_per_item

Returns the number of small labels to be printed for this class of items,
if it differs from the default (which the calling code must define).

=cut

sub small_labels_per_item_override {
    return $labels_per_item->{shift->classification}{small};
}

=head2 large_labels_per_item_override() : $labels_per_item

Returns the number of large labels to be printed for this class of items,
if it differs from the default (which the calling code must define).

=cut

sub large_labels_per_item_override {
    return $labels_per_item->{shift->classification}{large};
}
}

1;
