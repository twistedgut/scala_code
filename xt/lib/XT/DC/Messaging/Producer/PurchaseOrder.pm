package XT::DC::Messaging::Producer::PurchaseOrder;
use NAP::policy "tt", 'class';
use Scalar::Util qw/blessed/;
use Carp;

use XTracker::Constants::FromDB qw( :purchase_order_status );

with 'XT::DC::Messaging::Role::Producer';

has '+type' => ( default => 'update_status' );

use vars qw<
    $PURCHASE_ORDER_STATUS__PART_DELIVERED
    $PURCHASE_ORDER_STATUS__DELIVERED
>;

# Take a XT::Central::Schema::Public::PurchaseOrder
sub transform {
    my ($self, $header, $po ) = @_;

    confess __PACKAGE__ . "::transform needs a Public::SuperPurchaseOrder row"
        unless (blessed($po) && $po->isa('XTracker::Schema::Result::Public::SuperPurchaseOrder'));

    confess qq{Purchase order (id @{[$po->id]}) must have a status of 'Delivered'}
          . qq{ or 'Part Delivered' before it can send status updates to Fulcrum}
        unless ($po->status_id == $PURCHASE_ORDER_STATUS__PART_DELIVERED
             or $po->status_id == $PURCHASE_ORDER_STATUS__DELIVERED );

    my %status_map = (
        $PURCHASE_ORDER_STATUS__PART_DELIVERED => 'Part Delivered',
        $PURCHASE_ORDER_STATUS__DELIVERED      => 'Delivered',
    );
    my $msg = {
        purchase_order_number => $po->purchase_order_number,
        status                => $status_map{$po->status_id},
    };
    return (
        $header,
        $msg
    );
}

1;
