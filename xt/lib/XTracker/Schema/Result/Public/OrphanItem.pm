use utf8;
package XTracker::Schema::Result::Public::OrphanItem;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.orphan_item");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "orphan_item_id_seq",
  },
  "variant_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "voucher_variant_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "container_id",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 0, size => 255 },
  "operator_id",
  {
    data_type      => "integer",
    default_value  => 1,
    is_foreign_key => 1,
    is_nullable    => 0,
  },
  "date",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
  "old_container_id",
  { data_type => "varchar", is_nullable => 1, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "container",
  "XTracker::Schema::Result::Public::Container",
  { id => "container_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "operator",
  "XTracker::Schema::Result::Public::Operator",
  { id => "operator_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "variant",
  "XTracker::Schema::Result::Public::Variant",
  { id => "variant_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "voucher_variant",
  "XTracker::Schema::Result::Voucher::Variant",
  { id => "voucher_variant_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:dTk3OJYveuIOa+n3B8RhRQ

# Make sure "container" is transformed into instance of
# NAP::DC::Barcode::Container on the way from database
# and stringifed on the way back to DB
#
use NAP::DC::Barcode::Container;
__PACKAGE__->inflate_column('container_id', {
    inflate => sub { NAP::DC::Barcode::Container->new_from_id(shift) },
    deflate => sub { shift->as_id },
});

=head2 orphan_item_into

=cut

sub orphan_item_into {
    my ($self, $container_id, $options) = @_;

    my $container=$self->result_source
                       ->schema
                       ->resultset('Public::Container')
                       ->find_or_create({ id => $container_id })
                       ->discard_changes;

    $container->add_orphan_item( { orphan_item => $self,
                                   dont_validate => $options->{dont_validate} });

    return $self;
}

sub unpick {
    my ($self) = @_;

    return unless $self->container;

    $self->container->remove_item( { orphan_item => $self } );
}

=head2 get_sku

Looks up the SKU of the variant or voucher variant

=cut

sub get_sku {
    return shift->get_true_variant->sku;
}

sub get_product_id {
    my ($self) = @_;
    return $self->variant ?
        $self->variant->product->id :
        $self->voucher_variant->product->id;
}

sub get_channel {
    my ($self) = @_;

    return $self->variant ?
        $self->variant->product->get_product_channel->channel :
        $self->voucher_variant->product->channel;
}

=head2 get_true_variant

Get either the voucher_variant or variant

=cut

sub get_true_variant {
    my ($self) = @_;

    if ($self->variant) {
    return $self->variant;
    } elsif ($self->voucher_variant) {
    return $self->voucher_variant;
    } else {
    die qq{ Can't relate this item to either a 'variant' or 'voucher_variant' };
    }
}

# You can replace this text with custom content, and it will be preserved on regeneration
1;
