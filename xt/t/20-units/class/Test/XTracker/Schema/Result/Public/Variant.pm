package Test::XTracker::Schema::Result::Public::Variant;

use NAP::policy     qw( tt test class );
BEGIN {
    extends 'NAP::Test::Class';
}

=head1 NAME

Test::XTracker::Schema::Result::Public::Variant

=head1 DESCRIPTION

Tests methods for the 'Result::Public::Variant' and
'ResultSet::Public::Variant' Class.

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::PreOrder;

use XTracker::Constants::FromDB qw(
    :stock_order_item_status
);


sub startup : Test( startup => no_plan ) {
    my $self = shift;

    $self->SUPER::startup;

    $self->{channel} = Test::XTracker::Data->channel_for_business( name => 'nap' );
}

sub setup : Test( setup => no_plan ) {
    my $self = shift;

    $self->SUPER::setup;

    $self->schema->txn_begin;

    $self->{pids} = Test::XTracker::Data->find_or_create_products( {
        how_many     => 1,
        force_create => 1,
        channel_id   => $self->{channel}->id,
    } );
}

sub teardown : Test( teardown => no_plan ) {
    my $self = shift;

    $self->SUPER::teardown;

    $self->schema->txn_rollback;
}


=head1 TESTS

=head2 test_estimated_shipping_window

This tests the 'get_estimated_shipping_window' method which is used
primarily for displaying when we can expect stock for Pre-Orders to
the Operators.

=cut

sub test_estimated_shipping_window : Tests {
    my $self = shift;

    my $channel = $self->{channel};
    my $pids    = $self->{pids};

    note "TESTING Estimated shipping window calculation";

    my $pid     = $pids->[0]{pid};
    my $product = $self->rs('Public::Product')->find( $pid );

    # For a given pid, setup_purchase_order() method always creates a purchase order
    # for the same variant. Create a dummy PO to get the variant_id
    my $test_po = _create_n_purchase_orders(1, $pid);
    my $variant_id = ${$test_po}[0]->stock_orders->first
                                    ->stock_order_items->first
                                     ->variant_id;

    my $soi = $self->rs('Public::StockOrderItem')->search( {
        'variant_id' => $variant_id,
    } );

    # delete all stock_order_items for this variant
    $soi->search_related('link_delivery_item__stock_order_items')->delete;
    $soi->delete_all;

    # Create purchase order
    my $purchase_orders = _create_n_purchase_orders( 3, $pid);

    note "Purchase Order Created :". $purchase_orders->[0]->id. "\n";
    note "Purchase Order Created :". $purchase_orders->[1]->id. "\n";
    note "Purchase Order Created :". $purchase_orders->[2]->id. "\n";

    #update date of purchase order & window dates

    my $now       = $self->schema->db_now();
    my $yesterday = $now - DateTime::Duration->new( days => 1 );
    my $day_before_yesterday = $now - DateTime::Duration->new( days => 2);

    # specify the dates for the Purchase Orders
    my %args = (
        "Day Before Yesterday PO" => {
            po_date    => $day_before_yesterday,
            start_date => $now + DateTime::Duration->new( days => 1 ),
            end_date   => $now + DateTime::Duration->new( days => 10 ),
        },
        "Yesterday PO" => {
            po_date    => $yesterday,
            start_date => $now,
            end_date   => $now + DateTime::Duration->new( days => 2),
        },
        "NOW PO" => {
            po_date    => $now,
            start_date => $yesterday,
            end_date   => $now + DateTime::Duration->new( days => 3),
        },
    );

    # apply dates to the Purchase Orders
    _update_dates( $purchase_orders->[2], $args{"Day Before Yesterday PO"} );
    _update_dates( $purchase_orders->[0], $args{"Yesterday PO"} );
    _update_dates( $purchase_orders->[1], $args{"NOW PO"} );


    note " Test window date is returned correctly ";

    # get the Variant to use
    my $variant_obj = $self->rs('Public::Variant')->find( $variant_id );

    # set what dates to expect
    my $st_date  = $args{"NOW PO"}{start_date}->dmy;
    my $end_date = $args{"NOW PO"}{end_date}->dmy;

    note "it should pick up date of most recent purchase order among the above 3";
    my $window = $variant_obj->get_estimated_shipping_window();
    is( $window->{start_ship_date}, $st_date, "First - Start date is correct ". $st_date );
    is( $window->{cancel_ship_date}, $end_date, "First - End date is correct ". $end_date );

    note "Update one of the stockorder item to be delivered";
    my $so_1 = $purchase_orders->[1]->stock_orders->first
                                        ->stock_order_items->first;
    $so_1->update({'status_id' => $STOCK_ORDER_ITEM_STATUS__DELIVERED });
    $variant_obj->discard_changes;

    note "test now the window dates have changed latest po which is part delivered/on order";
    $st_date  = $args{"Yesterday PO"}{start_date}->dmy;
    $end_date = $args{"Yesterday PO"}{end_date}->dmy;

    $window = $variant_obj->get_estimated_shipping_window();
    is( $window->{start_ship_date}, $st_date, "Second - Start date is correct ". $st_date );
    is( $window->{cancel_ship_date}, $end_date, "Second - End date is correct ". $end_date );

    note "Update a PO's Stock Order's Shipping Window dates to be NULL";
    _update_dates( $purchase_orders->[0], { start_date => undef, end_date => undef } );
    $variant_obj->discard_changes;

    note "test that method still works and returns empty Hash Ref";
    $window = undef;    # clear previous test return values
    lives_ok {
        $window = $variant_obj->get_estimated_shipping_window();
    } "calling 'get_estimated_shipping_window' lives";
    cmp_ok( scalar( keys %{ $window } ), '==', 0, "No Shipping Window Dates returned" );

    note "create a new Stock Order wth a Shipping Window for the PO";
    my $so = Test::XTracker::Data->create_stock_order( {
        purchase_order_id   => $purchase_orders->[0]->id,
        product_id          => $pid,
        start_ship_date     => $args{"Yesterday PO"}->{start_date},
        cancel_ship_date    => $args{"Yesterday PO"}->{end_date},
    } );
    Test::XTracker::Data->create_stock_order_item( {
        stock_order_id => $so->id,
        variant_id     => $variant_obj->id,
    } );
    $variant_obj->discard_changes;

    note "test that the new Stock Order's Shipping Window is returned";
    $window = $variant_obj->get_estimated_shipping_window();
    is( $window->{start_ship_date}, $st_date, "Third - Start date is correct ". $st_date );
    is( $window->{cancel_ship_date}, $end_date, "Third - End date is correct ". $end_date );
}

