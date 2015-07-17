#!/usr/bin/env perl

use NAP::policy "tt", 'test';

use parent 'NAP::Test::Class';

=head2 Tests methods on the 'XTracker::Schema::Result::Public::PreOrder*'

These test should be used to test small utility methods found on the 'Public::PreOrder*' modules.

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::Operator;
use Test::XTracker::Data::PreOrder;
use Test::XTracker::Mock::PSP;
use XTracker::Constants           qw( :application );
use XTracker::Constants::PreOrder qw( :pre_order_operator_control );
use XTracker::Constants::FromDB   qw( :department
                                      :authorisation_level
                                      :pre_order_status
                                      :pre_order_item_status
                                      :pre_order_refund_status );

sub startup : Test( startup => no_plan ) {
    my ($self) = @_;

    $self->SUPER::startup();

    # get any operator that isn't the Application
    $self->{operator} = $self->rs('Public::Operator')->search(
        {
            id => { '!=' => $APPLICATION_OPERATOR_ID },
        },
    )->first;
}

sub setup : Test( setup => no_plan ) {
    my $self = shift;
    $self->SUPER::setup();

    $self->schema->txn_begin;
}

sub teardown : Test( teardown => no_plan ) {
    my $self = shift;
    $self->SUPER::teardown();

    $self->schema->txn_rollback;
}

=head1 TESTS

=cut

