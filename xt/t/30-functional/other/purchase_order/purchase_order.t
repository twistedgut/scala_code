#!/usr/bin/env perl
use NAP::policy "tt", 'test';
#
# Test the Purchase Order workflow and pages
#

use Test::XT::Flow;
use XTracker::Constants::FromDB qw( :authorisation_level  );

my $flow = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Data::PurchaseOrder',
        'Test::XT::Flow::StockControl',
        'Test::XT::Feature::Ch11n::StockControl',
        'Test::XT::Feature::Ch11n',
    ],
);

my $permissions = {
    $AUTHORISATION_LEVEL__OPERATOR => [
        'Stock Control/Purchase Order',
        'Stock Control/Location',
    ],
};

$flow->login_with_permissions({
        dept => 'Distribution Management',
        perms => $permissions,
    })
    ->flow_mech__stockcontrol__purchaseorder
        ->test_mech__stockcontrol__purchaseorder_ch11n
    ->flow_mech__stockcontrol__purchaseorder_submit
        ->test_mech__stockcontrol__purchaseorder_submit_ch11n
    # This method has been upgraded to not know about internally-held data
    ->flow_mech__stockcontrol__purchaseorder_overview( $flow->purchase_order->id )
        ->test_mech__stockcontrol__purchaseorder_overview_ch11n
    ->flow_mech__stockcontrol__purchaseorder_confirm
        ->test_mech__stockcontrol__purchaseorder_confirm_ch11n
    ->flow_mech__stockcontrol__purchaseorder_edit
        ->test_mech__stockcontrol__purchaseorder_edit_ch11n
    ->flow_mech__stockcontrol__purchaseorder_reorder
        ->test_mech__stockcontrol__purchaseorder_reorder_ch11n
    ->flow_mech__stockcontrol__purchaseorder_reorder_submit
        ->test_mech__stockcontrol__purchaseorder_reorder_submit_ch11n
    ->flow_mech__stockcontrol__purchaseorder_stockorder
        ->test_mech__stockcontrol__purchaseorder_stockorder_ch11n
    ->flow_mech__stockcontrol__purchaseorder_stockorder_submit
    ;

done_testing;
1;
