use utf8;
package XTracker::Schema::Result::Public::PreOrder;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.pre_order");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "pre_order_id_seq",
  },
  "customer_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "pre_order_status_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "reservation_source_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "shipment_address_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "invoice_address_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "shipping_charge_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "packaging_type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "currency_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "operator_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "telephone_day",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "telephone_eve",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "total_value",
  { data_type => "numeric", is_nullable => 1, size => [10, 3] },
  "comment",
  { data_type => "text", is_nullable => 1 },
  "created",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "signature_required",
  { data_type => "boolean", default_value => \"true", is_nullable => 0 },
  "applied_discount_percent",
  {
    data_type => "numeric",
    default_value => "0.00",
    is_nullable => 0,
    size => [5, 2],
  },
  "applied_discount_operator_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "last_updated",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
  "reservation_type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "applied_discount_operator",
  "XTracker::Schema::Result::Public::Operator",
  { id => "applied_discount_operator_id" },
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
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "customer",
  "XTracker::Schema::Result::Public::Customer",
  { id => "customer_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "invoice_address",
  "XTracker::Schema::Result::Public::OrderAddress",
  { id => "invoice_address_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "link_orders__pre_orders",
  "XTracker::Schema::Result::Public::LinkOrdersPreOrder",
  { "foreign.pre_order_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "operator",
  "XTracker::Schema::Result::Public::Operator",
  { id => "operator_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "packaging_type",
  "XTracker::Schema::Result::Public::PackagingType",
  { id => "packaging_type_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->has_many(
  "pre_order_email_logs",
  "XTracker::Schema::Result::Public::PreOrderEmailLog",
  { "foreign.pre_order_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "pre_order_items",
  "XTracker::Schema::Result::Public::PreOrderItem",
  { "foreign.pre_order_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "pre_order_notes",
  "XTracker::Schema::Result::Public::PreOrderNote",
  { "foreign.pre_order_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "pre_order_operator_logs",
  "XTracker::Schema::Result::Public::PreOrderOperatorLog",
  { "foreign.pre_order_id" => "self.id" },
  undef,
);
__PACKAGE__->might_have(
  "pre_order_payment",
  "XTracker::Schema::Result::Public::PreOrderPayment",
  { "foreign.pre_order_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "pre_order_refunds",
  "XTracker::Schema::Result::Public::PreOrderRefund",
  { "foreign.pre_order_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "pre_order_status",
  "XTracker::Schema::Result::Public::PreOrderStatus",
  { id => "pre_order_status_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "pre_order_status_logs",
  "XTracker::Schema::Result::Public::PreOrderStatusLog",
  { "foreign.pre_order_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "reservation_source",
  "XTracker::Schema::Result::Public::ReservationSource",
  { id => "reservation_source_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "reservation_type",
  "XTracker::Schema::Result::Public::ReservationType",
  { id => "reservation_type_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->belongs_to(
  "shipment_address",
  "XTracker::Schema::Result::Public::OrderAddress",
  { id => "shipment_address_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "shipping_charge",
  "XTracker::Schema::Result::Public::ShippingCharge",
  { id => "shipping_charge_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:aW7vddaGr8imHHmU8kcDEg

__PACKAGE__->many_to_many(
    'orders',
    link_orders__pre_orders => 'orders',
);

=head1 NAME

XTracker::Schema::Result::Public::PreOrder

=cut

use Try::Tiny;
use Carp;

use XTracker::Database::PreOrder    qw( :utils );
use XTracker::Constants             qw( :application );
use XTracker::Constants::PreOrder   qw( :pre_order_operator_control );
use XTracker::Constants::FromDB     qw(
                                        :pre_order_item_status
                                        :pre_order_status
                                        :pre_order_refund_status
                                        :pre_order_note_type
                                        :reservation_status
                                    );
use XTracker::Utilities             qw( number_in_list format_currency_2dp );
use XTracker::Vertex                qw( :pre_order );

use Moose;
with 'XTracker::Schema::Role::Hierarchy',
     'XTracker::Schema::Role::WithStatus' => {
    column => 'pre_order_status_id',
    statuses => {
        cancelled        => $PRE_ORDER_STATUS__CANCELLED,
        complete         => $PRE_ORDER_STATUS__COMPLETE,
        exported         => $PRE_ORDER_STATUS__EXPORTED,
        incomplete       => $PRE_ORDER_STATUS__INCOMPLETE,
        part_exported    => $PRE_ORDER_STATUS__PART_EXPORTED,
        payment_declined => $PRE_ORDER_STATUS__PAYMENT_DECLINED
    }
};

use XTracker::Config::Local qw{ config_section_slurp config_var };
use XTracker::Logfile       qw( xt_logger );

my $logger = xt_logger(__PACKAGE__);

=head2 can_confirm_all_items

Returns true or false if all the pre order items can be confirmed for payment

=cut

sub can_confirm_all_items {
    return shift->pre_order_items->are_all_confirmable;
}

=head2 confirm_all_items

Will change the status code of all items to 'Confirm'

=cut

sub confirm_all_items {
    my ($self, $operator_id) = @_;

    return $self->pre_order_items
                ->update_status( $PRE_ORDER_ITEM_STATUS__CONFIRMED,
                                 $operator_id );
}

=head2 select_all_items

Will change the status code of all items to 'Selected'

=cut

sub select_all_items {
    my ($self, $operator_id) = @_;

    return $self->pre_order_items
                ->update_status( $PRE_ORDER_ITEM_STATUS__SELECTED,
                                 $operator_id );
}

=head2 complete_all_items

Will change the status code of all items to 'Complete'

=cut

sub complete_all_items {
    my ($self, $operator_id) = @_;

    return $self->pre_order_items
                ->update_status( $PRE_ORDER_ITEM_STATUS__COMPLETE,
                                 $operator_id );
}

=head2 is_notifiable

Returns true if the pre-order is in a notifiable status, and there
exist no unnotifiable pre-order items.

=cut

sub is_notifiable {
    my $self = shift;


    my $log_check = $self->pre_order_status_logs->search({ pre_order_status_id => {'IN' =>[
                                                                 $PRE_ORDER_STATUS__COMPLETE,
                                                                 $PRE_ORDER_STATUS__PART_EXPORTED,
                                                                 $PRE_ORDER_STATUS__EXPORTED
                                                                ]}
                                                   });
    return 0 unless $log_check->count > 0;
    # note reversed sense of test -------------------------+---+
    #                                                      |   |
    #                                                      v   v
    return $self->pre_order_items->not_notifiable->count ? 0 : 1 ;
}

sub notify_web_app {
    my ( $self, $amq ) = @_;

    return unless $self->is_notifiable;

    # the producer knows whether or not to actually send the message
    return $amq->transform_and_send( 'XT::DC::Messaging::Producer::PreOrder::Update', { preorder => $self } );
}

=head2 update_status

    $self->update_status( $status_id, $operator_id );

Will update the Status of the Pre Order and Log the change in 'pre_order_status_log'.

Will default to 'Application' operator id NO $operator_id is passed.

=cut

sub update_status {
    my ( $self, $status_id, $operator_id )  = @_;

    # default to the Application Operator
    $operator_id    //= $APPLICATION_OPERATOR_ID;

    # update the Status
    $self->update( { pre_order_status_id => $status_id } );

    # now Log it
    $self->create_related( 'pre_order_status_logs', {
                                        pre_order_status_id     => $status_id,
                                        operator_id             => $operator_id,
                                } );

    return;
}

=head2 get_payment

Get the payment DBIx object for this Pre Order

=cut

sub get_payment { return shift->pre_order_payment; }

=head2 cancel

    $pre_order_refund_obj   = $self->cancel( {
                    stock_manager   => $stock_management_object,        # XTracker::WebContent::StockManagement object
                                                                        # required to Cancel Reservations for Items
                    operator_id     => $operator_id,                    # optional will default to App. User
                    # then one or the other of the following
                    items_to_cancel => [
                                        # Array Ref of Pre-Order Item Id's to be Cancelled,
                                    ],
                    cancel_pre_order=> 1,       # This will indicate that all remaining Pre-Order Items
                                                # that haven't been Cancelled and can be, should be
                } );

This will Cancel a Pre-Order as a Whole or only specific Pre-Order Items specified.

If a Refund is generated then a 'Pre-Order Refund' object will be returned.

=cut

sub cancel {
    my ( $self, $args )     = @_;

    # don't cancel more than once
    return      if ( $self->is_cancelled );

    croak "Missing Args HASH Ref for 'cancel' method in '" . __PACKAGE__ . "'"      if ( !$args || ref( $args ) ne 'HASH' );

    # now make sure $args has what is needed
    croak "No 'Stock Management' object passed in Args to 'cancel' method in '" . __PACKAGE__ . "'"
                                        if ( !$args->{stock_manager} || ref( $args->{stock_manager} ) !~ /WebContent::StockManagement/ );
    if ( ( !$args->{items_to_cancel} || ref( $args->{items_to_cancel} ) ne 'ARRAY' )
         && ( !$args->{cancel_pre_order} ) ) {
        croak "Neither 'items_to_cancel' Array Ref or 'cancel_pre_order' passed in Args to 'cancel' method in '" . __PACKAGE__ . "'";
    }

    my $stock_manager   = $args->{stock_manager};
    my $operator_id     = $args->{operator_id} // $APPLICATION_OPERATOR_ID;

    # get a Result-Set of Items to Cancel
    my $rs;
    if ( $args->{cancel_pre_order} ) {
        $rs = $self->pre_order_items->available_to_cancel;
    }
    else {
        # only get Items Available to Cancel
        # that are in the List of Ids
        $rs = $self->pre_order_items
                ->available_to_cancel
                    ->search(
                        {
                            id  => { 'IN' => [ @{ $args->{items_to_cancel} } ] },
                        }
                    );
    }

    my @items_to_refund;

    my @items   = $rs->order_by_id->all;

    foreach my $item ( @items ) {
        if ( $item->is_complete ) {
            # we can refund these
            push @items_to_refund, $item;
        }

        $item->cancel( $stock_manager, $operator_id );
    }

    # if ALL Pre-Order Items are Cancelled then
    # the Pre-Order It'self should be Cancelled
    if ( $self->pre_order_items->are_all_cancelled ) {
        $self->update_status( $PRE_ORDER_STATUS__CANCELLED, $operator_id );
    }

    if ( @items_to_refund ) {
        # create a refund for all of these items
        my $refund  = $self->create_related( 'pre_order_refunds', {
                                                        pre_order_refund_status_id  => $PRE_ORDER_REFUND_STATUS__PENDING,
                                                } );
        foreach my $item ( @items_to_refund ) {
            $refund->create_related( 'pre_order_refund_items', {
                                                        pre_order_item_id   => $item->id,
                                                        unit_price          => $item->unit_price,
                                                        tax                 => $item->tax,
                                                        duty                => $item->duty,
                                                } );
        }

        $refund->update_status( $PRE_ORDER_REFUND_STATUS__PENDING, $operator_id );

        return $refund;
    }

    return;
}

=head2 all_items_are_cancelled

    $boolean    = $self->all_items_are_cancelled;

This will return TRUE or FALSE based on whether all Pre-Order Items have been Cancelled.

=cut

sub all_items_are_cancelled { return shift->pre_order_items->are_all_cancelled; }

=head2 total_uncancelled_value

    my $decimal = $self->total_uncancelled_value;

This will return the actual Value of the Pre-Order less any Cancelled Items.

=cut

sub total_uncancelled_value {
    return shift->pre_order_items->not_cancelled->total_value;
}

=head2 total_uncancelled_value_formatted

    $str = $self->total_uncancelled_value_formatted;

Returns the same as 'total_uncancelled_value' but formatted for
the page using the 'format_currency_2dp' function.

    Example:
        1250 -> 1,250.00

=cut

sub total_uncancelled_value_formatted {
    my $self = shift;
    return format_currency_2dp( $self->total_uncancelled_value );
}

sub pre_order_number {
    return get_pre_order_number_from_id( shift->id );
}

sub channel { return shift->customer->channel; }

sub has_shipment_address_change {
    return ( shift->pre_order_notes
                  ->shipment_address_change
                  ->first )
           ? 1 : 0 ;
}

# handy object-orientation delegating thingummybobs
sub use_vertex {
    return use_vertex_for_pre_order( @_ );
}

sub update_from_vertex_quotation {
    return update_pre_order_from_vertex_quotation( @_ );
}

sub create_vertex_quotation_request {
    return create_vertex_quotation_request_from_pre_order( @_ );
}

sub create_vertex_quotation {
    return create_vertex_quotation_from_pre_order( @_ );
}

=head2 is_signature_required

    $boolean    = $pre_order->is_signature_required;

This returns either TRUE or FALSE depending on the state of the field 'signature_required'.

=cut

sub is_signature_required {
    my $self    = shift;

    return ($self->signature_required
            ? 1     # TRUE  - Signature IS Required
            : 0     # FALSE - Signature is NOT Required
        );
}

=head2 exportable_items

Will return a Result Set of PreOrderItems for this preorder that are in an
exportable state

=cut

sub exportable_items {
    my $self = shift;

    my $rs = $self->pre_order_items->search(
        {
          pre_order_item_status_id => $PRE_ORDER_ITEM_STATUS__COMPLETE,
          'reservation.status_id'  => $RESERVATION_STATUS__UPLOADED,
        },
        { join => 'reservation' },
    );

    return $rs;
}

=head2 all_items_are_exported

Will return positively if all non-Cancelled PreOrderItems in the PreOrder
have a status of 'Exported'.

=cut

sub all_items_are_exported {
    my $self = shift;
    return $self->pre_order_items
                    ->not_cancelled
                    ->all_are_exported;
}

=head2 some_items_are_exported

Will return positively if at least one PreOrderItem in the PreOrder has a
status of 'Exported'

=cut

sub some_items_are_exported {
    return shift->pre_order_items->some_are_exported;
}

=head2 contains_item

Will return the PreOrderItem row object for a specific PreOrderItem if that
PreOrderItem is present in the PreOrder

=cut

sub contains_item {
    my $self = shift;
    my $item = shift;
    return $self->pre_order_items->find($item->id);
}


=head2 transfer_to_operator

Return TRUE if the pre order was successfully transferred between operators

=cut

sub transfer_to_operator {
    my ($self, $to_operator, $by_operator) = @_;

    # Fail if the operator is not a dbix object
    unless ($to_operator->isa('XTracker::Schema::Result::Public::Operator')) {
        $logger->warn('to_operator is not a DBIx object: '.$to_operator);
        return 0;
    }

    # Fail if the operator is not a dbix object
    unless ($by_operator->isa('XTracker::Schema::Result::Public::Operator')) {
        $logger->warn('by_operator is not a DBIx object: '.$to_operator);
        return 0;
    }

    # Can not transfer to the same operator
    return 0 if ($self->operator->id == $to_operator->id);

    # Can not transfer to someone outside these departments
    return 0 unless grep {$to_operator->department->id == $_} @{$PRE_ORDER_OPERATOR_CONTROL__OPERATOR_TRANSFER_DEPARTMENTS};

    my $schema = $self->result_source->schema;

    # Transfer pre order between operators inside a transaction
    return $schema->txn_do(
        sub {
            return try {
                # Only a manager or the owner of the pre order can transfer
                if ($by_operator->is_manager($PRE_ORDER_OPERATOR_CONTROL__OPERATOR_TRANSFER_SECTION, $PRE_ORDER_OPERATOR_CONTROL__OPERATOR_TRANSFER_SUBSECTION) || ($by_operator->id == $self->operator->id)) {

                    # Create a log entry
                    $self->create_related('pre_order_operator_logs', {
                        pre_order_status_id => $self->pre_order_status_id,
                        operator_id         => $by_operator->id,
                        from_operator_id    => $self->operator_id,
                        to_operator_id      => $to_operator->id,
                    });

                    # Update each reservation associated with each pre order item
                    foreach my $item ($self->pre_order_items) {
                        $item->reservation->update_operator($self->operator->id, $to_operator->id);
                    }

                    # Update pre order
                    $self->update({
                        operator_id => $to_operator->id,
                    });

                    # Transfer was successful so return true
                    return 1;
                }
                # Not allowed to transfer so return false
                else {
                    return 0;
                }
            }
            catch {
                $logger->warn($_);
                $logger->warn('unable to transfer preorder from #'.$self->operator_id.' to #'.$to_operator.' by #'.$by_operator);

                $schema->txn_rollback();

                # Something bad happened so return false
                return 0;
            };
        }
    );
}

=head2 get_item_shipping_attributes

    $hash_ref   = $self->get_item_shipping_attributes();

This will return a HashRef of 'Shipping Attributes' for all NON-Cancelled Pre-Order Items
for the Pre-Order with the 'Product Id' as the key.

    {
        1232414 => {
            scientific_term     => 'term',
            country_id          => 34,
            cites_restricted    => true,
            is_hazmat           => false,
            ...
        },
        ...
    }

=cut

sub get_item_shipping_attributes {
    my $self    = shift;

    my %retval;

    my @attribs = $self->pre_order_items
                        ->not_cancelled
                            ->related_resultset('variant')
                                ->related_resultset('product')
                                    ->related_resultset('shipping_attribute')
                                        ->all;

    foreach my $attrib ( @attribs ) {
        $retval{ $attrib->product_id }  = {
            $attrib->get_columns,       # turns the record into a HASH
        };
    }

    return \%retval;
}

=head2 get_total_without_discount

    $decimal = $self->get_total_without_discount;

Returns the Total Value without the Discount being Applied.

This adds up the 'original_' columns on the 'pre_order_item'
table.

WARNING: Be careful of rounding errors if using this value
         in any calculations, better to use the source data.

=cut

sub get_total_without_discount {
    my $self = shift;
    return $self->pre_order_items->not_cancelled->total_original_value;
}

=head2 get_total_without_discount_formatted

    $str = $self->get_total_without_discount_formatted;

Returns the same as 'get_total_without_discount' but after it has been formatted
for the page using the 'format_currency_2dp' function.

    Example:
        1250 -> 1,250.00

=cut

sub get_total_without_discount_formatted {
    my $self = shift;
    return format_currency_2dp( $self->get_total_without_discount );
}

=head2 has_discount

    $boolean = $self->has_discount;

Conveinience method to return TRUE or FALSE depending on whether the Pre-Order
has a Discount or not.

=cut

sub has_discount {
    my $self = shift;
    return (
        $self->applied_discount_percent > 0
        ? 1
        : 0
    );
}

1;
