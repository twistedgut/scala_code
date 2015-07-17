use utf8;
package XTracker::Schema::Result::Public::RenumerationItem;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.renumeration_item");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "renumeration_item_id_seq",
  },
  "renumeration_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "shipment_item_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "unit_price",
  { data_type => "numeric", is_nullable => 0, size => [10, 3] },
  "tax",
  { data_type => "numeric", is_nullable => 0, size => [10, 3] },
  "duty",
  { data_type => "numeric", is_nullable => 0, size => [10, 3] },
  "last_updated",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "renumeration",
  "XTracker::Schema::Result::Public::Renumeration",
  { id => "renumeration_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "shipment_item",
  "XTracker::Schema::Result::Public::ShipmentItem",
  { id => "shipment_item_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:OchJNtkDSbKJ4B+3TZSgTw

=head1 NAME

XTracker::Schema::Result::Public::RenumerationItem

=head1 METHODS

=head2 format_as_refund_line_item

Returns a HashRef of data with the following keys: C<sku>, C<name>, C<amount>,
C<vat> and C<tax>. They are all self explanatory, with the exception of C<name>
which returns the name of the associated product and C<amount> which returns
the result of the C<total_price> method.

    my $hashref = $self->format_as_refund_line_item;

=cut

sub format_as_refund_line_item {
    my $self = shift;

    my $variant = $self->shipment_item->variant;

    return {
        sku     => $variant->sku,
        name    => $variant->product->name,
        amount  => $self->total_price   * 100,
        vat     => $self->tax           * 100,
        tax     => $self->duty          * 100,
    };

}

=head2 total_price

Returns the total price of the Renumeration Item including all taxes,
currently this equates to C<unit_price> + C<tax> + C<duty>.

    my $total_price = $self->total_price;

=cut

sub total_price {
    my $self = shift;

    return $self->unit_price
        + $self->tax
        + $self->duty;

}

1;
