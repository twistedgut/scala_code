use utf8;
package XTracker::Schema::Result::Voucher::PurchaseOrder;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("voucher.purchase_order");
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
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "type_id",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 1,
  },
  "created_by",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "channel",
  "XTracker::Schema::Result::Public::Channel",
  { id => "channel_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "created_by",
  "XTracker::Schema::Result::Public::Operator",
  { id => "created_by" },
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
  "supplier",
  "XTracker::Schema::Result::Public::Supplier",
  { id => "supplier_id" },
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
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:yf5XEizXRX1FySSMOm/1dA

__PACKAGE__->has_many(
    "stock_orders",
    "XTracker::Schema::Result::Public::StockOrder",
    { "foreign.purchase_order_id" => "self.id" },
);

# we really don't want to do this with a "use base", we need all the
# above declarations to have run already
## no critic(ProhibitExplicitISA)
our @ISA;
require XTracker::Schema::Result::Public::SuperPurchaseOrder;
@ISA = ('XTracker::Schema::Result::Public::SuperPurchaseOrder');
# apply magic to make this horrible inheritance work.  this breaks
# under DBIx::Class::Schema::Loader's reloading shenanigans, but isn't
# needed for schema dumping, so disable it if Schema::Loader is loaded
__PACKAGE__->spo_register_subclass
    unless exists $INC{"DBIx/Class/Schema/Loader.pm"};

sub vouchers {
    my ($self) = @_;

    $self->stock_orders->related_resultset('voucher_product');
}

# why is this here? it's the same as the inherited one!
sub cancel_po {
    my ($self) = @_;
    eval{
        $self->result_source->schema->txn_do(sub{
            $self->update({ cancel => 1 });
            $self->stock_orders
                 ->related_resultset('stock_order_items')
                 ->update({ cancel => 1 });
            $self->stock_orders
                 ->update({ cancel => 1 });
        });
        $self->broadcast_stock_updates;
    };
    if ( my $e = $@ ) {
        die "Couldn't cancel purchase order: $e\n";
    }
}

1;