# test updating Statuses for PreOrder, PreOrderItem and PreOrderRefund
sub test_updating_status : Tests() {
    my ($self) = @_;

    note "TESTING Updating Statuses";

    my $pre_order       = Test::XTracker::Data::PreOrder->create_complete_pre_order( { with_no_status_logs => 1 } );
    my ( $pre_order_item, $other_item ) = $pre_order->pre_order_items
                                                        ->search( undef, { order_by => 'id' } )
                                                            ->all;

    # get any operator that isn't the Application
    my $operator = $self->{operator};
    $operator->update( { department_id => $DEPARTMENT__PERSONAL_SHOPPING } );

    # delete any logs
    $pre_order->pre_order_status_logs->delete;
    $pre_order_item->pre_order_item_status_logs->delete;
    my $pre_order_log_rs        = $pre_order->pre_order_status_logs
                                                ->search( undef, { order_by => 'id DESC' } );
    my $pre_order_item_log_rs   = $pre_order_item->pre_order_item_status_logs
                                                ->search( undef, { order_by => 'id DESC' } );
    # to use for comparisons in later tests
    my @pre_order_log_ids;
    my @item_log_ids;
    my @refund_log_ids;

    # start at known statuses
    $pre_order->update( { pre_order_status_id => $PRE_ORDER_STATUS__INCOMPLETE } );
    $pre_order_item->update( { pre_order_item_status_id => $PRE_ORDER_ITEM_STATUS__SELECTED } );

    note "test updating Pre Order Status";

    $pre_order->update_status( $PRE_ORDER_STATUS__EXPORTED, $operator->id );
    cmp_ok( $pre_order->pre_order_status_id, '==', $PRE_ORDER_STATUS__EXPORTED,
                                        "Updated Pre Order Status correctly when passing an Operator Id" );
    my $log = $pre_order_log_rs->reset->first;
    isa_ok( $log, 'XTracker::Schema::Result::Public::PreOrderStatusLog', "Log record created" );
    cmp_ok( $log->pre_order_status_id, '==', $PRE_ORDER_STATUS__EXPORTED,
                                        "Log has the correct Status Id" );
    cmp_ok( $log->operator_id, '==', $operator->id,
                                        "Log has the correct Operator Id" );
    push @pre_order_log_ids, $log->id;

    $pre_order->update_status( $PRE_ORDER_STATUS__CANCELLED );
    cmp_ok( $pre_order->pre_order_status_id, '==', $PRE_ORDER_STATUS__CANCELLED,
                                        "Updated Pre Order Status correctly when NOT passing an Operator Id" );
    $log    = $pre_order_log_rs->reset->first;
    cmp_ok( $log->pre_order_status_id, '==', $PRE_ORDER_STATUS__CANCELLED,
                                        "Log has the correct Status Id" );
    cmp_ok( $log->operator_id, '==', $APPLICATION_OPERATOR_ID,
                                        "Log uses the Application Operator Id" );
    push @pre_order_log_ids, $log->id;

    note "test updating Pre Order Item Status";

    $pre_order_item->update_status( $PRE_ORDER_ITEM_STATUS__EXPORTED, $operator->id );
    cmp_ok( $pre_order_item->pre_order_item_status_id, '==', $PRE_ORDER_ITEM_STATUS__EXPORTED,
                                        "Updated Pre Order Status correctly when passing an Operator Id" );
    $log    = $pre_order_item_log_rs->reset->first;
    isa_ok( $log, 'XTracker::Schema::Result::Public::PreOrderItemStatusLog', "Log record created" );
    cmp_ok( $log->pre_order_item_status_id, '==', $PRE_ORDER_ITEM_STATUS__EXPORTED,
                                        "Log has the correct Status Id" );
    cmp_ok( $log->operator_id, '==', $operator->id,
                                        "Log has the correct Operator Id" );
    push @item_log_ids, $log->id;

    $pre_order_item->update_status( $PRE_ORDER_ITEM_STATUS__CANCELLED );
    cmp_ok( $pre_order_item->pre_order_item_status_id, '==', $PRE_ORDER_ITEM_STATUS__CANCELLED,
                                        "Updated Pre Order Status correctly when NOT passing an Operator Id" );
    $log    = $pre_order_item_log_rs->reset->first;
    cmp_ok( $log->pre_order_item_status_id, '==', $PRE_ORDER_ITEM_STATUS__CANCELLED,
                                        "Log has the correct Status Id" );
    cmp_ok( $log->operator_id, '==', $APPLICATION_OPERATOR_ID,
                                        "Log uses the Application Operator Id" );
    push @item_log_ids, $log->id;

    note "test updating Pre Order Refund Status";
    my $pre_order_refund        = Test::XTracker::Data::PreOrder->create_refund_for_pre_order( $pre_order, 2 );
    my $pre_order_refund_log_rs = $pre_order_refund->pre_order_refund_status_logs
                                                ->search( undef, { order_by => 'id DESC' } );

    $pre_order_refund->update_status( $PRE_ORDER_REFUND_STATUS__FAILED, $operator->id );
    cmp_ok( $pre_order_refund->pre_order_refund_status_id, '==', $PRE_ORDER_REFUND_STATUS__FAILED,
                                        "Updated Pre Order Refund Status correctly when passing an Operator Id" );
    $log    = $pre_order_refund_log_rs->reset->first;
    isa_ok( $log, 'XTracker::Schema::Result::Public::PreOrderRefundStatusLog', "Log record created" );
    cmp_ok( $log->pre_order_refund_status_id, '==', $PRE_ORDER_REFUND_STATUS__FAILED,
                                        "Log has the correct Status Id" );
    cmp_ok( $log->operator_id, '==', $operator->id,
                                        "Log has the correct Operator Id" );
    push @refund_log_ids, $log->id;

    $pre_order_refund->update_status( $PRE_ORDER_REFUND_STATUS__CANCELLED );
    cmp_ok( $pre_order_refund->pre_order_refund_status_id, '==', $PRE_ORDER_REFUND_STATUS__CANCELLED,
                                        "Updated Pre Order Refund Status correctly when NOT passing an Operator Id" );
    $log    = $pre_order_refund_log_rs->reset->first;
    cmp_ok( $log->pre_order_refund_status_id, '==', $PRE_ORDER_REFUND_STATUS__CANCELLED,
                                        "Log has the correct Status Id" );
    cmp_ok( $log->operator_id, '==', $APPLICATION_OPERATOR_ID,
                                        "Log uses the Application Operator Id" );
    push @refund_log_ids, $log->id;


    note "check Status Log List Methods";

    note "test 'status_log_for_summary_page' for Pre-Order Status Logs";
    my @expected_log_keys   = qw(
                                log_id
                                status_date
                                status
                                operator_name
                                department
                            );
    my $list    = $pre_order->pre_order_status_logs->status_log_for_summary_page;
    isa_ok( $list, 'ARRAY', "method returned expected result" );
    is_deeply( [ map { $_->{log_id} } @{ $list } ], \@pre_order_log_ids, "and the List has all of the Logs in the expected sequence" );
    isa_ok( $list->[0], 'HASH', "first element is as expected" );
    is_deeply( [ map { $_ } sort keys %{ $list->[0] } ], [ sort @expected_log_keys ], "and has the expected keys in it" );
    $pre_order->pre_order_status_logs->delete;
    $list   = $pre_order->pre_order_status_logs->status_log_for_summary_page;
    cmp_ok( @{ $list }, '==', 0, "when there are NO logs returns empty Array Ref" );

    note "test 'status_log_for_summary_page' for Pre-Order Items";
    @expected_log_keys  = qw(
                                log_id
                                item_obj
                                status_date
                                status
                                operator_name
                                department
                            );
    # update another Item's status
    $other_item->update_status( $PRE_ORDER_ITEM_STATUS__EXPORTED );
    push @item_log_ids, $other_item->pre_order_item_status_logs->first->id;

    $list   = $pre_order->pre_order_items->status_log_for_summary_page;
    isa_ok( $list, 'ARRAY', "method returned expected result" );
    is_deeply( [ map { $_->{log_id} } @{ $list } ], \@item_log_ids, "and the List has all of the Logs in the expected sequence" );
    isa_ok( $list->[0], 'HASH', "first element is as expected" );
    is_deeply( [ map { $_ } sort keys %{ $list->[0] } ], [ sort @expected_log_keys ], "and has the expected keys in it" );
    $pre_order->pre_order_items->search_related('pre_order_item_status_logs')->delete;
    $list   = $pre_order->pre_order_items->status_log_for_summary_page;
    cmp_ok( @{ $list }, '==', 0, "when there are NO logs returns empty Array Ref" );

    note "test 'status_log_for_summary_page' for Pre-Order Refund Status Logs";
    @expected_log_keys  = qw(
                                log_id
                                status_date
                                status
                                operator_name
                                department
                            );
    $list   = $pre_order_refund->pre_order_refund_status_logs->status_log_for_summary_page;
    isa_ok( $list, 'ARRAY', "method returned expected result" );
    is_deeply( [ map { $_->{log_id} } @{ $list } ], \@refund_log_ids, "and the List has all of the Logs in the expected sequence" );
    isa_ok( $list->[0], 'HASH', "first element is as expected" );
    is_deeply( [ map { $_ } sort keys %{ $list->[0] } ], [ sort @expected_log_keys ], "and has the expected keys in it" );
    $pre_order_refund->pre_order_refund_status_logs->delete;
    $list   = $pre_order_refund->pre_order_refund_status_logs->status_log_for_summary_page;
    cmp_ok( @{ $list }, '==', 0, "when there are NO logs returns empty Array Ref" );

    return;
}


