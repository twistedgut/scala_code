use utf8;
package XTracker::Schema::Result::Public::SuperPurchaseOrder;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.super_purchase_order");
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
  { data_type => "boolean", default_value => \"false", is_nullable => 1 },
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
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "channel",
  "XTracker::Schema::Result::Public::Channel",
  { id => "channel_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
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
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:0uf7B3OtU6c7R/QOVIIvvQ

use Carp qw/confess/;
use Moose;

__PACKAGE__->has_many(
    "stock_orders",
    "XTracker::Schema::Result::Public::StockOrder",
    { "foreign.purchase_order_id" => "self.id" },
);

__PACKAGE__->belongs_to(
  "season",
  "XTracker::Schema::Result::Public::Season",
  { id => "season_id" },
  { join_type => "LEFT" },
);

__PACKAGE__->belongs_to(
    'currency' => 'XTracker::Schema::Result::Public::Currency',
    { 'foreign.id' => 'self.currency_id' },
    { join_type => 'LEFT' },
);

use XTracker::Constants::FromDB qw(
  :purchase_order_status
  :stock_order_status
);

use XTracker::WebContent::StockManagement::Broadcast;

# This is a badly named column, also it should arguably be a status
sub is_cancelled {
  $_[0]->get_column('cancel');
}

=head2 check_status

Checks the status of the stock_order rows for the purchase_order and returns
the status the PO should be in. Replaces
XTracker::Database::PurchaseOrder::check_purchase_order_status.

=cut

sub check_status {
    my ($self) = @_;
    my $status_id_col =
      $self->stock_orders->search( { cancel => 0 } )->get_column('status_id');

    return $PURCHASE_ORDER_STATUS__DELIVERED
      if $status_id_col->min == $STOCK_ORDER_STATUS__DELIVERED;
    return $PURCHASE_ORDER_STATUS__ON_ORDER
      if $status_id_col->max == $STOCK_ORDER_STATUS__ON_ORDER;
    return $PURCHASE_ORDER_STATUS__PART_DELIVERED;
}

=head2 update_status

Update the status to what it should be (by calling check_status
and setting status_id to the result).

=cut

sub update_status {
    my ($self) = @_;

    $self->update({ status_id => $self->check_status });

    $self->broadcast_stock_updates;
}


sub stock_orders_by_pid {
    return $_[0]->search_related('stock_orders', undef, {order_by => 'product_id'});
}

=head2 inflate_result

Right - so this super_purchase_order table is inherited by public.purchase_order and
voucher.purchase_order as C<INHERITS(super_purchase_order)>. But we never want
to get a SuperPurchaseOrder row out. We also don't want to have to prefetch on
the two possible child rels form this source as it vastly complicates *using*
this source.

So what we do is create a virtual view that does:

 SELECT 'public' AS vti_type, <common columns>, <public columns> <NULL for each voucher column>
  UNION
 SELECT 'voucher' AS vti_type, <common columns>, <NULL for each public column>, <volumn columns>

We then install a custom inflate_result that examines this column and then
creates the correct result type.

The magic happens when the subclass calls:

  __PACKAGE__->spo_register_subclass;

=cut

__PACKAGE__->table_class('DBIx::Class::ResultSource::View');
__PACKAGE__->table("super_purchase_order");

my %sub_po;

sub spo_register_subclass {
    my ($subclass) = @_;

    my $my_po = __PACKAGE__->result_source_instance;
    my $sub_po = $subclass->result_source_instance;
    # a clean name to use as discriminant in the SQL
    my $sub_name = $sub_po->name =~ s{\W+}{_}gr;

    $sub_po{$sub_name} = $subclass;

    $my_po->is_virtual(1);

    __PACKAGE__->_rebuild_sql;
}

sub _rebuild_sql {
    # we now re-build our SQL "view"

    # Work out what columns are needed
    my (%all, %per_sub);

    for my $sub_name (keys %sub_po) {
        # list of columns required for this subclass
        my @cols = $sub_po{$sub_name}->result_source_instance->columns;
        # set of them
        @{$per_sub{$sub_name}}{@cols}=();
        # add them to the "all" set
        @all{@cols}=();
    }
    # now %all contains all columns, and $per_sub{foo} contains foo's
    # columns

    my @sql_snippets;
    for my $sub_name (keys %sub_po) {
        # columns, sorted by their name, some "nulled" if they don't
        # belong to this sub-class
        my @sub_cols = map {
            exists $per_sub{$sub_name}->{$_} ? $_ : "NULL AS $_"
        } sort keys %all;

        my $sql_snippet =
            "SELECT '$sub_name' AS purchase_order_subclass_type, " .
                join(', ',@sub_cols) .
                    ' FROM ' .
                        $sub_po{$sub_name}->result_source_instance->from;

        push @sql_snippets,$sql_snippet;
    }
    my $sql = join "\nUNION\n", @sql_snippets;

    # and finally we re-assign our view defition query
    __PACKAGE__->result_source_instance->view_definition( $sql );
    __PACKAGE__->add_columns('purchase_order_subclass_type', keys %all);
}

sub inflate_result {
    my ($class, $source, $cols, $prefetch) = @_;

    # Work out which (subclass) to bless it into.
    if ( $class eq __PACKAGE__) {

        confess "super_purchase_order.purchase_order_subclass_type virtual column not loaded!"
            unless $cols->{purchase_order_subclass_type};

        my $sub_po_type = delete $cols->{purchase_order_subclass_type};
        my $source_name = $sub_po{$sub_po_type};

        # Remove columns that are useless for the actual sub-po we want
        my %sub_cols = map { $_ => $cols->{$_} }
            $source_name->result_source_instance->columns;

        $source = $source->schema->source($source_name);

        # This calls into DBIC and does the bless into the (new) $class
        return $source_name->inflate_result($source, $cols, $prefetch);
    }
    else {
        return $class->next::method($source,$cols,$prefetch);
    }
}

=head2 is_product_po

Returns a true value if this purchase order is for products.

=cut

sub is_product_po {
    return ( ref $_[0]) =~ m{Public::PurchaseOrder$};
}

=head2 is_voucher_po

Returns a true value if this purchase order is for vouchers.

=cut

sub is_voucher_po {
    return ( ref $_[0]) =~ m{Voucher::PurchaseOrder$};
}

=head2 quantity_ordered

Returns the number of non-cancelled items in the purchase order.

=cut

sub quantity_ordered {
    return shift->stock_orders
                ->search_related(
                    'stock_order_items',
                    {'stock_order_items.cancel' => 0})
                ->get_column('quantity')
                ->sum;
}

=head2 originally_ordered

Returns the full number of items in the purchase order.

=cut

sub originally_ordered {
    return $_[0]->stock_orders
                ->related_resultset('stock_order_items')
                ->get_column('quantity')
                ->sum;
}

=head2 quantity_delivered

Returns the number of items that have been delivered.

=cut

sub quantity_delivered {
    return $_[0]->stock_orders
                ->related_resultset('stock_order_items')
                ->related_resultset('link_delivery_item__stock_order_items')
                ->search_related('delivery_item', { 'delivery_item.cancel' => 0})
                ->get_column('delivery_item.quantity')
                ->sum;
}

=head2 cancel_po

Cancel a purchase order

=cut
sub cancel_po {
    my ($self)=@_;

    $self->result_source->schema->txn_do(sub{

        $self->update({ cancel=>1 });
        # Set the cancel flag for the stock orders and stock order items to reflect
        # that the purchase order they belong to has been cancelled.
        foreach my $stock_order ( $self->stock_orders ) {
            $stock_order->cancel_po();
            foreach my $stock_order_item ( $stock_order->stock_order_items ) {
                $stock_order_item->cancel_po();
            }
        }

        $self->broadcast_stock_updates;

    });
}

=head2 uncancel_po

Un-cancel a purchase order

=cut
sub uncancel_po{
    my ($self) = @_;

    $self->result_source->schema->txn_do(sub{
        $self->update({ cancel=>0 });

        my $args;

        # Set the cancel flag for the stock orders and stock order items to reflect
        # that the purchase order they belong to has been uncancelled.
        foreach my $stock_order ( $self->stock_orders ) {
            # If the stock_order has been cancelled by editpo skip
            next if $stock_order->stock_order_cancel;
            $stock_order->uncancel_po();
            foreach my $stock_order_item ( $stock_order->stock_order_items ) {
                # If the stock order item was cancelled via EditPO, i.e units set to 0.
                next if $stock_order_item->stock_order_item_cancel;
                $stock_order_item->uncancel_po();
            }
        }

        # Set an uncancel flag for the purpose of broadcasting stock updates.
        $args->{ uncancel } = 1;
        # Broadcast the original quantities back to the product service
        $self->broadcast_stock_updates( $args );
    });

    return;
}

sub broadcast_stock_updates {
    my ($self, $args) = @_;

    my $broadcast = XTracker::WebContent::StockManagement::Broadcast->new({
        schema => $self->result_source->schema,
        channel_id => $self->channel_id,
    });

    my $so_rs = $self->search_related('stock_orders');
    while (my $so = $so_rs->next) {

        $broadcast->stock_update(
            quantity_change => $args->{'uncancel'} ? $so->quantity_ordered : 0,
            product_id => $so->product_id // $so->voucher_product_id,
            full_details => 1,
        );
    }
    $broadcast->commit;
}

no Moose;

1;
