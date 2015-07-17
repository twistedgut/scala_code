package XTracker::Schema::ResultSet::Public::PreOrderNote;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

use XTracker::Constants::FromDB qw( :pre_order_note_type );

use Moose;
with 'XTracker::Schema::Role::ResultSet::Orderable' => {
         order_by => {      id => 'id',
                          date => 'date',
                     },
     },

     'XTracker::Schema::Role::ResultSet::WithStatus' => {
         column => 'note_type_id',
         statuses => {
             shipment_address_change
                  => $PRE_ORDER_NOTE_TYPE__SHIPMENT_ADDRESS_CHANGE,

             online_fraud_finance
                  => $PRE_ORDER_NOTE_TYPE__ONLINE_FRAUD_FSLASH_FINANCE,

             pre_order_item
                  => $PRE_ORDER_NOTE_TYPE__PRE_DASH_ORDER_ITEM,

             misc => $PRE_ORDER_NOTE_TYPE__MISC
         }
     };


sub for_operator_id {
    my ( $resultset, $operator_id ) = @_;

    return $resultset->search( { operator_id => $operator_id } );
}

1;