sub test_operator_transfer :Tests() {
    my ($self) = @_;

    my $pre_order_transfer_subsection_id = $self->schema->resultset('Public::AuthorisationSubSection')->search({
        sub_section => $PRE_ORDER_OPERATOR_CONTROL__OPERATOR_TRANSFER_SUBSECTION
    })->first->id;

    my $credit_hold_subsection_id = $self->schema->resultset('Public::AuthorisationSubSection')->search({
        sub_section => 'Credit Hold'
    })->first->id;

    my $customer_care_manager = Test::XTracker::Data::Operator->create_new_operator_with_authorisation({
        authorisation_sub_section_id => $pre_order_transfer_subsection_id,
        authorisation_level_id       => $AUTHORISATION_LEVEL__MANAGER,
        department_id                => $DEPARTMENT__PERSONAL_SHOPPING,
    });
    isa_ok($customer_care_manager, 'XTracker::Schema::Result::Public::Operator');

    my $other_manager = Test::XTracker::Data::Operator->create_new_operator_with_authorisation({
        authorisation_sub_section_id => $credit_hold_subsection_id,
        authorisation_level_id       => $AUTHORISATION_LEVEL__MANAGER,
        department_id                => $DEPARTMENT__DISTRIBUTION,
    });
    isa_ok($other_manager, 'XTracker::Schema::Result::Public::Operator');

    my $personal_shopper_operator_1 = Test::XTracker::Data::Operator->create_new_operator_with_authorisation({
        authorisation_sub_section_id => $pre_order_transfer_subsection_id,
        authorisation_level_id       => $AUTHORISATION_LEVEL__OPERATOR,
        department_id                => $DEPARTMENT__PERSONAL_SHOPPING,
    });
    isa_ok($personal_shopper_operator_1, 'XTracker::Schema::Result::Public::Operator');

    my $personal_shopper_operator_2 = Test::XTracker::Data::Operator->create_new_operator_with_authorisation({
        authorisation_sub_section_id => $pre_order_transfer_subsection_id,
        authorisation_level_id       => $AUTHORISATION_LEVEL__OPERATOR,
        department_id                => $DEPARTMENT__PERSONAL_SHOPPING,
    });
    isa_ok($personal_shopper_operator_2, 'XTracker::Schema::Result::Public::Operator');

    my $personal_shopper_operator_3 = Test::XTracker::Data::Operator->create_new_operator_with_authorisation({
        authorisation_sub_section_id => $pre_order_transfer_subsection_id,
        authorisation_level_id       => $AUTHORISATION_LEVEL__OPERATOR,
        department_id                => $DEPARTMENT__FASHION_ADVISOR,
    });
    isa_ok($personal_shopper_operator_3, 'XTracker::Schema::Result::Public::Operator');

    note 'Transfer from one operator to another by customer care manager';
    $self->_do_operator_transfer_and_test_for_success($personal_shopper_operator_1, $personal_shopper_operator_2, $customer_care_manager);

    note 'Transfer from one operator to another by another manager';
    $self->_do_operator_transfer_and_test_for_failure($personal_shopper_operator_1, $personal_shopper_operator_2, $other_manager);

    note 'Transfer from one operator to another by first operator';
    $self->_do_operator_transfer_and_test_for_success($personal_shopper_operator_1, $personal_shopper_operator_2, $personal_shopper_operator_1);

    note 'Transfer from one operator to another by second operator';
    $self->_do_operator_transfer_and_test_for_failure($personal_shopper_operator_1, $personal_shopper_operator_2, $personal_shopper_operator_2);

    note 'Transfer from one operator to another by third operator';
    $self->_do_operator_transfer_and_test_for_failure($personal_shopper_operator_1, $personal_shopper_operator_2, $personal_shopper_operator_3);

    note 'Transfer to and from same operator';
    $self->_do_operator_transfer_and_test_for_failure($personal_shopper_operator_1, $personal_shopper_operator_1, $personal_shopper_operator_1);
}

