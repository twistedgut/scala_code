use utf8;
package XTracker::Schema::Result::Public::ShippingAttribute;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.shipping_attribute");
__PACKAGE__->add_columns(
  "product_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "scientific_term",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "country_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "packing_note",
  { data_type => "text", is_nullable => 1 },
  "weight",
  {
    data_type => "numeric",
    default_value => 0,
    is_nullable => 1,
    size => [20, 3],
  },
  "box_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "fabric_content",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "legacy_countryoforigin",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "fish_wildlife",
  { data_type => "boolean", default_value => \"false", is_nullable => 1 },
  "operator_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "shipping_attribute_id_seq",
  },
  "cites_restricted",
  { data_type => "boolean", default_value => \"false", is_nullable => 1 },
  "fish_wildlife_source",
  { data_type => "varchar", is_nullable => 1, size => 50 },
  "is_hazmat",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "packing_note_operator_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "packing_note_date_added",
  { data_type => "timestamp with time zone", is_nullable => 1 },
  "length",
  { data_type => "numeric", is_nullable => 1, size => [10, 3] },
  "width",
  { data_type => "numeric", is_nullable => 1, size => [10, 3] },
  "height",
  { data_type => "numeric", is_nullable => 1, size => [10, 3] },
  "dangerous_goods_note",
  { data_type => "text", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("shipping_attribute_product_id_key", ["product_id"]);
__PACKAGE__->belongs_to(
  "box",
  "XTracker::Schema::Result::Public::Box",
  { id => "box_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "country",
  "XTracker::Schema::Result::Public::Country",
  { id => "country_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "operator",
  "XTracker::Schema::Result::Public::Operator",
  { id => "operator_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "packing_note_operator",
  "XTracker::Schema::Result::Public::Operator",
  { id => "packing_note_operator_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "product",
  "XTracker::Schema::Result::Public::Product",
  { id => "product_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:l+LmZbK9ExPfWx8TrNKjQw

=head1 NAME

XTracker::Schema::Result::Public::ShippingAttribute

=cut

use MooseX::Params::Validate;

use XT::Data::Types 'PosNum';

__PACKAGE__->load_components( qw/AuditLog/ );
__PACKAGE__->add_audit_recents_rel;
__PACKAGE__->audit_columns(qw/length width height weight/);

=head2 add_volumetrics(:length, :width, :height) :

Insert values for 'C<length>', 'C<width>' and 'C<height>' in cm.

=cut

sub add_volumetrics {
    my $self = shift;
    my (%args) = validated_hash(\@_,
        # As our defaults are worked out dynamically we can't cache this
        MX_PARAMS_VALIDATE_NO_CACHE => 1,
        # Explicitly passing a value of 'undef' is *not* the same as not
        # passing the value at all. The former will try and update the field,
        # the latter won't.
        map { $_ => { isa => 'XT::Data::Types::PosNum|Undef', default => $self->$_ } } qw/length width height/
    );

    die "Volumetrics (length, width and height) must all be either set or unset\n"
        if scalar grep { $_ != keys %args && $_ != 0 }
           scalar grep { defined $args{$_} } keys %args;

    return $self->update(\%args);
}

1;
