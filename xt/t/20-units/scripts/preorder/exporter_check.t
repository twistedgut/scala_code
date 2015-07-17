#!perl

use NAP::policy "tt", 'test';
use parent 'NAP::Test::Class';

use Test::XTracker::Data;
use Test::XTracker::Data::PreOrder;
use XTracker::Constants::FromDB qw( :pre_order_item_status
                                    :pre_order_status );

use XTracker::Script::PreOrder::ExporterCheck;

sub setup :Tests(setup) {
    my $self = shift;

    $self->{schema} = Test::XTracker::Data->get_schema();

    $self->SUPER::setup();
}

sub teardown :Test(teardown) {
    my ($self) = @_;

    $self->SUPER::teardown();
}

sub test_part_exported_preorder :Tests()  {
    my $self = shift;

    my $pre_order = Test::XTracker::Data::PreOrder->create_part_exported_pre_order_with_a_missing_order();

    # Hack timestamp for one hour in the past
    foreach my $item ($pre_order->pre_order_items) {
        $item->pre_order_item_status_logs->search({
            pre_order_item_status_id => $PRE_ORDER_ITEM_STATUS__EXPORTED
        })->update({
            date => \"now() - INTERVAL '1 hour'"
        });
    }

    # Before script is run
    cmp_ok($pre_order->pre_order_status_id,'==', $PRE_ORDER_STATUS__PART_EXPORTED, 'PreOrder is part exported');

    foreach my $item ($pre_order->pre_order_items->search({pre_order_item_status_id => $PRE_ORDER_ITEM_STATUS__EXPORTED})) {
        my $count = $item->pre_order_item_status_logs->search({
            pre_order_item_status_id => $PRE_ORDER_ITEM_STATUS__EXPORTED,
            date => {
                '<=' => \"now() - INTERVAL '1 hour'"
            }
        })->count;
        cmp_ok($count, '==', 1, 'Export log entry found in the past');
    }

    # Run script
    XTracker::Script::PreOrder::ExporterCheck->new()->invoke();
    $pre_order->discard_changes();

    # After script has ran
    cmp_ok($pre_order->pre_order_status_id, '==', $PRE_ORDER_STATUS__PART_EXPORTED, 'PreOrder has correct value');

    foreach my $item ($pre_order->pre_order_items) {
        if ($item->reservation->link_shipment_item__reservations->count > 0) {
            cmp_ok($item->pre_order_item_status_id,'==', $PRE_ORDER_ITEM_STATUS__EXPORTED, 'PreOrderItem is exported');
        }
        else {
            cmp_ok($item->pre_order_item_status_id,'==', $PRE_ORDER_ITEM_STATUS__COMPLETE, 'PreOrderItem is complete');
        }
    }
}

Test::Class->runtests;