=head2 test_get_total_without_discount

Tests the 'get_total_without_discount' method that returns the Total Value
for the Pre-Order Items without a Discount applied.

=cut

sub test_get_total_without_discount : Tests() {
    my $self = shift;

    my $products = Test::XTracker::Data::PreOrder->create_pre_orderable_products( { num_products => 2 } );
    my @variants = map { $_->variants->first } @{ $products };
    my @pids     = map { $_->id } sort { $a->id <=> $b->id } @{ $products };

    my $channel  = $products->[0]->product_channel->first->channel;
    my $operator = $self->{operator};

    my %tests = (
        "with Original Values same as regular Values" => {
            setup => {
                item_prices => {
                    $pids[0] => {
                        unit_price => 100,
                        tax        => 10,
                        duty       => 15,
                    },
                    $pids[1] => {
                        unit_price => 200,
                        tax        => 20,
                        duty       => 25,
                    },
                },
                original_prices => {
                    $pids[0] => {
                        unit_price => 100,
                        tax        => 10,
                        duty       => 15,
                    },
                    $pids[1] => {
                        unit_price => 200,
                        tax        => 20,
                        duty       => 25,
                    },
                },
            },
            expect => {
                total_value          => 370,
                total_original_value => 370,
            },
        },
        "with different Original Values to regular Values" => {
            setup => {
                item_prices => {
                    $pids[0] => {
                        unit_price => 100,
                        tax        => 10,
                        duty       => 15,
                    },
                    $pids[1] => {
                        unit_price => 200,
                        tax        => 20,
                        duty       => 25,
                    },
                },
                original_prices => {
                    $pids[0] => {
                        unit_price => 150,
                        tax        => 15,
                        duty       => 20,
                    },
                    $pids[1] => {
                        unit_price => 250,
                        tax        => 25,
                        duty       => 30,
                    },
                },
            },
            expect => {
                total_value          => 370,
                total_original_value => 490,
            },
        },
        "even though with a Discount of 50% this ignored and just uses the actual Original Values on the records" => {
            setup => {
                discount    => 50,
                item_prices => {
                    $pids[0] => {
                        unit_price => 100,
                        tax        => 10,
                        duty       => 15,
                    },
                    $pids[1] => {
                        unit_price => 200,
                        tax        => 20,
                        duty       => 25,
                    },
                },
                original_prices => {
                    $pids[0] => {
                        unit_price => 150,
                        tax        => 35,
                        duty       => 20,
                    },
                    $pids[1] => {
                        unit_price => 250,
                        tax        => 25,
                        duty       => 30,
                    },
                },
            },
            expect => {
                total_value          => 370,
                total_original_value => 510,
            },
        },
    );

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test   = $tests{ $label };
        my $setup  = $test->{setup};
        my $expect = $test->{expect};

        my $pre_order = Test::XTracker::Data::PreOrder->create_complete_pre_order( {
            channel                      => $channel,
            item_product_prices          => $setup->{item_prices},
            original_item_product_prices => $setup->{original_prices},
            variants                     => \@variants,
            discount_percentage          => $setup->{discount} // 0,
            ( $setup->{discount} ? ( discount_operator => $operator ) : () ),
        } );

        my $total          = _d2( $pre_order->total_uncancelled_value );
        my $total_original = _d2( $pre_order->get_total_without_discount );

        is( $total, _d2( $expect->{total_value} ), "Total Value is as Expected" );
        is( $total_original, _d2( $expect->{total_original_value} ), "Total Original Value is as Expected" );

        note "now Cancel an Item and make sure the Totals change accordingly";
        my ( $item ) = grep { $_->variant->product_id == $pids[0] } $pre_order->pre_order_items;
        $item->update_status( $PRE_ORDER_ITEM_STATUS__CANCELLED );
        $pre_order->discard_changes;

        # work out the new expected Values
        my $expect_value          = $setup->{item_prices}{ $pids[1] }{unit_price} +
                                    $setup->{item_prices}{ $pids[1] }{tax} +
                                    $setup->{item_prices}{ $pids[1] }{duty};
        my $expect_original_value = $setup->{original_prices}{ $pids[1] }{unit_price} +
                                    $setup->{original_prices}{ $pids[1] }{tax} +
                                    $setup->{original_prices}{ $pids[1] }{duty};

        $total          = _d2( $pre_order->total_uncancelled_value );
        $total_original = _d2( $pre_order->get_total_without_discount );
        is( $total, _d2( $expect_value ), "Total Value is as Expected" );
        is( $total_original, _d2( $expect_original_value ), "Total Original Value is as Expected" );
    }
}


