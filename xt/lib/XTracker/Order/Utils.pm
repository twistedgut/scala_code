package XTracker::Order::Utils;

use NAP::policy     qw( class );

use XTracker::Logfile qw(xt_logger);
use XTracker::Database              qw( xtracker_schema );
use XTracker::Database::Shipment;
use XTracker::Database::Order;
use XTracker::Constants::FromDB qw(
    :department
    :shipment_class
);
use XTracker::Database::OrderPayment qw( get_order_payment
                                         check_order_payment_fulfilled );

=head1 NAME

XTracker::Order::Utils

=head1 DESCRIPTION

Utility methods for order processing

=cut

=head1 ATTRIBUTES

=head2 dbh

=cut

has dbh => (
    is       => 'ro',
    isa      => 'DBI::db',
    required => 0,
    lazy_build => 1,
);

=head2 schema

=cut

has schema => (
    is      => 'ro',
    isa     => 'Object',
    required=> 0,
    lazy_build => 1,
);

=head2 logger

=cut

has logger => (
    is      => 'ro',
    default => sub { xt_logger() },
);

# build the DBH
sub _build_dbh {
    my $self = shift;
    return $self->schema->storage->dbh;
}

# build the Schema
sub _build_schema {
    return xtracker_schema();
}


=head1 METHODS

=head2 billing_address_change_allowed

Can the Billing address be changed from the orders current state

=cut

sub billing_address_change_allowed {
    my ($self, $order_id) = @_;
    my $edit_allowed = 1;

    # get payment info for order
    my $order_payment = get_order_payment( $self->dbh, $order_id );

    # Disallow edits to billing address if payment has been taken
    if ( $order_payment
           && check_order_payment_fulfilled($self->dbh, $order_id) ){
        $edit_allowed = 0;
    }
    else {
        my $order = $self->schema->resultset('Public::Orders')->find( $order_id );
        # certain Payment Methods restrict the editing of the Billing Address
        $edit_allowed = $order->payment_method_allows_editing_of_billing_address()
                                if ( $order );
    }

    return $edit_allowed;
}

=head2 shipping_address_change_allowed

Can the Shipping address be changed from the order/shipments current state

=cut

sub shipping_address_change_allowed {
    my ($self, $order_id, $shipment_id, $dept_id) = @_;

    my $edit_allowed = 1;

    # get shipment and payment info for order
    my $shipment = $self->schema->resultset('Public::Shipment')->find( $shipment_id );
    my $order_payment = get_order_payment($self->dbh, $order_id);

    # not allowed to edit Shipping address if air waybill has been assigned
    # already
    if( ( $shipment->outward_airway_bill // '' ) ne "none" ){
        $edit_allowed = 0;
    }

    # Not allowed to edit shipping address on standard shipments once payment
    # is taken if not a Shipping or Distribution Manager
    if( $shipment->shipment_class_id == $SHIPMENT_CLASS__STANDARD
          && ( $order_payment
                 && check_order_payment_fulfilled($self->dbh, $order_id) )
                 && $dept_id != $DEPARTMENT__SHIPPING
                 && $dept_id != $DEPARTMENT__SHIPPING_MANAGER
                 && $dept_id != $DEPARTMENT__DISTRIBUTION_MANAGEMENT
    ){
        $edit_allowed = 0;
    }

    # not allowed to edit shipping address once payment is taken and
    #'allow_editing_of_shipping_address_after_settlement' on order.payment_method is set to FALSE
    #no matter which department you are in.

    if( ( $order_payment
           && check_order_payment_fulfilled($self->dbh, $order_id) )
         && !$shipment->allow_editing_of_shipping_address_post_settlement
    ) {
        $edit_allowed = 0;
    }
    return $edit_allowed;
}


1;