=head2 test_can_be_pre_ordered_in_channel

Test the method 'can_be_pre_ordered_in_channel' that it returns TRUE or FALSE
depending on whether the Variants/Products can be Pre-Ordered.

=cut

sub test_can_be_pre_ordered_in_channel : Tests() {
    my $self = shift;

    # get all the details about the Variant
    my $pid_details = $self->{pids}[0];
    my $product     = $pid_details->{product}->discard_changes;
    my $prod_chann  = $pid_details->{product_channel}->discard_changes;
    my $variant     = $pid_details->{variant}->discard_changes;

    my $channel_id  = $self->{channel}->id;


    note "With Zero Stock on Order and the Product NOT Live - should return FALSE";

    # make sure the Product is NOT Live and there is NO Stock on Order
    $prod_chann->update( { live => 0 } );
    $variant->stock_order_items->update( { quantity => 0 } );

    ok( !$variant->can_be_pre_ordered_in_channel( $channel_id ), "'can_be_pre_ordered_in_channel' returns FALSE" );


    note "With Stock on Order and the Product NOT Live - should return TRUE";

    my $stock_order_item = $variant->stock_order_items->first;
    $stock_order_item->update( { quantity => 2 } );

    ok( $variant->can_be_pre_ordered_in_channel( $channel_id ), "'can_be_pre_ordered_in_channel' returns TRUE" );


    note "With More Stock on Order than Completed Pre-Orders and the Product NOT Live - should return TRUE";

    # make sure there is one Pre-Order for the Variant
    my $pre_order = Test::XTracker::Data::PreOrder->create_complete_pre_order( {
        channel  => $self->{channel},
        variants => [ $variant ],
    } );

    ok( $variant->can_be_pre_ordered_in_channel( $channel_id ), "'can_be_pre_ordered_in_channel' returns TRUE" );


    note "With the same amount of Stock on Order as Completed Pre-Orders and the Product NOT Live - should return FALSE";

    # make sure there is only 1 Item of Stock Ordered
    $stock_order_item->update( { quantity => 1 } );

    ok( !$variant->can_be_pre_ordered_in_channel( $channel_id ), "'can_be_pre_ordered_in_channel' returns FALSE" );


    note "With More Stock on Order than Completed Pre-Orders and the Product LIVE - should return FALSE";

    # there's only one Pre-Order so set Stock on Order to 2
    $stock_order_item->update( { quantity => 2 } );
    $prod_chann->update( { live => 1 } );

    ok( !$variant->can_be_pre_ordered_in_channel( $channel_id ), "'can_be_pre_ordered_in_channel' returns FALSE" );
}


#----------------------- Helper Methods------------------------------------------

sub _create_n_purchase_orders {
    my $number = shift;
    my $pid    = shift;

    my @po;
    foreach my $i (1..$number) {
        push(@po, Test::XTracker::Data->setup_purchase_order( $pid));
    }

    return \@po;
}

sub _update_dates {
    my $po   = shift;
    my $args = shift;

    my $po_date    = $args->{po_date};
    my $start_date = $args->{start_date};
    my $end_date   = $args->{end_date};

    my $so = $po->stock_orders->first;

    $po->update({'date' => $po_date })  if ( $po_date );

    $so->update({
       'start_ship_date'  => $start_date,
       'cancel_ship_date' => $end_date,
    });

}

