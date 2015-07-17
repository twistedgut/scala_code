use utf8;
package XTracker::Schema::Result::Public::PurchaseOrder;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.purchase_order");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "purchase_order_id_seq",
  },
  "purchase_order_number",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "date",
  {
    data_type     => "timestamp",
    default_value => \"('now'::text)::timestamp(6) with time zone",
    is_nullable   => 0,
  },
  "currency_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "status_id",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 1,
  },
  "exchange_rate",
  { data_type => "double precision", is_nullable => 1 },
  "cancel",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "supplier_id",
  { data_type => "integer", is_nullable => 1 },
  "channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "type_id",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 1,
  },
  "comment",
  { data_type => "text", is_nullable => 1 },
  "designer_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "description",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "season_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "act_id",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 0,
  },
  "confirmed",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "confirmed_operator_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "placed_by",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "when_confirmed",
  { data_type => "timestamp with time zone", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "act",
  "XTracker::Schema::Result::Public::SeasonAct",
  { id => "act_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "channel",
  "XTracker::Schema::Result::Public::Channel",
  { id => "channel_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "confirmed_operator",
  "XTracker::Schema::Result::Public::Operator",
  { id => "confirmed_operator_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "currency",
  "XTracker::Schema::Result::Public::Currency",
  { id => "currency_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "designer",
  "XTracker::Schema::Result::Public::Designer",
  { id => "designer_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "season",
  "XTracker::Schema::Result::Public::Season",
  { id => "season_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "status",
  "XTracker::Schema::Result::Public::PurchaseOrderStatus",
  { id => "status_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "type",
  "XTracker::Schema::Result::Public::PurchaseOrderType",
  { id => "type_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:5/4Ip1PzMvWEBnEHbTjYkA

# we really don't want to do this with a "use base", we need all the
# above declarations to have run already
## no critic(ProhibitExplicitISA)
our @ISA;
require XTracker::Schema::Result::Public::SuperPurchaseOrder;
@ISA = ('XTracker::Schema::Result::Public::SuperPurchaseOrder');

use XTracker::Config::Local "enable_edit_purchase_order";
use XTracker::Database::Pricing qw( set_purchase_price );
use NAP::XT::Exception::EditPO::PurchaseOrderAlreadyEditable;
use XTracker::Logfile 'xt_logger';

__PACKAGE__->has_many(
    'stock_orders',
    'XTracker::Schema::Result::Public::StockOrder',
    { 'foreign.purchase_order_id' => 'self.id' },
);

__PACKAGE__->might_have(
    is_not_editable_in_fulcrum =>
    'XTracker::Schema::Result::Public::PurchaseOrderNotEditableInFulcrum',
    { 'foreign.number' => 'self.purchase_order_number' },
);

# apply magic to make this horrible inheritance work, after all rels
# are set up.  this breaks under DBIx::Class::Schema::Loader's
# reloading shenanigans, but isn't needed for schema dumping, so
# disable it if Schema::Loader is loaded
__PACKAGE__->spo_register_subclass
    unless exists $INC{"DBIx/Class/Schema/Loader.pm"};

=head2 update_purchase_order

updated the stock_order and price_purchase table for a given purchase order

=cut
sub update_purchase_order {
    my ($self, $purchase_order_hash ) = @_;
    # Get all stock order records for the products we have sent for update.
    my @stock_order_products_rs = $self->stock_orders->search({
        product_id => { -in => [ keys %{$purchase_order_hash//{}} ] }
    })->all;

    # Store the row objects in a hash, and access them via product_id in the loop
    my $products_by_id = {};
    $products_by_id->{ $_->product_id } = $_ foreach @stock_order_products_rs;

    while ( my ( $product_id, $purchase_order_data ) = each %{$purchase_order_hash} ) {
        # $stock_order is a Public::StockOrder row object
        my $stock_order = $products_by_id->{ $product_id };


        if (
            $purchase_order_data->{cancel}
            && !$stock_order->cancel
               # PM-1871 - take cancelled deliveries into account
            && $stock_order->deliveries->count( { cancel => 0 } )
        ) {
            die   "Error: "
                . "PID $product_id cannot be cancelled; "
                . "there are uncancelled deliveries for this PID"
                . "\n";
        }

        $stock_order->update({
            start_ship_date         => $purchase_order_data->{ship_date},
            cancel_ship_date        => $purchase_order_data->{cancel_date},
            shipment_window_type_id => $purchase_order_data->{shipment_window_type},
            stock_order_cancel      => $purchase_order_data->{cancel}, # boolean true|false
            cancel                  => $purchase_order_data->{cancel}, # boolean true|false
        });

        my $stock_order_items = $stock_order->stock_order_items;
        while ( my $soi = $stock_order_items->next ) {
            # Update the stock order item's cancel status
            $soi->update({
                stock_order_item_cancel => $purchase_order_data->{cancel}, # boolean true|false
                cancel                  => $purchase_order_data->{cancel}, # boolean true|false
            });
            # Update the status_id of the stock order item
            $soi->update_status;
        }
        # Update the status_id of the stock order
        $stock_order->update_status;

        $stock_order->public_product->price_purchase->update({
            original_wholesale => $purchase_order_data->{original_wholesale},
            wholesale_price    => $purchase_order_data->{wholesale_cost}
        });
    }
    # Update the status_id of the purchase order
    $self->update_status();

}

=head2 update

Update PurchaseOrder data.

It makes sure the PO number doesn't already exists when updating it and the
Public::PurchaseOrdersNotEditableInFulcrum table is kept in sync

=cut

sub update {
    my ($self, $args) = @_;

    my $schema = $self->result_source->schema;
    my $guard = $schema->storage->txn_scope_guard;

    my $purchase_order_number = $args->{purchase_order_number};
    if (defined $purchase_order_number) {
      if ($schema->resultset('Public::PurchaseOrder')->search({ purchase_order_number => $purchase_order_number },)->count) {
        xt_logger->info("PO $purchase_order_number already exists");
        return undef;
      }
      $self->update_not_editable_in_fulcrum( $purchase_order_number );
    }

    my $updated_po = $self->SUPER::update($args);

    $guard->commit;

    return $updated_po;
}

=head2 update_not_editable_in_fulcrum

Update PO number in Public::PurchaseOrdersNotEditableInFulcrum

=cut

sub update_not_editable_in_fulcrum {
    my ($self, $purchase_order_number) = @_;

    my $po_not_editable_in_fulcrum = $self->is_not_editable_in_fulcrum;

    return 0 unless $po_not_editable_in_fulcrum;

    xt_logger->info("Updating PO number with value '$purchase_order_number' in PurchaseOrdersNotEditableInFulcrum");
    $po_not_editable_in_fulcrum->update({ number => $purchase_order_number });

    return 1;
}

=head2 is_editable_in_xt

Returns TRUE if the relationship $self->is_not_editable_in_fulcrum exists, FALSE otherwise

=cut
sub is_editable_in_xt {
    my $self = shift;
    if ( enable_edit_purchase_order || $self->is_not_editable_in_fulcrum ) {
        return 1;
    }
    else {
        return;
    }
}

=head2 enable_edit_po_in_xt

Enable purchase order to be editable in XT.

=cut
sub enable_edit_po_in_xt {
    my ($self, $data) = @_;

    # Throw exception if PO already editable in XT,
    # we don't want to add duplicate records.
    NAP::XT::Exception::EditPO::PurchaseOrderAlreadyEditable->throw()
      if $self->is_editable_in_xt;

    # Add purchase order number to Public::PurchaseOrderNotEditableInFulcrum
    # table.
    $self->create_related('is_not_editable_in_fulcrum',
        { number => $self->purchase_order_number } );

}

1;
