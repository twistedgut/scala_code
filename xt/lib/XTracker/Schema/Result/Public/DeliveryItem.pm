use utf8;
package XTracker::Schema::Result::Public::DeliveryItem;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.delivery_item");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "delivery_item_id_seq",
  },
  "delivery_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "packing_slip",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "quantity",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "status_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "cancel",
  { data_type => "boolean", default_value => \"false", is_nullable => 1 },
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
  "delivery",
  "XTracker::Schema::Result::Public::Delivery",
  { id => "delivery_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "link_delivery_item__quarantine_processes",
  "XTracker::Schema::Result::Public::LinkDeliveryItemQuarantineProcess",
  { "foreign.delivery_item_id" => "self.id" },
  undef,
);
__PACKAGE__->might_have(
  "link_delivery_item__return_item",
  "XTracker::Schema::Result::Public::LinkDeliveryItemReturnItem",
  { "foreign.delivery_item_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "link_delivery_item__shipment_items",
  "XTracker::Schema::Result::Public::LinkDeliveryItemShipmentItem",
  { "foreign.delivery_item_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "link_delivery_item__stock_order_items",
  "XTracker::Schema::Result::Public::LinkDeliveryItemStockOrderItem",
  { "foreign.delivery_item_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "rma_request_details",
  "XTracker::Schema::Result::Public::RmaRequestDetail",
  { "foreign.delivery_item_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "rtv_quantities",
  "XTracker::Schema::Result::Public::RTVQuantity",
  { "foreign.delivery_item_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "status",
  "XTracker::Schema::Result::Public::DeliveryItemStatus",
  { id => "status_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "stock_processes",
  "XTracker::Schema::Result::Public::StockProcess",
  { "foreign.delivery_item_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "type",
  "XTracker::Schema::Result::Public::DeliveryItemType",
  { id => "type_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->many_to_many(
  "quarantine_processes",
  "link_delivery_item__quarantine_processes",
  "quarantine_process",
);
__PACKAGE__->many_to_many(
  "shipment_items",
  "link_delivery_item__shipment_items",
  "shipment_item",
);
__PACKAGE__->many_to_many(
  "stock_order_items",
  "link_delivery_item__stock_order_items",
  "stock_order_item",
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:MhGz+SShjYAOc/k1q9Bjcw

use Carp;
use XTracker::Constants::FromDB qw(:delivery_item_status);

=head2

Returns the shipment item or undef

=cut

sub get_shipment_item {
    my ($self) = @_;

    my $link = $self->link_delivery_item__shipment_items->first;
    return $link ? $link->shipment_item : undef;
}

=head2

Returns the shipment item or undef

=cut

sub get_return_item {
    my ($self) = @_;

    my $link = $self->link_delivery_item__return_item;
    return $link ? $link->return_item : undef;
}


=head2

Returns the stock_order_item (there should only ever be one) for this object.

=cut

sub stock_order_item {
    return $_[0]->stock_order_items->first;
}

=head2 $delivery_item->update_status( $stock_process_id | $delivery_item_id, $status_type, $status_id )

=cut

sub update_status {
    my ( $record, $stock_process_id, $source, $type_id ) = @_;

    my $status_type = {
        delivery_item_id => $stock_process_id,
        stock_process_id => $record
                          ->result_source
                          ->schema
                          ->resultset('Public::StockProcess')
                          ->find($stock_process_id)
                          ->delivery_item_id,
    };

    my $status_id = $status_type->{$source};
    if ( not defined $status_id ) {
        croak 'This subroutine only accepts delivery_item_id or
            stock_process_id as its second argument';
    }

    $record->update(
        { status_id => $type_id, }
    );
    return;
}

=head2 is_status_valid

Check if the delivery_item can advance to the given status

=cut

sub is_status_valid {
    my ( $self, $status_id ) = @_;
    return $self->status_id < $status_id;
}

=head2 is_item_count_valid

Returns true if packing slip is non-zero (BA-276) and equal to item count

=cut

sub is_item_count_valid {
    my ( $self, $item_count ) = @_;
    return !$self->packing_slip || $self->packing_slip == $item_count;
}


# This is a badly named column, also it should arguably be a status
sub is_cancelled {
  $_[0]->get_column('cancel');
}


=head2 stock_process

Returns a stock_process item. Dies if there are more than one.

=head3 CAVEAT

Only call this when you know there will be a single stock process against a
delivery item - i.e. against customer returns.

=cut

sub stock_process {
    my ($self) = @_;

    my $rs = $self->stock_processes;

    my $sp = $rs->next;

    die "More than one stock process for delivery item @{[$self->id]} - don't call stock_process!"
        if $rs->next;
    return $sp;
}

=head2 stock_processes_complete

Checks if all the related stock_process rows are complete.

=cut

sub stock_processes_complete {
    return $_[0]->stock_processes->get_column('complete')->func('bool_and');
}

=head2 complete

Change the status of the delivery item to completed.

=cut

sub complete {
    return $_[0]->update({status_id=>$DELIVERY_ITEM_STATUS__COMPLETE});
}

=head2 variant

Tries really hard to find a corresponding variant

=cut

sub variant {
    my $delivery_item = shift;
    my $variant;

    if ( my $link_to_soi =
        $delivery_item->link_delivery_item__stock_order_items->first )
    {
        my $soi = $link_to_soi->stock_order_item;
        $variant =
          $soi->voucher_variant_id ? $soi->voucher_variant : $soi->variant;
    }
    elsif ( my $link_to_ri = $delivery_item->link_delivery_item__return_item ) {
        $variant = $link_to_ri->return_item->variant;
    }
    elsif ( my $link_to_qp =
        $delivery_item->link_delivery_item__quarantine_processes->first )
    {
        $variant = $link_to_qp->quarantine_process->variant;
    }
    elsif ( my $link_to_si =
        $delivery_item->link_delivery_item__shipment_items->first )
    {
        my $si = $link_to_si->shipment_item;
        $variant =
          $si->voucher_variant_id ? $si->voucher_variant : $si->variant;
    }

    $variant;
}

1;
