use utf8;
package XTracker::Schema::Result::Public::PreOrderItem;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.pre_order_item");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "pre_order_item_id_seq",
  },
  "pre_order_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "variant_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "reservation_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "pre_order_item_status_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "tax",
  { data_type => "numeric", is_nullable => 0, size => [10, 3] },
  "duty",
  { data_type => "numeric", is_nullable => 0, size => [10, 3] },
  "unit_price",
  { data_type => "numeric", is_nullable => 0, size => [10, 3] },
  "created",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "original_unit_price",
  { data_type => "numeric", is_nullable => 0, size => [10, 3] },
  "original_tax",
  { data_type => "numeric", is_nullable => 0, size => [10, 3] },
  "original_duty",
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
  "pre_order",
  "XTracker::Schema::Result::Public::PreOrder",
  { id => "pre_order_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "pre_order_item_status",
  "XTracker::Schema::Result::Public::PreOrderItemStatus",
  { id => "pre_order_item_status_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "pre_order_item_status_logs",
  "XTracker::Schema::Result::Public::PreOrderItemStatusLog",
  { "foreign.pre_order_item_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "pre_order_refund_items",
  "XTracker::Schema::Result::Public::PreOrderRefundItem",
  { "foreign.pre_order_item_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "reservation",
  "XTracker::Schema::Result::Public::Reservation",
  { id => "reservation_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "variant",
  "XTracker::Schema::Result::Public::Variant",
  { id => "variant_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:4hbqVVpNsCvA8KjKrBCfHw


use Carp;

use XTracker::Database::PreOrder    qw( :utils );
use XTracker::Constants                 qw( :application );
use XTracker::Constants::FromDB         qw( :pre_order_item_status
                                            :reservation_status
                                          );

use XTracker::Database::Reservation     qw( cancel_reservation update_reservation_variant );

# defines a relationship to the 'pre_order_item_status_log'
# table but when only the Status is 'Complete'
__PACKAGE__->has_many(
  "unique_complete_pre_order_item_status_logs",
  "XTracker::Schema::Result::Public::PreOrderItemStatusLog",
  sub {
    my $args    = shift;
    return {
        "$args->{foreign_alias}.pre_order_item_id" => { -ident => "$args->{self_alias}.id" },
        # the following ensures that if there are multiple 'Complete' Status Logs
        # then only the first one is returned to avoid duplicate rows being returned
        "$args->{foreign_alias}.id" => {
                                        '=' => \"(
                                            SELECT  MIN(poisl.id) AS poisl_id
                                            FROM    pre_order_item_status_log poisl
                                            WHERE   poisl.pre_order_item_id = $args->{self_alias}.id
                                            AND     poisl.pre_order_item_status_id = $PRE_ORDER_ITEM_STATUS__COMPLETE
                                        )",
                                    },
    };
  },
  {},
);


use Moose;
with 'XTracker::Schema::Role::WithStatus' => {
    column => 'pre_order_item_status_id',
    statuses => {
        cancelled        => $PRE_ORDER_ITEM_STATUS__CANCELLED,
        complete         => $PRE_ORDER_ITEM_STATUS__COMPLETE,
        confirmed        => $PRE_ORDER_ITEM_STATUS__CONFIRMED,
        exported         => $PRE_ORDER_ITEM_STATUS__EXPORTED,
        payment_declined => $PRE_ORDER_ITEM_STATUS__PAYMENT_DECLINED,
        selected         => $PRE_ORDER_ITEM_STATUS__SELECTED
    }
};

sub can_be_cancelled {
    my $self    = shift;

    # note reversed sense of test -------------------------+---+
    #                                                      |   |
    #                                                      v   v
    return ( $self->is_exported || $self->is_cancelled ) ? 0 : 1 ;
}

=head2 update_status

    $self->update_status( $status_id, $operator_id );

Will update the Status of the Pre Order Item and Log the change in 'pre_order_item_status_log'.

Will default to 'Application' operator id NO $operator_id is passed.

=cut

sub update_status {
    my ( $self, $status_id, $operator_id )  = @_;

    # default to the Application Operator
    $operator_id    //= $APPLICATION_OPERATOR_ID;

    # update the Status
    $self->update( { pre_order_item_status_id => $status_id } );

    # now Log it
    $self->create_related( 'pre_order_item_status_logs', {
                                        pre_order_item_status_id=> $status_id,
                                        operator_id             => $operator_id,
                                } );

    return;
}

=head2 cancel

    $self->cancel(
                    $stock_management_object,       # XTracker::WebContent::StockManagement object
                    $operator_id,                   # optional will default to App. user
                );

This will Cancel the Pre-Order Item and if there are any cancel the Reservation for the Item also.

It will need to be passed a Stock Management Object if it is to cancel a Reservation - this constraint
will only be looked at if there is a Reservation to be Cancelled. Also an optional Operator Id can be
passed but if absent will be default to the App. User.

=cut

sub cancel {
    my ( $self, $stock_manager, $operator_id )  = @_;

    # don't bother cancelling twice
    return      if $self->is_cancelled ;

    # default to the Application Operator
    $operator_id    //= $APPLICATION_OPERATOR_ID;

    my $reservation;
    if ( $reservation = $self->reservation ) {
        # if a reservation is found then check for Stock Manager argument
        croak "No 'Stock Management' object passed to 'cancel' method in '" . __PACKAGE__ . "'"
                        if ( !$stock_manager || ref( $stock_manager ) !~ /WebContent::StockManagement/ );
    }

    # now update the Status of the Item to be 'Cancelled', will also log it
    $self->update_status( $PRE_ORDER_ITEM_STATUS__CANCELLED, $operator_id );

    if ( $reservation ) {
        # if there is a Reservation, Cancel it too
        my $dbh = $self->result_source->schema->storage->dbh;
        cancel_reservation( $dbh, $stock_manager, {
                                        reservation_id      => $reservation->id,
                                        variant_id          => $reservation->variant_id,
                                        status_id           => $reservation->status_id,
                                        operator_id         => $operator_id,
                                        customer_nr         => $reservation
                                                                    ->customer
                                                                        ->is_customer_number,
                                } );
    }

    return;
}

=head2 is_confirmable

Returns true if-and-only-if this pre order item can be confirmed for payment.

=cut

sub is_confirmable {
    my $self = shift;

    if ( $self->is_selected ) {
        return $self->variant->discard_changes
                        ->can_be_pre_ordered_in_channel($self->pre_order->channel->id);
    }
    else {
        return $self->is_payment_declined || $self->is_confirmed;
    }
}

=head2 update_reservation_id

Set the reservation id for this pre order item

=cut

sub update_reservation_id {
    my ($self, $id) = @_;

    $self->update({ reservation_id => $id });
}

sub channel { return shift->pre_order->channel; }

=head2 is_exportable

Will return positively if this PreOrderItem is available to be exported to the
web site. This is a combination of the PreOrderItem status and the associated
Reservation status

=cut

sub is_exportable {
    my $self = shift;

    my $exportable = 0;

    if( $self->is_complete
          && $self->reservation->status_id == $RESERVATION_STATUS__UPLOADED ){
        $exportable = 1;
    }

    return $exportable;
}

=head2 name

Return a human-readable product name for this pre-order item.

=cut

sub name {
    return shift->variant->product->preorder_name;
}

=head2 product_details_for_email

    $hash_ref = $self->product_details_for_email;

Will return the following Hash Ref. containing details of the Product
mostly in regards to the Product Name. These details are primarily used
for being passed to the Product Service when an Email is being processed.
Assign this Hash Ref. to 'product_items' in the Email Data and the PS
should then traslate each Product.

    {
        product_id      => 2345,
        name            => $pre_order_item->name,
        designer_name   => $designer_name,          # or empty string if not available,
        original_name   => $pre_order_item->name,
        name_for_tt     => CODE,                    # this is a sub to decide which name
                                                    # to return when in the TT document
                                                    # see explanation about 'original_name'
    },

The use of 'original_name' in a TT Email document:

    '$pre_order_item->name' returns 'Designer - Name' or '$product->product_attribute->description'
    depending on the data available at the time (as Pre-Order Products are used a lot earlier than
    usual and not all the data may be available), but when 'product_items' gets translated by the PS
    then it will only contain 'Name', so 'original_name' should be used in the TT to check if its
    still the same as 'name', if it is then no translation happened and will use 'name' but if
    its different then will use 'designer_name' - 'name' in the TT Email.

=cut

sub product_details_for_email {
    my $self    = shift;

    my $product = $self->variant->product;

    my $detail  = {
        product_id      => $product->id,
        name            => $self->name,
        designer_name   => eval{ $product->designer->designer } // '',
        original_name   => $self->name,
    };

    # sub to get the name of the Product depending on what
    # has happened with translation and what else is available
    $detail->{name_for_tt}  = sub {
        # no translation has happened
        return $detail->{name}
            if ( ( $detail->{name} // '' ) eq $detail->{original_name} );

        # use the Designer Name & the Translated Product Name
        return $detail->{designer_name} . ' - ' . $detail->{name}
            if ( $detail->{designer_name} && $detail->{name} );

        # if no Designer Name, then use the Product Name or if that's empty the Original Name
        return ( $detail->{name} ? $detail->{name} : $detail->{original_name} );
    };

    return $detail;
}

=head2 change_size_to

    $pre_order_item_obj = $self->change_size_to( $new_variant, $stock_manager, $operator_id, $optional_error_result_hashref );

This will change the Size of the Pre-Order Item by Cancelling the existing one and
creating a new one, it will also change the size of the associated Reservation.

Only 'Complete' Pre-Order Items can be changed and if there isn't Stock left to Pre-Order
for the New Size then it won't be changed and return FALSE;

Returns the New Pre-Order Item Object or 'undef' based on whether it actually changed the Size.

You will need to pass in an 'XTracker::WebContent::StockManagement' object to handle processing the Reservations and
and Operator Id.

If you pass a Hash Ref as a secondary parameter then (if upon failure) it will be populated
with an Error Message detailing why.

=cut

sub change_size_to {
    my ( $self, $new_variant, $stock_manager, $operator_id, $err_result )   = @_;

    if ( !$new_variant || ref( $new_variant ) !~ m/::Public::Variant$/ ) {
        croak "No Variant Object passed in to '" . __PACKAGE__ . "->change_size_to'";
    }
    if ( !$stock_manager || ref( $stock_manager ) !~ /WebContent::StockManagement/ ) {
        croak "No Stock Management object passed in to '" . __PACKAGE__ . "->change_size_to'";
    }
    if ( !$operator_id ) {
        croak "No Operator Id object passed in to '" . __PACKAGE__ . "->change_size_to'";
    }

    $err_result //= {};
    my $retval;

    if ( !$self->is_complete ) {
        $err_result->{message}  = "Pre-Order Item is NOT at the Correct Status, currently: " . $self->pre_order_item_status->status;
        return $retval;
    }

    if ( $self->variant->product_id != $new_variant->product_id ) {
        $err_result->{message}  = "New Variant is NOT for the Same PID as the Old: " . $self->variant->product_id . " != " . $new_variant->product_id;
        return $retval;
    }

    if ( $self->variant->size_id == $new_variant->size_id ) {
        $err_result->{message}  = "New Size is the Same as the Old";
        return $retval;
    }

    my $channel = $self->channel;

    # get the Variants for the Product
    # and check there are some available
    my $product = $new_variant->product;
    my $variants= $product->get_variants_for_pre_order( $channel );
    if ( !$variants ) {
        $err_result->{message}  = "Couldn't Find any Variants for Product: " . $product->id;
        return $retval;
    }

    if (
        grep { $_->{variant}->id == $new_variant->id }              # only want the Variant that matches $new_variant
                grep { $_->{variant} && $_->{is_available} }        # only want those Variants that are Available
                    @{ $variants }
        ) {

        # Can Change the Size
        my $pre_order   = $self->pre_order;
        my $new_item    = $pre_order->create_related( 'pre_order_items', {
                                    variant_id              => $new_variant->id,
                                    pre_order_item_status_id=> $PRE_ORDER_ITEM_STATUS__COMPLETE,
                                    tax                     => $self->tax,
                                    duty                    => $self->duty,
                                    unit_price              => $self->unit_price,
                                    original_tax            => $self->original_tax,
                                    original_duty           => $self->original_duty,
                                    original_unit_price     => $self->original_unit_price,
                            } );
        # log the Status
        $new_item->update_status( $PRE_ORDER_ITEM_STATUS__COMPLETE, $operator_id );

        # change the Size of the Reservation
        my $dbh = $self->result_source->schema->storage->dbh;
        update_reservation_variant(
                                    $dbh,
                                    $stock_manager,
                                    $self->reservation_id,
                                    $new_variant->id,
                                    {
                                        link_to_pre_order_item => $new_item,
                                    },
                                );

        # ZERO the Ordering Id for the New Reservation
        $new_item->discard_changes
                    ->reservation
                        ->update( { ordering_id => 0 } );

        # and cancel the current Pre-Order Item
        $self->update_status( $PRE_ORDER_ITEM_STATUS__CANCELLED, $operator_id );

        $retval = $new_item;    # SUCCESS!
    }
    else {
        $err_result->{message}  = "SOLD OUT of the New Size";
    }

    return $retval;
}

=head2 link_to_shipment_item

Fetch the related shipment item link for this pre-order item, if it exists.

=cut

sub link_to_shipment_item {
    my $reservation = shift->reservation;

    return unless $reservation;

    return $reservation->link_shipment_item__reservations->first;
}

=head2 has_link_to_shipment_item

Return true iff a shipment item exists for this pre-order item.

=cut

sub has_link_to_shipment_item {
    return shift->link_to_shipment_item ? 1 : 0 ;
}

=head2 is_awaiting_order

Returns true iff the item has been exported, but no associated
shipment item has yet been created.

=cut

sub is_awaiting_order {
    my $self = shift;

    return 0 unless $self->is_exported;

    # note reversed sense of test ------------+---+
    #                                         |   |
    #                                         v   v
    return $self->has_link_to_shipment_item ? 0 : 1 ;
}

=head2 export_date

Returns the most recent export date for this item from its status logs.

=cut

sub export_date {
    my $self = shift;

    my $log = $self->pre_order_item_status_logs
                   ->exported
                   ->order_by_date_desc
                   ->first;

    return unless $log;

    return $log->date;
}

=head2 order

    $order_obj  = $self->order;

Returns the DBIC Public::Orders object if it is linked to one via its Reservation.

=cut

sub order {
    my $link_to_si  = shift->link_to_shipment_item;

    return      if ( !$link_to_si );

    my $order   = $link_to_si->shipment_item
                                ->shipment
                                    ->order;

    return $order;
}

sub pre_order_number {
    return get_pre_order_number_from_id( shift->pre_order_id );
}

sub customer { return shift->pre_order->customer; }

1;
