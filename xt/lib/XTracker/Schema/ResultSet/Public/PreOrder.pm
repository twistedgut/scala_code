package XTracker::Schema::ResultSet::Public::PreOrder;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

=head1 NAME

XTracker::Schema::ResultSet::Public::PreOrder

=cut

use XTracker::Constants::FromDB qw( :pre_order_status
                                    :reservation_status
                                    :pre_order_item_status
                                    :shipment_status
                                    :shipment_hold_reason
                                    :shipment_class
                                  );
use XTracker::Constants qw(
    $APPLICATION_OPERATOR_ID
);
use XTracker::Config::Local qw( config_var );

use Moose;
with 'XTracker::Schema::Role::ResultSet::Orderable' => {
        order_by => {      id => 'id',
                      created => 'created'
                    }
     },

     'XTracker::Schema::Role::ResultSet::WithStatus' => {
       column => 'pre_order_status_id',
       statuses => {
           complete         => $PRE_ORDER_STATUS__COMPLETE,
           incomplete       => $PRE_ORDER_STATUS__INCOMPLETE,
           exported         => $PRE_ORDER_STATUS__EXPORTED,
           cancelled        => $PRE_ORDER_STATUS__CANCELLED,
           part_exported    => $PRE_ORDER_STATUS__PART_EXPORTED,
           payment_declined => $PRE_ORDER_STATUS__PAYMENT_DECLINED,
       }
};

sub for_customer_id {
    my ( $resultset, $customer_id ) = @_;

    return $resultset->search( { customer_id => $customer_id } );
}

sub for_currency_id {
    my ( $resultset, $currency_id ) = @_;

    return $resultset->search( { currency_id => $currency_id } );
}

=head2 with_items_to_export

    Adds the condition limiting the preorder resultset to only those with
    preorder items to export

=cut

sub with_items_to_export {
    shift->search(
        { 'pre_order_items.pre_order_item_status_id' => $PRE_ORDER_ITEM_STATUS__COMPLETE,
          'reservation.status_id'                    => $RESERVATION_STATUS__UPLOADED,
        },
        { join => { 'pre_order_items' => 'reservation'},
          distinct => 1
        },
    );
}

=head2 get_pre_order_list

   For given operator_id and interval (defaults to 6 months) returns resultset
   containing preorders for that operator for given time frame.

=cut

sub get_pre_order_list {
    my $self = shift;
    my $args = shift;


    my $default_interval = config_var( 'PreOrder', 'default_summary_interval');
    my $age = defined $args->{age}
        ? $args->{age}
        : $default_interval;
    my $operator_id = $args->{operator_id} || $APPLICATION_OPERATOR_ID;

    my $rs = $self->search( {
        'me.created' => { '>=' => \"(now() - interval \' $age\')"},
       'me.operator_id' => $operator_id,
    },{
        order_by => [  'me.id DESC', 'me.customer_id'],
        prefetch => [ { 'customer' =>  'channel' } , 'operator'  ],
    });

    return $rs;
}

=head2 get_exported_pre_orders_on_hold

Returns all Exported or Part Exported Pre-Orders that are on the following
shipment holds:

* Hold
* Finance Hold
* DDU Hold

    my $exported_pre_orders_on_hold = $schema
        ->resultset('Public::PreOrder')
        ->get_exported_pre_orders_on_hold;

=cut

sub get_exported_pre_orders_on_hold {
    my $self = shift;

    return $self->search({
        'me.pre_order_status_id'        => { '-in' => [ $PRE_ORDER_STATUS__EXPORTED, $PRE_ORDER_STATUS__PART_EXPORTED ] },
        'shipment.shipment_status_id'   => { '-in' => [ $SHIPMENT_STATUS__HOLD, $SHIPMENT_STATUS__FINANCE_HOLD, $SHIPMENT_STATUS__DDU_HOLD ] },
        'shipment.shipment_class_id'    => $SHIPMENT_CLASS__STANDARD,
    },{
        join => { link_orders__pre_orders => { orders => { link_orders__shipments => 'shipment' } } },
    });

}

1;
