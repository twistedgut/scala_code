package XTracker::Schema::ResultSet::Public::PreOrderItemStatusLog;
# vim: ts=4 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

use XTracker::Constants::FromDB         qw( :pre_order_item_status );

use Moose;
with 'XTracker::Schema::Role::ResultSet::Orderable' => {
         order_by => {           id => 'id',
                               date => 'date',
                       date_item_id => [ qw( date pre_order_item_id id ) ]
                     }
     },
     'XTracker::Schema::Role::ResultSet::WithStatus' => {
         column => 'pre_order_item_status_id',
         statuses => {
                     selected => $PRE_ORDER_ITEM_STATUS__SELECTED,
                    confirmed => $PRE_ORDER_ITEM_STATUS__CONFIRMED,
                     complete => $PRE_ORDER_ITEM_STATUS__COMPLETE,
                    cancelled => $PRE_ORDER_ITEM_STATUS__CANCELLED,
                     exported => $PRE_ORDER_ITEM_STATUS__EXPORTED,
             payment_declined => $PRE_ORDER_ITEM_STATUS__PAYMENT_DECLINED,
         }
     };

1;
