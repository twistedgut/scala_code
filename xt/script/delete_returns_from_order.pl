#!/opt/xt/xt-perl/bin/perl
use strict;
use warnings;
use Getopt::Long;
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Constants::FromDB qw(
    :renumeration_type
    :shipment_item_status
);
require XTracker::Database;

my ($order_nr, $order_id, $order); 
GetOptions( 'nr=i' => \$order_nr, 'id=i' => \$order_id);
die "usage $0 [--nr=34234 | --id=23123]" 
    unless $order_nr || $order_id;

my ($schema) = XTracker::Database::get_schema_and_ro_dbh('xtracker_schema');

$order = $schema->resultset('Public::Orders')->find({order_nr=>$order_nr})
        || $schema->resultset('Public::Orders')->find($order_id);

die "Couldn't find order with id/number: ".($order_id||$order_nr)."\n" 
    unless $order;

$schema->txn_begin;

eval {

    my $refund_renumerations = $order->link_orders__shipments
        ->search_related('shipment')
        ->search_related('renumerations',
            { renumeration_type_id => {
                -in => 
                [ $RENUMERATION_TYPE__CARD_REFUND, 
                $RENUMERATION_TYPE__STORE_CREDIT ]
            }
        });

        $refund_renumerations->related_resultset('renumeration_tenders')->delete;

    for my $ship ($order->shipments) {

        for my $return ($ship->returns) {
            $return->return_items
                ->related_resultset('link_delivery_item__return_items')->delete;

            $return->return_items->related_resultset('return_item_status_logs')
                ->delete;
            $return->return_items->delete;
            $return->return_items->related_resultset('return_item_status_logs')
                ->delete;
            $return->link_return_renumerations->delete;
            $return->link_delivery__returns->delete;
            $return->link_routing_export__returns->delete;
            $return->return_status_logs->delete;
            $return->return_notes->delete;

            $return->delete;
        }
    }

    $refund_renumerations->related_resultset('renumeration_status_logs')
        ->delete;
    $refund_renumerations->related_resultset('renumeration_change_logs')
        ->delete;
    $refund_renumerations->related_resultset('renumeration_items')->delete;
    $refund_renumerations->delete;

    $order->link_orders__shipments->search_related('shipment')
        ->related_resultset('shipment_items')->update(
            { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__DISPATCHED }
    );
};

die "bollocks: $@\n" if $@;

$schema->txn_commit; 
print "Deleted all returns for order : ".($order_id || $order_nr)."\n";
