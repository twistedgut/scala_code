use utf8;
package XTracker::Schema::Result::Public::StockOrderItem;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.stock_order_item");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "stock_order_item_id_seq",
  },
  "stock_order_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "variant_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "quantity",
  { data_type => "integer", is_nullable => 0 },
  "status_id",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 0,
  },
  "type_id",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 0,
  },
  "cancel",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "original_quantity",
  { data_type => "integer", is_nullable => 1 },
  "voucher_variant_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "stock_order_item_cancel",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "link_delivery_item__stock_order_items",
  "XTracker::Schema::Result::Public::LinkDeliveryItemStockOrderItem",
  { "foreign.stock_order_item_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "status",
  "XTracker::Schema::Result::Public::StockOrderItemStatus",
  { id => "status_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "stock_order",
  "XTracker::Schema::Result::Public::StockOrder",
  { id => "stock_order_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "type",
  "XTracker::Schema::Result::Public::StockOrderItemType",
  { id => "type_id" },
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
__PACKAGE__->has_many(
  "voucher_codes",
  "XTracker::Schema::Result::Voucher::Code",
  { "foreign.stock_order_item_id" => "self.id" },
  undef,
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
__PACKAGE__->many_to_many(
  "delivery_items",
  "link_delivery_item__stock_order_items",
  "delivery_item",
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:kMRK1ZSDJ9BGUulYxB/yCQ

use XTracker::Constants::FromDB qw(
    :delivery_item_status
    :delivery_item_type
    :stock_order_item_status
);

__PACKAGE__->belongs_to(
  "product_variant",
  "XTracker::Schema::Result::Public::Variant",
  { id => "variant_id" },
);

=head2 check_status

Returns what status the stock_order_item should be in by comparing the
delivered quantity to the ordered quantity ($self->quantity).
Replaces XTracker::Database::PurchaseOrder::soi_status

=cut

sub check_status {
    my ( $self ) = @_;

    my $delivered = $self->delivery_items
                         ->search({cancel=>0})
                         ->get_column('quantity')
                         ->sum
                    // 0;

    return $STOCK_ORDER_ITEM_STATUS__ON_ORDER
        if $delivered == 0;
    return $STOCK_ORDER_ITEM_STATUS__DELIVERED
        if $delivered >= $self->quantity;
    return $STOCK_ORDER_ITEM_STATUS__PART_DELIVERED;
}

=head2 update_status

Update the status to what it should be (by calling check_status
and setting status_id to the result).

=cut

sub update_status {
    my ($self) = @_;

    $self->update({ status_id => $self->check_status });
}

=head2 variant

Call the product or voucher variant for this object.

=cut

{
    no warnings "redefine";
    *variant = sub {
        return $_[0]->product_variant || $_[0]->voucher_variant;
    };
}

=head2 get_delivered_quantity

Get the quantity of non-cancelled deliveries of the variant in the purchase
order. Replaces XTracker::Database::Stock::get_delivered_quantity().

=cut

sub get_delivered_quantity {
    return $_[0]->delivery_items
                ->search({cancel=>0})
                ->get_column('quantity')
                ->sum;
}

=head2 is_cancelled

Return true if stock order item is cancelled.

=cut

sub is_cancelled {
    return $_[0]->cancel == 1;
}

=head2 is_delivered

Return true if stock order item is delivered.

=cut

sub is_delivered {
    return $_[0]->status_id == $STOCK_ORDER_ITEM_STATUS__DELIVERED;
}

=head2 cancel_po

When cancelling a purchase order, set the cancel field to true on the child
stock order items.

=cut
sub cancel_po {
    my ($self) = @_;

    $self->update({ cancel => 1 });

    return;
}

=head2 uncancel_po

When cancelling a purchase order, set the cancel field to false on the child
stock order items.

=cut
sub uncancel_po {
    my ($self) = @_;

    $self->update({ cancel => 0 });

    return;
}

1;
