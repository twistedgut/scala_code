use utf8;
package XTracker::Schema::Result::Public::Delivery;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.delivery");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "delivery_id_seq",
  },
  "date",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
  "invoice_nr",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "status_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "cancel",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "on_hold",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "last_updated",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "delivery_items",
  "XTracker::Schema::Result::Public::DeliveryItem",
  { "foreign.delivery_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "delivery_notes",
  "XTracker::Schema::Result::Public::DeliveryNote",
  { "foreign.delivery_id" => "self.id" },
  undef,
);
__PACKAGE__->might_have(
  "link_delivery__return",
  "XTracker::Schema::Result::Public::LinkDeliveryReturn",
  { "foreign.delivery_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "link_delivery__shipments",
  "XTracker::Schema::Result::Public::LinkDeliveryShipment",
  { "foreign.delivery_id" => "self.id" },
  undef,
);
__PACKAGE__->might_have(
  "link_delivery__stock_order",
  "XTracker::Schema::Result::Public::LinkDeliveryStockOrder",
  { "foreign.delivery_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "log_deliveries",
  "XTracker::Schema::Result::Public::LogDelivery",
  { "foreign.delivery_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "status",
  "XTracker::Schema::Result::Public::DeliveryStatus",
  { id => "status_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "type",
  "XTracker::Schema::Result::Public::DeliveryType",
  { id => "type_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->many_to_many("shipments", "link_delivery__shipments", "shipment");


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:+BQvT6wCWcgro9Igp+F/GA

use DateTime;
use XTracker::Constants ':application';
use XTracker::Constants::FromDB qw(
    :delivery_action
    :delivery_item_status
    :delivery_item_type
    :delivery_status
    :stock_process_type
);

# SchemaLoader generates an incorrect relationship with the shipment link
# table. A delivery can only be in one shipment. - DJ
__PACKAGE__->might_have(
  "link_delivery__shipment",
  "XTracker::Schema::Result::Public::LinkDeliveryShipment",
  { "foreign.delivery_id" => "self.id" },
);

=head2 shipment

Returns this delivery's shipment if it has one.

=cut

sub shipment {
    my ( $self ) = @_;
    return unless $self->link_delivery__shipment;
    return $self->link_delivery__shipment->shipment;
}

=head2 stock_order

Returns this delivery's stock_order if it has one.

=cut

sub stock_order {
    my ( $self ) = @_;
    return unless $self->link_delivery__stock_order;
    return $self->link_delivery__stock_order->stock_order;
}

=head2 create_note

Create a note for this delivery

=cut

sub create_note {
    my ( $self, $operator_id, $description ) = @_;
    return $self->add_to_delivery_notes({
        created_by  => $operator_id,
        modified_by => $operator_id,
        description => $description,
    });
}

sub order_by_created {
    my ( $self, $arg ) = @_;

    if ( not defined $arg or $arg !~ m/(?:asc|desc)/i ) {
        $arg = "ASC";
        xt_logger->warn( "Defaulted to ASC" );
    }

    my $ordered_rs = $self->delivery_notes->search(undef,
        { order_by => \"created $arg" },
    );

    return $ordered_rs;
}

=head2 hold

Takes an optional boolean argument - 0 to release, 1 to hold. Without args
marks delivery as held.

=cut

sub hold {
    my ( $self, $hold ) = @_;
    return $self->update({ on_hold => ( defined $hold ? $hold : 1 ) });
}

=head2 release

Wrapper around $delivery->hold(0).

=cut

sub release {
    return shift->hold(0);
}

sub create_delivery_items {
    my ( $self, $delivery_item_type_id, $delivery_items ) = @_;
    foreach ( @{ $delivery_items } ) {
        my $delivery_item = $self->add_to_delivery_items(
            packing_slip => $_->{packing_slip},
            type_id      => $delivery_item_type_id,
        );
        my $link_type = $_->{return_item_id}        ? 'return_item'
                      : $_->{shipment_item_id}      ? 'shipment_item'
                      : $_->{quarantine_process_id} ? 'quarantine_process'
                      :                               'stock_order_item'
                      ;
        $delivery_item->create_related("link_delivery_item__$link_type",
            ($link_type.'_id') => $_->{$link_type.'_id'}
        );
    }
    return $self->discard_changes;
}

=head2 get_total_packing_slip

Returns the sum of the packing_slip values for this delivery's delivery items.

=cut

sub get_total_packing_slip {
    return $_[0]->delivery_items->get_column('packing_slip')->sum;
}

=head2 get_total_quantity

Returns the sum of the quantity for this delivery's delivery items.

=cut

sub get_total_quantity {
    return $_[0]->delivery_items->get_column('quantity')->sum;
}

=head2 log_stock_in

Log a stock in entry for this delivery.

    $delivery->log_stock_in({
        operator_id => $operator_id,
        #optional
        notes => $notes,
    });

=cut

sub log_stock_in {
    my ( $self, $args ) = @_;
    $args->{delivery_action_id} = $DELIVERY_ACTION__CREATE;
    $args->{quantity}           = $self->get_total_packing_slip;
    $args->{type_id}            = $STOCK_PROCESS_TYPE__MAIN;
    return $self->_log($args);
}

=head2 log_item_count

Log an item count entry for this delivery.

    $delivery->log_item_count({
        operator_id => $operator_id,
        #optional
        notes => $notes,
    });

=cut

sub log_item_count {
    my ( $self, $args ) = @_;
    $args->{delivery_action_id} = $DELIVERY_ACTION__COUNT;
    $args->{quantity}           = $self->get_total_quantity;
    $args->{type_id}            = $STOCK_PROCESS_TYPE__MAIN;
    return $self->_log($args);
}

=head2 log_bag_and_tag({:type_id! :quantity! :operator_id :notes}) :

Log a bag and tag entry for this delivery.

=cut

sub log_bag_and_tag {
    my ( $self, $args ) = @_;
    return $self->_log({
        %{$args||{}},
        delivery_action_id => $DELIVERY_ACTION__BAG_AND_TAG,
    });
}

sub _log {
    my ( $self, $args ) = @_;
    return $self->create_related('log_deliveries', {
        (map { $_ => $args->{$_} } keys %$args),
        operator_id => $args->{operator_id}
                    // $self->result_source->schema->operator_id
                    // $APPLICATION_OPERATOR_ID,
    });
}

=head2 is_priority

If the delivery is a priority this sub returns true.

=cut

sub is_priority {
    my ( $self, $priority_after ) = @_;

    my $upload_date = $self->stock_order
                           ->product_channel
                           ->upload_date;
    return unless defined $upload_date;

    $upload_date->set_time_zone( 'UTC' );
    $priority_after ||= DateTime->now->subtract( days => 3 );
    $priority_after->set_time_zone( 'UTC' );
    return 1 if ( DateTime->compare( $priority_after, $upload_date ) == 1);
    return;
}

=head2 is_processing

Returns true if the delivery has a status of C<Processing>.

=cut

sub is_processing {
    $_[0]->status_id == $DELIVERY_STATUS__PROCESSING;
}

=head2 is_complete

Returns true if the delivery has been completed.

=cut

sub is_complete {
    shift->status_id == $DELIVERY_STATUS__COMPLETE;
}

=head2 has_been_qced

Returns true if the delivery has already been QCed.

=cut

sub has_been_qced {
    my $self = shift;
    return $self->is_processing || $self->is_complete;
}

# This is a badly named column, also it should arguably be a status
sub is_cancelled {
  $_[0]->get_column('cancel');
}

=head2 cancel_delivery

Not to be confused with the column (I<cancel>), this method cancels the delivery.

=head3 NOTE

This only works for deliveries that link to stock order items.

=cut

sub cancel_delivery {
    my ( $self, $operator_id ) = @_;
    my $delivery_items = $self->delivery_items;
    my $stock_processes = $delivery_items->related_resultset('stock_processes');
    my $schema = $self->result_source->schema;
    $schema->txn_do(sub{
        $stock_processes->related_resultset('putaways')->delete;
        $stock_processes->related_resultset('rtv_stock_process')->delete;
        $stock_processes->related_resultset('log_putaway_discrepancies')->delete();
        $stock_processes->delete;

        $delivery_items->update({cancel => 1});
        $self->update({cancel => 1});

        $self->create_related('log_deliveries', {
            delivery_action_id => $DELIVERY_ACTION__CANCEL,
            operator_id => $operator_id,
            quantity => 0,
            type_id => $STOCK_PROCESS_TYPE__ALL,
        });

        # TODO: Port check_soi_status to DBIC
        use XTracker::Database::PurchaseOrder;

        for ( $delivery_items->all ) {
            next unless $_->stock_order_item;
            $_->stock_order_item->update({
                status_id => XTracker::Database::PurchaseOrder::check_soi_status(
                    $schema->storage->dbh, $_->id, 'delivery_item_id'),
            });
        }
        $self->_update_statuses;
    });
    return;
}

=head2 delivery_items_complete

Returns true if the delivery's delivery items are all complete.

=cut

sub delivery_items_complete {
    my ( $self ) = @_;
    my $min_status_id = $self->search_related(
                               'delivery_items',
                               { cancel=>0,
                                 quantity=> { q{>} => 0 }, })
                             ->get_column('status_id')
                            ->min;
    return $min_status_id == $DELIVERY_ITEM_STATUS__COMPLETE;
}

=head2 complete

Mark this delivery as complete

=cut

sub complete {
    return $_[0]->update({status_id=>$DELIVERY_STATUS__COMPLETE});
}

=head2  mark_as_counted

Updates this Delivery to have a status of 'Counted' and updates the status of
the related stock order and purchase orders.

=cut

sub mark_as_counted {
    my ($self) = @_;

    $self->update({status_id => $DELIVERY_STATUS__COUNTED});

    $self->_update_statuses;
    return $self;
}

sub _update_statuses {
    my ($self) = @_;

    my $stock_order = $self->stock_order;
    $stock_order->update_status;

    $stock_order->purchase_order->update_status;
}

=head2 ready_for_qc

Return true of this delivery can be QC'd - i.e. the delivery has been counted

=cut

sub ready_for_qc {
    my ($self) = @_;

    return $_[0]->status_id == $DELIVERY_STATUS__COUNTED;
}

sub is_voucher_delivery {
    my ($self) = @_;

    my $so = $self->stock_order;

    return $so && $so->voucher_product_id;
}

=head2 create_delivery_item( $stock_order_item, $packing_slip ) : delivery_item

Add a delivery item for the given stock order item to this delivery

=cut

sub create_delivery_item {
    my ($self, $stock_order_item, $packing_slip ) = @_;

    return $self->result_source->schema->txn_do(sub{
        my $item = $self->add_to_delivery_items({
            packing_slip => $packing_slip,
            status_id    => $DELIVERY_ITEM_STATUS__NEW,
            type_id      => $DELIVERY_ITEM_TYPE__STOCK_ORDER,
        });

        $item->create_related('link_delivery_item__stock_order_items',
            { stock_order_item_id => $stock_order_item->id }
        );
        return $item;
    });
}

# vim: sw=4 ts=4:
1;
