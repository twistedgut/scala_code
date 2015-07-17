#!/opt/xt/xt-perl/bin/perl

# This script will fix two products that are in an incorrect state so we can
# complete their product transfer

#use lib '/opt/xt/deploy/xtracker/lib';
use FindBin::libs qw( base=lib_dynamic );
use NAP::policy qw/tt/;
use XTracker::Constants '$APPLICATION_OPERATOR_ID';
use XTracker::Constants::FromDB qw/:shipment_status :shipment_item_status/;
use XTracker::Database;

my $schema = schema_handle();
my $shipment_rs = $schema->resultset('Public::Shipment');

$schema->txn_do(sub{
    fix_shipment_status( @$_ ) && say "Updated shipment $_->[0] successfully"
        for (
            [3057224, $SHIPMENT_STATUS__CANCELLED, $SHIPMENT_ITEM_STATUS__SELECTED],
            [2896658,  $SHIPMENT_STATUS__CANCELLED, $SHIPMENT_ITEM_STATUS__CANCEL_PENDING],
        );
});
say 'DONE';

sub fix_shipment_status {
    my ( $shipment_id, $shipment_status_id, $shipment_item_status_id ) = @_;
    my $shipment_item = $shipment_rs
        ->search({ 'me.id' => $shipment_id, shipment_status_id => $shipment_status_id })
        ->search_related('shipment_items',
            { shipment_item_status_id => $shipment_item_status_id },
            { rows => 1 },
        )->single;

    die "Could not find item with status of $shipment_item_status_id in shipment $shipment_id (status $shipment_status_id)"
        unless $shipment_item;

    return $shipment_item->update_status(
        $SHIPMENT_ITEM_STATUS__CANCELLED, $APPLICATION_OPERATOR_ID,
    );
}
