use utf8;
package XTracker::Schema::Result::Public::PackagingType;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.packaging_type");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "packaging_type_id_seq",
  },
  "sku",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "name",
  { data_type => "varchar", is_nullable => 1, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("packaging_type_sku_key", ["sku"]);
__PACKAGE__->has_many(
  "packaging_attributes",
  "XTracker::Schema::Result::Public::PackagingAttribute",
  { "foreign.packaging_type_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "pre_orders",
  "XTracker::Schema::Result::Public::PreOrder",
  { "foreign.packaging_type_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:lesNYi1dy3W6IEbhRw4+Sw

=head2 prodcut_id

Extract the C<product_id> from the C<sku>.

=cut

sub product_id {
    my $self = shift;

    my ($product_id,undef) = split /-/, $self->sku;

    return $product_id+0;
}

=head2 size_id

Extract the C<size_id> from the C<sku>.

=cut

sub size_id {
    my $self = shift;

    my (undef,$size_id) = split /-/, $self->sku;

    return $size_id+0;
}
1;
