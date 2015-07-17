package  Test::XTracker::Schema::ResultSet::Public::PreOrder;
use NAP::policy qw/test class/;

BEGIN {
    extends 'NAP::Test::Class';
};

use XTracker::Constants                     qw( :application );
=head1 NAME

Test::XTracker::Schema::ResultSet::Public::PreOrder

=head1 DESCRIPTION

Tests the L<Test::XTracker::Schema::ResultSet::Public::PreOrder> class.

=cut

use Test::XTracker::Data::PreOrder;
use Test::XTracker::Data;
use Test::XTracker::Data::Operator;
use XTracker::Constants::FromDB qw(
    :department
    :pre_order_status
    :shipment_status
);
use DateTime;
use FindBin::libs;

=head1 TESTS

=head2 startup

Checks the class being tested can be loaded OK.

=cut

sub startup : Test( startup => no_plan ) {
    my $self = shift;
    $self->SUPER::startup();

    require_ok( 'XTracker::Schema::ResultSet::Public::PreOrder' );

}

=head2 setup

Begins a database transaction.

=cut

sub setup : Test( setup => no_plan ) {
    my $self = shift;
    $self->SUPER::setup();

    $self->schema->txn_begin;
}

=head2 teardown

Rolls back the database transaction.

=cut

sub teardown : Test( teardown => no_plan ) {
    my $self = shift;
    $self->SUPER::teardown();

    $self->schema->txn_rollback;
}

sub test__get_pre_order_list : Tests {
    my $self = shift;

    my $schema = $self->schema();

    my $six_month =  DateTime->now->subtract( months => 6 );
    my $one_month =  DateTime->now->subtract( months => 1 );
    #create 2 new operator
    my $new_operator = Test::XTracker::Data::Operator->create_new_operator();
    my $alt_operator = Test::XTracker::Data::Operator->create_new_operator();

    my @operator = ($new_operator->id,$alt_operator->id);

    isa_ok( $new_operator, 'XTracker::Schema::Result::Public::Operator', 'New operator' );

    my $expected;
    my $preorder_obj = $schema->resultset('Public::PreOrder');
    #create few preorders for each operator.
    my $pre_order1      = Test::XTracker::Data::PreOrder->create_complete_pre_order;
    my ( $pre_order2 )  = Test::XTracker::Data::PreOrder->create_part_exported_pre_order;
    $pre_order1->update({operator_id => $new_operator->id , created => $six_month});
    $pre_order2->update({operator_id => $new_operator->id });
    $expected->{$pre_order2->id} = 1;

    # TEST 1: Preorder for only 1 month are  shown
    my $resultset = $preorder_obj->get_pre_order_list( { age => '1 month',operator_id => $new_operator->id});
    my $got;
    foreach my $rs ( $resultset->all ) {
        if ($rs->operator->id ~~  @operator ) {
                $got->{$rs->id} =1;
        }
    }
    cmp_deeply( $got, $expected, "Test 1: Only one preorder is listed as expected" );

    my $pre_order3      = Test::XTracker::Data::PreOrder->create_complete_pre_order;
    my $pre_order4      = Test::XTracker::Data::PreOrder->create_complete_pre_order;
    $pre_order3->update({operator_id => $alt_operator->id });
    $pre_order4->update({operator_id => $alt_operator->id ,created => $one_month });
    $got = {};
    $expected = {};
    $expected->{$pre_order3->id} = 1;
    $expected->{$pre_order4->id} = 1;


    #Test 2: Preorder results defaults to 6 month if not given
    # call method and test it shows the same resultset
    $resultset = $preorder_obj->get_pre_order_list( { operator_id => $alt_operator->id});

    foreach my $rs ( $resultset->all ) {
        if ($rs->operator->id ~~  @operator ) {
                $got->{$rs->id} =1;

        }
    }
    cmp_deeply( $got, $expected, "Test 2:Both the Preorder are in the list as expected" );

}

=head2 test__get_pre_orders_on_hold

Test the C<get_exported_pre_orders_on_hold> method.

The scenarios in this test use the following methods:
    test__get_pre_orders_on_hold_INIT
    test__get_pre_orders_on_hold_TEST

=cut

