use utf8;
package XTracker::Schema::Result::Public::ProductType;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.product_type");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "product_type_id_seq",
  },
  "product_type",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("product_type_product_type_key", ["product_type"]);
__PACKAGE__->has_many(
  "link_marketing_promotion__product_types",
  "XTracker::Schema::Result::Public::LinkMarketingPromotionProductType",
  { "foreign.product_type_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "product_type_measurements",
  "XTracker::Schema::Result::Public::ProductTypeMeasurement",
  { "foreign.product_type_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "product_type_tax_rates",
  "XTracker::Schema::Result::Public::ProductTypeTaxRate",
  { "foreign.product_type_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "products",
  "XTracker::Schema::Result::Public::Product",
  { "foreign.product_type_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "promotion_detail_producttypes",
  "XTracker::Schema::Result::Promotion::DetailProductTypes",
  { "foreign.producttype_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "sample_product_type_default_sizes",
  "XTracker::Schema::Result::Public::SampleProductTypeDefaultSize",
  { "foreign.product_type_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "std_size_mappings",
  "XTracker::Schema::Result::Public::StdSizeMapping",
  { "foreign.product_type_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:sYAw5fhbLZtYl9YCjQQ0Ww


__PACKAGE__->many_to_many(
    'measurements', 'product_type_measurements' => 'measurement'
);

{
# See also Classification Result class, which is one level more specific
my $labels_per_item = {
    Jewelry => {
        small => 2,
        large => 0,
    },
    # A tiny minority of products actually spell jewellery like this, and in
    # the original code that was ported this wasn't even included, but it's a
    # valid spelling so we probably want it to behave as 'Jewelry', so adding
    # it too
    Jewellery => {
        small => 2,
        large => 0,
    },
    'Small Leather Goods' => {
        small => 2,
        large => 0,
    },
    'Belts' => {
        small => 2,
        large => 0,
    },
};

=head2 small_labels_per_item_override() : $labels_per_item

Returns the number of small labels to be printed for this class of items,
if it differs from the default (which the calling code must define).

=cut

sub small_labels_per_item_override {
    return $labels_per_item->{shift->product_type}{small};
}

=head2 large_labels_per_item_override() : $labels_per_item

Returns the number of large labels to be printed for this class of items,
if it differs from the default (which the calling code must define)

=cut

sub large_labels_per_item_override {
    return $labels_per_item->{shift->product_type}{large};
}
}

=head2 measurements_for_channels(@channel_ids?) : $product_type_measurement_rs || @product_type_measurements

Return the measurements for the given channels for this product type. Not
passing any arguments will not filter by channels.

=cut

sub measurements_for_channels {
    my ( $self, @channel_ids ) = @_;

    # I'm not 100% convinced by order_by measurement_id as this table has a
    # sort_order - but I'm porting this sub from ProductTypeMeasurement's
    # resultset and that's how it was written.
    return $self->search_related('product_type_measurements',
        { @channel_ids ? ( channel_id => \@channel_ids ) : () },
        { order_by => 'measurement_id', prefetch => 'measurement' }
    );
}

1;
