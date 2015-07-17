#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

use Test::XTracker::RunCondition
    iws_phase => [1, 2];

use Test::XTracker::Data;

use Data::Dumper;



use DateTime;

use XTracker::Constants qw( $APPLICATION_OPERATOR_ID );

BEGIN {
    use_ok('XTracker::Database', qw( :common ));
    use_ok('XTracker::Database::PurchaseOrder', qw(
                            confirm_purchase_order
                        ));
}

my $schema  = Test::XTracker::Data->get_schema();
my $dbh     = $schema->storage->dbh;


# setup a public purchase order
ok(my $p = Test::XTracker::Data->grab_products({
    how_many => 1,
    channel_id=> Test::XTracker::Data->channel_for_nap()->id
}));

ok(my $product = $schema->resultset('Public::Product')->find($p->[0]->{pid}));
my $po = Test::XTracker::Data->setup_purchase_order($product->id);
isa_ok( $po, 'XTracker::Schema::Result::Public::PurchaseOrder', 'check type' );

ok( !$po->confirmed, 'Purchase order starts out unconfirmed' );
ok( !defined $po->when_confirmed, 'Purchase order starts out with no when_confirmed' );

confirm_purchase_order({
    dbh => $dbh,
    purchase_order_id => $po->id,
    operator_id => $APPLICATION_OPERATOR_ID,
});

my $fresh_po = $po->get_from_storage;
ok( $fresh_po->confirmed, 'confirm_purchase_order sets po confirmed' );
ok( $fresh_po->when_confirmed, 'confirm_purchase_order sets po when_confirmed' );
can_ok( $fresh_po->when_confirmed, 'ymd' );

note("The confirmed date is: " . $fresh_po->when_confirmed);

subtest 'Test stock order cancel status' => sub {
    plan tests => 2;
    # Cancel a stock order then attempt to cancel a purchase order

    foreach my $so ( $po->stock_orders ) {
        isa_ok( $so, 'XTracker::Schema::Result::Public::StockOrder');
        # Cancel stock order
        $so->update( { stock_order_cancel => 1 });
        ok($so->stock_order_cancel, 'Stock order cancel flag has been set to true');
    }
};

# Cancel PO
$po->cancel_po;
ok($po->cancel, 'PO has been cancelled');
# Attempt to uncancel the purchase order
$po->uncancel_po;
ok(!$po->cancel, "PO has been uncancelled");

# When uncancelling a purchase order containing a stock order that was already
# cancelled via EditPO, test that the stock order remains cancelled.
subtest 'Test stock order remains cancelled after PO uncancelled' => sub {
    plan tests => 2;

    foreach my $so ( $po->stock_orders ) {
        ok($so->stock_order_cancel,
            'Stock order remains cancelled, even though PO has been uncancelled');

        ok($so->cancel,
            'Cancel flag remain set to true, even if purchase order was uncancelled')
    }
};

done_testing();