sub test__get_pre_orders_on_hold : Tests {
    my $self = shift;

    $self->test_scenarios( {
        # Exported Pre-Orders
        'Pre-Order Exported, Shipment on Hold' => {
            pre_order_status    => $PRE_ORDER_STATUS__EXPORTED,
            shipment_status     => $SHIPMENT_STATUS__HOLD,
            expected_count      => 2,
        },
        'Pre-Order Exported, Shipment on Finance Hold' => {
            pre_order_status    => $PRE_ORDER_STATUS__EXPORTED,
            shipment_status     => $SHIPMENT_STATUS__FINANCE_HOLD,
            expected_count      => 2,
        },
        'Pre-Order Exported, Shipment on DDU Hold' => {
            pre_order_status    => $PRE_ORDER_STATUS__EXPORTED,
            shipment_status     => $SHIPMENT_STATUS__DDU_HOLD,
            expected_count      => 2,
        },
        'Pre-Order Exported, Shipment Delivered' => {
            pre_order_status    => $PRE_ORDER_STATUS__EXPORTED,
            shipment_status     => $SHIPMENT_STATUS__DELIVERED,
            expected_count      => 1,
        },
        # Part Exported Pre-Orders
        'Pre-Order Part Exported, Shipment on Hold' => {
            pre_order_status    => $PRE_ORDER_STATUS__PART_EXPORTED,
            shipment_status     => $SHIPMENT_STATUS__HOLD,
            expected_count      => 2,
        },
        'Pre-Order Part Exported, Shipment on Finance Hold' => {
            pre_order_status    => $PRE_ORDER_STATUS__PART_EXPORTED,
            shipment_status     => $SHIPMENT_STATUS__FINANCE_HOLD,
            expected_count      => 2,
        },
        'Pre-Order Part Exported, Shipment on DDU Hold' => {
            pre_order_status    => $PRE_ORDER_STATUS__PART_EXPORTED,
            shipment_status     => $SHIPMENT_STATUS__DDU_HOLD,
            expected_count      => 2,
        },
        'Pre-Order Part Exported, Shipment Delivered' => {
            pre_order_status    => $PRE_ORDER_STATUS__PART_EXPORTED,
            shipment_status     => $SHIPMENT_STATUS__DELIVERED,
            expected_count      => 1,
        },
        # Complete Pre-Orders
        'Pre-Order Complete, Shipment on Hold' => {
            pre_order_status    => $PRE_ORDER_STATUS__COMPLETE,
            shipment_status     => $SHIPMENT_STATUS__HOLD,
            expected_count      => 1
        },
        'Pre-Order Complete, Shipment on Finance Hold' => {
            pre_order_status    => $PRE_ORDER_STATUS__COMPLETE,
            shipment_status     => $SHIPMENT_STATUS__FINANCE_HOLD,
            expected_count      => 1,
        },
        'Pre-Order Complete, Shipment on DDU Hold' => {
            pre_order_status    => $PRE_ORDER_STATUS__COMPLETE,
            shipment_status     => $SHIPMENT_STATUS__DDU_HOLD,
            expected_count      => 1,
        },
        'Pre-Order Complete, Shipment Delivered' => {
            pre_order_status    => $PRE_ORDER_STATUS__COMPLETE,
            shipment_status     => $SHIPMENT_STATUS__DELIVERED,
            expected_count      => 1,
        },
    }, 'Pre-Order on Hold Scenarios' );

}

=head1 SCENARIO METHODS

=head2 test__get_pre_orders_on_hold_INIT

Create two Pre-Orders, one that will always be included in the results and
another 'dynamic' one that will be updated in each test.

=cut

sub test__get_pre_orders_on_hold_INIT {
    my $self = shift;

    my ( $static_pre_order )    = Test::XTracker::Data::PreOrder->create_part_exported_pre_order;
    my ( $dynamic_pre_order )   = Test::XTracker::Data::PreOrder->create_part_exported_pre_order;

    $self->update_pre_order_and_related_shipment_statuses(
        $static_pre_order,
        $PRE_ORDER_STATUS__EXPORTED,
        $SHIPMENT_STATUS__HOLD );

    return ( $static_pre_order, $dynamic_pre_order );

}

=head2 test__get_pre_orders_on_hold_TEST

Updates the 'dynamic' Pre-Order, calls the C<get_exported_pre_orders_on_hold> method
and checks the number of Pre-Orders returned is correct.

=cut

sub test__get_pre_orders_on_hold_TEST {
    my $self = shift;
    my ( $test_name, $test_data, $static_pre_order, $dynamic_pre_order ) = @_;

    $self->update_pre_order_and_related_shipment_statuses( $dynamic_pre_order,
        $test_data->{pre_order_status},
        $test_data->{shipment_status} );

    my @results = $self->schema->resultset('Public::PreOrder')
        ->search({ id => { in => [ $static_pre_order->id, $dynamic_pre_order->id ] } })
        ->as_subselect_rs
        ->get_exported_pre_orders_on_hold
        ->all;

    cmp_ok( scalar @results, '==', $test_data->{expected_count},
        "Got $test_data->{expected_count} Pre-Orders as expected" );

}

=head1 METHODS

=head2 update_pre_order_and_related_shipment_statuses( $pre_order, $pre_order_status, $shipment_status )

Update a given C<$pre_order> to have a status of C<$pre_order_status> and it's
related shipments to have statuses of C<$shipment_status>.

=cut

sub update_pre_order_and_related_shipment_statuses {
    my $self = shift;
    my ( $pre_order, $pre_order_status, $shipment_status ) = @_;

    $pre_order
        ->update({ pre_order_status_id => $pre_order_status });

    $pre_order
        ->link_orders__pre_orders
        ->search_related('orders')
        ->search_related('link_orders__shipments')
        ->search_related('shipment')
        ->update({ shipment_status_id => $shipment_status });

}