sub _do_operator_transfer {
    my ($self, $original_operator, $new_operator, $by_operator) = @_;

    my $pre_order = Test::XTracker::Data::PreOrder->create_complete_pre_order({
        operator => $original_operator
    });

    cmp_ok($pre_order->operator_id, '==', $original_operator->id, 'The pre order has the correct operator');

    $pre_order->transfer_to_operator($new_operator, $by_operator);

    note $pre_order->operator_id;

    return $pre_order;
}

sub _do_operator_transfer_and_test_for_success {
    my ($self, $original_operator, $new_operator, $by_operator) = @_;

    my $pre_order = $self->_do_operator_transfer($original_operator, $new_operator, $by_operator);

    cmp_ok($pre_order->operator_id, '==', $new_operator->id, 'The pre order has the new operator');

    cmp_ok($pre_order->pre_order_operator_logs, '==', 1, 'Pre order has a log for the operator transfer');

    my $log_entry = $pre_order->pre_order_operator_logs->first;

    cmp_ok($log_entry->operator_id,      '==', $by_operator->id, 'Manager logged as doing the transfer');
    cmp_ok($log_entry->from_operator_id, '==', $original_operator->id, 'first operator logged as original operator');
    cmp_ok($log_entry->to_operator_id,   '==', $new_operator->id, 'second operator logged as new operator');

    foreach my $item ($pre_order->pre_order_items) {
        cmp_ok($item->reservation->operator->id, '==', $new_operator->id, 'Reservation has been transfered to new operator');
    }
}

sub _do_operator_transfer_and_test_for_failure {
    my ($self, $original_operator, $new_operator, $by_operator) = @_;

    my $pre_order = $self->_do_operator_transfer($original_operator, $new_operator, $by_operator);

    cmp_ok($pre_order->operator_id, '==', $original_operator->id, 'the original operator is still assigned to the pre order');

    cmp_ok($pre_order->pre_order_operator_logs, '==', 0, 'Pre order has a log for the operator transfer');

    foreach my $item ($pre_order->pre_order_items) {
        cmp_ok($item->reservation->operator->id, '==', $original_operator->id, 'Reservation has been transfered to new operator');
    }
}

# helper to get values to 2 decimal places
sub _d2 {
    my $value = shift;
    return sprintf( '%0.2f', $value );
}

Test::Class->runtests;
