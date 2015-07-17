use utf8;
package XTracker::Schema::Result::Public::StockOrder;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.stock_order");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "stock_order_id_seq",
  },
  "product_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "purchase_order_id",
  { data_type => "integer", is_nullable => 0 },
  "start_ship_date",
  { data_type => "timestamp", is_nullable => 1 },
  "cancel_ship_date",
  { data_type => "timestamp", is_nullable => 1 },
  "status_id",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 0,
  },
  "comment",
  { data_type => "text", is_nullable => 1 },
  "type_id",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 0,
  },
  "consignment",
  { data_type => "boolean", is_nullable => 1 },
  "cancel",
  { data_type => "boolean", is_nullable => 1 },
  "confirmed",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "shipment_window_type_id",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 0,
  },
  "voucher_product_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "stock_order_cancel",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "link_delivery__stock_orders",
  "XTracker::Schema::Result::Public::LinkDeliveryStockOrder",
  { "foreign.stock_order_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "public_product",
  "XTracker::Schema::Result::Public::Product",
  { id => "product_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "shipment_window_type",
  "XTracker::Schema::Result::Public::ShipmentWindowType",
  { id => "shipment_window_type_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "status",
  "XTracker::Schema::Result::Public::StockOrderStatus",
  { id => "status_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "stock_order_items",
  "XTracker::Schema::Result::Public::StockOrderItem",
  { "foreign.stock_order_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "type",
  "XTracker::Schema::Result::Public::StockOrderType",
  { id => "type_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "voucher_product",
  "XTracker::Schema::Result::Voucher::Product",
  { id => "voucher_product_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:WPaWAl6BYv9wB51FsskM0A

__PACKAGE__->many_to_many (
    'deliveries', 'link_delivery__stock_orders' => 'delivery'
);

__PACKAGE__->belongs_to(
    'purchase_order',
    "XTracker::Schema::Result::Public::SuperPurchaseOrder",
    { 'foreign.id' => 'self.purchase_order_id' },
);


=head2 why_cannot_create_packing_slip

After call to can_create_packing_slip, if the result was false, this attribute will
contain a string with the reason why.

If the result was true, this will be undef.

=cut
# Non-DB accessor on the object
__PACKAGE__->mk_group_accessors( simple => 'why_cannot_create_packing_slip' );



use DateTime;
use XTracker::Constants::FromDB qw(
  :delivery_status
  :delivery_type
  :stock_order_item_status
  :stock_order_status
);

=head2 check_status

Returns the status that the stock_order object should be in. Replaces
XTracker::Database::PurchaseOrder::check_stock_order_status

=cut

sub check_status {
    my ($self) = @_;
    my $status_id_col = $self->stock_order_items
                             ->search( { cancel => 0 } )
                             ->get_column('status_id');

    my ($min, $max) = ($status_id_col->min, $status_id_col->max);

    return $STOCK_ORDER_STATUS__DELIVERED
      if defined $min && $min == $STOCK_ORDER_ITEM_STATUS__DELIVERED;
    return $STOCK_ORDER_STATUS__ON_ORDER
      if !defined $max || $max == $STOCK_ORDER_ITEM_STATUS__ON_ORDER;
    return $STOCK_ORDER_STATUS__PART_DELIVERED;
}

=head2 update_status

Update the status to what it should be (by calling check_status
and setting status_id to the result).

=cut

sub update_status {
    my ($self) = @_;
    $self->update({ status_id => $self->check_status });
}

=head2 can_create_packing_slip

If it's ok to create a packing slip, returns true. Otherwise, returns false.

By create a packing slip, we mean enter packing slip values into XT
on the Goods In Stock In PackingSlip screen.

If it's not possible, $self->why_cannot_create_packing_slip will return a string with the reason.
=cut

sub can_create_packing_slip {
    my ($self) = @_;

    my $status = $self->check_status;

    # Look for reasons why we can't submit the packing slip
    my $why_not;

    # Need a stock order status, or something's very broken
    $why_not = "Stock order status is undefined"
        unless defined $status;

    # Can't enter packing slip on delivered stock order
    $why_not = "Stock order is already delivered"
        unless $status < $STOCK_ORDER_ITEM_STATUS__DELIVERED;

    # save the reason for future reference
    $self->why_cannot_create_packing_slip( $why_not );

    # if we can't see a reason not to, return true
    return !$why_not;
}

=head2 product

Get the related product or voucher row.

=cut

sub product {
    return $_[0]->public_product || $_[0]->voucher_product;
}

=head2 product_channel

Get the related product_channel if there is one. Returns unless stock order
object has a product (i.e. not a voucher) associated with it.

=cut

sub product_channel {
    my ( $self ) = @_;
    return unless $self->public_product;
    my $product_channel
        = $self->public_product
               ->product_channel
               ->search({channel_id=>$self->purchase_order->channel_id})
               ->next;
    return $product_channel;
}

sub quantity_ordered {
    return shift->search_related('stock_order_items', {'cancel'=>0})
                ->get_column('quantity')->sum;
}

sub originally_ordered {
    return $_[0]->stock_order_items
                ->get_column('quantity')->sum;
}

sub quantity_delivered {
    return $_[0]->stock_order_items
                ->related_resultset('link_delivery_item__stock_order_items')
                ->search_related('delivery_item', {'delivery_item.cancel'=>0})
                ->get_column('quantity')
                ->sum;
}

=head2 create_delivery

Create a delivery for this stock order object. This should normally be run
without args to be created in its first state. status_id and type_id can be
passed for testing/debugging purposes.

=cut

sub create_delivery {
    my ( $self, $status_id, $type_id ) = @_;

    my $delivery = $self->result_source->schema->resultset('Public::Delivery')->create({
        status_id => $status_id || $DELIVERY_STATUS__NEW,
        type_id   => $type_id   || $DELIVERY_TYPE__STOCK_ORDER,
    });
    return $self->add_to_deliveries($delivery);
}


=head2 get_voucher_codes

=cut

sub get_voucher_codes {
    my ($self) = @_;
    $self->stock_order_items
         ->search_related('voucher_codes', {}, { order_by => 'voucher_codes.id' });
}

=head2 cancel_po

When cancelling a purchase order, set the cancel field to true on the child
stock order.

=cut
sub cancel_po {
    my ($self) = @_;

    $self->update({ cancel => 1 });

    return;
}

=head2 uncancel_po

When uncancelling a purchase order, set the cancel field to false on the child
stock order.

=cut
sub uncancel_po {
    my ($self) = @_;

    $self->update({ cancel => 0 });

    return;
}

1;
