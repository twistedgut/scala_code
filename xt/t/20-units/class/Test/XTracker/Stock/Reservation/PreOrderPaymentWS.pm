package Test::XTracker::Stock::Reservation::PreOrderPaymentWS;

use NAP::policy "tt", qw( test );

use parent 'NAP::Test::Class';

=head1 NAME

Test::XTracker::Stock::Reservation::PreOrderPaymentWS

=head1 DESCRIPTION

Test XTracker::Stock::Reservation::PreOrderPaymentWS

=head1 TESTS

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::PreOrder;
use Test::XTracker::Mock::PSP;
use Test::XTracker::Mock::Handler;
use Test::XTracker::MessageQueue;

use XTracker::Config::Local qw(
    config_var
);

use XTracker::Stock::Reservation::PreOrderPaymentWS;
use XTracker::Constants::Payment        qw( :psp_return_codes
                                            :pre_order_payment_api_messages );


sub startup : Test( startup => no_plan ) {
    my ($self) = @_;

    $self->SUPER::startup;
    $self->{schema} = Test::XTracker::Data->get_schema();

    Test::XTracker::Mock::PSP->use_all_mocked_methods();    # get the PSP Mock in a known state
}

sub setup : Test( setup => no_plan ) {
    my ($self) = @_;

    $self->SUPER::setup;

    $self->{schema}->txn_begin;

    # Mock the PSP and set return values
    $self->{mock_psp} = XT::Domain::Payment->new();
    $self->{mock_psp}->set_preauth_death(0);
    $self->{mock_psp}->set_settle_payment_return_code($PSP_RETURN_CODE__SUCCESS);

    $self->{payment_session_id} = $self->{mock_psp}->create_new_payment_session(
        Test::XTracker::Mock::Handler->_build_session_id,
        $self->{mock_psp}->get_new_card_token );

    $self->{products} = Test::XTracker::Data::PreOrder->create_pre_orderable_products( {
        # make sure each Variant has enough stock on Order
        amount_of_stock_to_order => 100,
    } );
    $self->{incomplete_pre_order} = Test::XTracker::Data::PreOrder->create_incomplete_pre_order( {
        products => $self->{products},
    } );

}

sub test_shutdown : Test( shutdown => no_plan ) {
    my $self = shift;
    $self->SUPER::shutdown;

    Test::XTracker::Mock::PSP->use_all_original_methods();
}

=head2 test_pre_order_payment_with_good_data_but_pre_auth_reject

Process payment for a Pre Order with the correct parameters but have the Pre Auth rejected by the bank

=cut

sub test_pre_order_payment_with_good_data_but_preauth_reject : Tests() {
    my ($self) = @_;

    $self->{mock_psp}->set__preauth_with_payment_session__response__not_authorised;

    $self->run_tests_for_payment_declined_preorder({
        expected_error_message => $PRE_ORDER_PAYMENT_API_MESSAGE__BANK_REJECT,
        pre_order              => $self->{incomplete_pre_order},
    });
}

=head2 test_pre_order_payment_with_good_data_but_settle_reject

Process payment for a Pre Order with the correct parameters but have the Settle rejected by the bank

=cut

sub test_pre_order_payment_with_good_data_but_settle_reject : Tests() {
    my ($self) = @_;

    $self->{mock_psp}->set__preauth_with_payment_session__response__success;

    # First Attempt
    my $max_reservation_id_before_first_attempt = $self->{schema}->resultset('Public::Reservation')->get_column('id')->max() // 0;
    my $count_rs = $self->{schema}->resultset('Public::Reservation')->search({id => {'>' => $max_reservation_id_before_first_attempt}});

    $self->{mock_psp}->set_settle_payment_return_code($PSP_RETURN_CODE__BANK_REJECT);

    $self->run_tests_for_settle_failed_preorder({
        expected_error_message => sprintf($PRE_ORDER_PAYMENT_API_MESSAGE__BANK_REJECT_AT_SETTLE, 'to err is human'),
        pre_order              => $self->{incomplete_pre_order},
    });

    cmp_ok(
        $count_rs->reset->count,
        '==',
        $self->{incomplete_pre_order}->pre_order_items->count,
        'Correct number of reservation items created'
    );

    # Second Attempt
    my $max_reservation_id_after_first_attempt = $self->{schema}->resultset('Public::Reservation')->get_column('id')->max();

    $self->{mock_psp}->set_settle_payment_return_code($PSP_RETURN_CODE__SUCCESS);

    $self->run_tests_for_complete_preorder({
        pre_order    => $self->{incomplete_pre_order}
    });

    my $max_reservation_id_after_second_attempt = $self->{schema}->resultset('Public::Reservation')->get_column('id')->max();

    cmp_ok(
        $count_rs->reset->count,
        '==',
        $self->{incomplete_pre_order}->pre_order_items->count,
        'No additional reservations created'
    );

    cmp_ok(
        $max_reservation_id_after_second_attempt,
        '==',
        $max_reservation_id_after_first_attempt,
        'Max reservation id has not changed'
    );
}

=head2 test_pre_order_payment_with_good_data_but_pre_auth_reject

Process payment for a Pre Order with the correct parameters but have the Pre Auth rejected by the bank

=cut

sub test_pre_order_payment_with_preauth_death : Tests() {
    my ($self) = @_;

    $self->{mock_psp}->set__preauth_with_payment_session__response__die;

    $self->run_tests_for_incomplete_preorder({
        pre_order              => $self->{incomplete_pre_order},
        expected_error_message => $PRE_ORDER_PAYMENT_API_MESSAGE__UNABLE_TO_PREAUTH
    });
}

=head2 test_pre_order_payment_with_skus_that_can_no_longer_be_pre_ordered

Process payment for a Pre Order where one of the Items can no longer be Pre-Ordered
such as one of the Items is for a Live Product.

=cut

sub test_pre_order_payment_with_skus_that_can_no_longer_be_pre_ordered : Tests() {
    my ($self) = @_;

    my $pre_order = $self->{incomplete_pre_order};
    my @products  = map { $_->discard_changes->variant->product } $pre_order->pre_order_items->all;

    # make one of the Products Live, so it shouldn't be Pre-Ordered
    $products[0]->product_channel->update( { live => 1 } );

    $self->run_tests_for_incomplete_preorder( {
        expected_error_message => $PRE_ORDER_PAYMENT_API_MESSAGE__UNABLE_TO_CONFIRM_ORDER,
        pre_order              => $pre_order,
    } );
}


=head2 test_pre_order_payment_with_good_data

Process payment for a Pre Order with the correct parameters

=cut

sub test_pre_order_payment_with_good_data : Tests() {
    my ($self) = @_;

    $self->{mock_psp}->set__preauth_with_payment_session__response__success;

    $self->run_tests_for_complete_preorder({
        pre_order    => $self->{incomplete_pre_order}
    });
}

=head2 test_two_pre_orders_for_the_last_ordered_variant

Process payment for two Pre Orders with the same Variant ID but only one left 'on order'

=cut

sub test_two_pre_orders_for_the_last_ordered_variant : Tests() {
    my ($self) = @_;

    my ($first_pre_order, $second_pre_order) = Test::XTracker::Data::PreOrder->create_two_pre_orders_for_last_ordered_variant();
    isa_ok($first_pre_order, 'XTracker::Schema::Result::Public::PreOrder');
    isa_ok($second_pre_order, 'XTracker::Schema::Result::Public::PreOrder');

    cmp_ok($first_pre_order->pre_order_items, '==', 1, 'First pre order has one item');
    cmp_ok($second_pre_order->pre_order_items, '==', 1, 'Second pre order has one item');

    cmp_ok($first_pre_order->pre_order_items, '==', $second_pre_order->pre_order_items, 'Both have the same number of items in their basket');
    cmp_ok($first_pre_order->pre_order_items->first->variant->id, '==', $second_pre_order->pre_order_items->first->variant->id, 'Both have the same variant in their basket');

    ok($first_pre_order->can_confirm_all_items(), 'All items can be pre ordered');
    cmp_ok($first_pre_order->pre_order_items->first->variant->get_ordered_quantity_for_channel($first_pre_order->customer->channel->id), '==', 1, 'There is only one left in stock');

    $self->{mock_psp}->set__preauth_with_payment_session__response__success;

    $self->run_tests_for_complete_preorder({
        pre_order    => $first_pre_order
    });

    $self->run_tests_for_incomplete_preorder({
        pre_order              => $second_pre_order,
        expected_error_message => $PRE_ORDER_PAYMENT_API_MESSAGE__UNABLE_TO_CONFIRM_ORDER,
    });
}

=head2 test_pre_order_payment_with_decimal_places

Process payment for a Pre Order checking how decimals are handled and passed to the PSP:

IN        PSP
---------------
.0      = 0
.00     = 0
0.0     = 0
0.00    = 0
123     = 12300
123.0   = 12300
123.00  = 12300
123.04  = 12304
123.40  = 12340
123.4   = 12340
123.401 = 12340
123.405 = 12341
123.45  = 12345
123.450 = 12345

This checks the value that was passed to the PSP in the 'coinAmount' argument for 'init_with_payment_session' & 'settle_payment' PSP actions.

=cut

sub test_pre_order_payment_with_decimal_places : Tests() {
    my ($self) = @_;

    my @test_cases = (
        [ '.0'      , '0' ],
        [ '.00'     , '0' ],
        [ '0.0'     , '0' ],
        [ '0.00'    , '0' ],
        [ '123'     , '12300' ],
        [ '123.0'   , '12300' ],
        [ '123.00'  , '12300' ],
        [ '123.04'  , '12304' ],
        [ '123.40'  , '12340' ],
        [ '123.4'   , '12340' ],
        [ '123.401' , '12340' ],
        [ '123.405' , '12341' ],
        [ '123.45'  , '12345' ],
        [ '123.450' , '12345' ],
    );

    $self->{mock_psp}->set__preauth_with_payment_session__response__success;

    foreach my $test_case ( @test_cases ) {
        note "Test Case: " . join( ', ', @{ $test_case } );

        my $pre_order = Test::XTracker::Data::PreOrder->create_incomplete_pre_order( {
            products => $self->{products},
        } );

        # Overwrite the expected value
        $pre_order->update( {
            total_value => $test_case->[0],
        } );

        $self->run_tests_for_complete_preorder({
            pre_order    => $pre_order,
            coin_amount  => $test_case->[1],
        });
    }
}

sub test_complete_preorder : Tests {
    my $self = shift;

    my $pre_order = $self->{incomplete_pre_order};

    $self->{mock_psp}->set__preauth_with_payment_session__response__success;

    # Make sure we only record method calls related to this test.
    $self->{mock_psp}->clear_method_calls;

    # Run the test.
    $self->run_tests_for_complete_preorder( {
        pre_order => $pre_order,
    } );

    my $customer            = $pre_order->customer;
    my $address             = $pre_order->invoice_address;
    my $channel             = $pre_order->channel;
    my $merchant_channel    = config_var( 'PaymentService_' . $channel->business->config_section, 'merchant_channel' );
    my $merchant_url        = config_var( 'PaymentService_' . $channel->business->config_section, 'merchant_url' );
    my $dc_channel          = config_var( 'PaymentService_'. $channel->business->config_section, 'dc_channel' );

    # These values are hard coded in Test::XTracker::Mock::PSP->getinfo_saved_card.
    my $expiry_month = '12';
    my $expiry_year  = '16';
    my $card_number  = '4508751100000006';

    cmp_ok( $self->{mock_psp}->all_method_calls, '==', 3, 'Two Domain::Payment methods where called' );

    # Test the call to 'init_with_payment_session'.
    cmp_deeply( $self->{mock_psp}->next_method_call, {
        method    => 'init_with_payment_session',
        arguments => [ {
            address1            => $address->address_line_1,
            address2            => $address->address_line_2,
            address3            => $address->towncity,
            billingCountry      => $address->country_table->code,
            channel             => $merchant_channel,
            coinAmount          => $pre_order->total_value * 100,
            currency            => $pre_order->currency->currency,
            distributionCentre  => $dc_channel,
            email               => $customer->email,
            firstName           => $address->first_name,
            isPreOrder          => 0,
            lastName            => $address->last_name,
            merchantUrl         => $merchant_url,
            paymentMethod       => 'CREDITCARD',
            paymentSessionId    => $self->{payment_session_id},
            postcode            => $address->postcode,
            title               => $customer->title,
        } ],
    }, 'The parameters passed to init_with_payment_session where as expected' );

    # Test the call to 'preauth_with_payment_session'.
    cmp_deeply( $self->{mock_psp}->next_method_call, {
        method    => 'preauth_with_payment_session',
        arguments => [ {
            orderNumber         => 'pre_order_' . $pre_order->id,
            paymentSessionId    => $self->{payment_session_id},
            # The reference value is not important, as it's mocked, just make
            # sure it's present.
            reference           => ignore(),
        } ],
    }, 'The parameters passed to preauth_with_payment_session where as expected' );

    # Test the call to 'settle_payment'.
    cmp_deeply( $self->{mock_psp}->next_method_call, {
        method    => 'settle_payment',
        arguments => [ {
            channel     => $dc_channel,
            coinAmount  => $pre_order->total_value * 100,
            currency    => $pre_order->currency->currency,
            # The reference value is not important, as it's mocked, just make
            # sure it's present.
            reference   => ignore(),
        } ],
    }, 'The parameters passed to settle_payment where as expected' );

}

sub run_tests_for_complete_preorder {
    my ($self, $args) = @_;

    my $coin_amount = delete $args->{coin_amount};
    my $pre_order   = $args->{pre_order};

    if ( $self->_new_object__process__lives_ok( $args ) ) {

        $pre_order->discard_changes();

        # Get a default coin amount.
        $coin_amount //= $pre_order->total_value * 100;

        isa_ok($pre_order->get_payment, 'XTracker::Schema::Result::Public::PreOrderPayment', 'Payment');

        note ref($pre_order->get_payment);

        ok($pre_order->get_payment->psp_ref, 'PSP ref found');
        ok($pre_order->get_payment->preauth_ref, 'Preauth ref found');
        ok($pre_order->get_payment->settle_ref, 'Settle ref found');

        # check what 'coinAmount' got to the PSP, which has the decimal place removed
        my $psp_init_data   = $self->{mock_psp}->get_init_with_payment_session_in;
        my $psp_settle_data = $self->{mock_psp}->get_settle_data_in;

        is( $psp_init_data->{coinAmount}, $coin_amount, "'init_with_payment_session' got the correct value in 'coinAmount'");
        is( $psp_settle_data->{coinAmount}, $coin_amount, "'settle_payment' got the correct value in 'coinAmount'");

        foreach my $item ($pre_order->pre_order_items) {
            ok($item->is_complete(), 'Item completed for customer');
            isnt($item->reservation_id, undef, 'Item has reservation id');
            cmp_ok($item->reservation->ordering_id, '==', 0, 'Ordering for reservation is zero');
        }

        ok($pre_order->is_complete(), 'Pre order is completed');
    }
}

sub run_tests_for_incomplete_preorder {
    my ($self, $args) = @_;

    $self->_new_object__process__dies_ok( $args );

    $args->{pre_order}->discard_changes();

    foreach my $item ($args->{pre_order}->pre_order_items) {
        ok($item->is_selected(), "Item status is 'selected'");
        is($item->reservation_id, undef, 'Item has no reservation id');
    }

    ok($args->{pre_order}->is_incomplete(), 'Pre order is still incomplete');

    ok(!$args->{pre_order}->pre_order_payment, 'Entry in the payment table has not been created');
}

sub run_tests_for_payment_declined_preorder {
    my ($self, $args) = @_;

    $self->_new_object__process__dies_ok( $args );

    $args->{pre_order}->discard_changes();

    foreach my $item ($args->{pre_order}->pre_order_items) {
        ok($item->is_selected(), "Item status is 'selected'");
        is($item->reservation_id, undef, 'Item has reservation id');
    }

    ok($self->{incomplete_pre_order}->is_payment_declined(), 'Payment Declined status for the Pre order because payment preauth failed');

    ok(!$args->{pre_order}->pre_order_payment, 'Entry in the payment table has not been created');
}

sub run_tests_for_settle_failed_preorder {
    my ($self, $args) = @_;

    $self->_new_object__process__dies_ok( $args );

    $args->{pre_order}->discard_changes();

    foreach my $item ($args->{pre_order}->pre_order_items) {
        ok($item->is_confirmed (), "Item status is 'confirmed'");
        isnt($item->reservation_id, undef, 'Item has reservation id');
    }

    ok($self->{incomplete_pre_order}->is_incomplete(), 'Payment Declined status for the Pre order because payment preauth failed');

    isa_ok($args->{pre_order}->pre_order_payment, 'XTracker::Schema::Result::Public::PreOrderPayment', 'Entry in the payment table has been created');
}

sub teardown :Test( teardown => no_plan ) {
    my ($self) = @_;

    $self->SUPER::teardown();

    $self->{schema}->txn_rollback;
}

sub _new_object_ok {
    my ($self,  $pre_order, $attributes ) = @_;

    $attributes //= {};

    return new_ok('XTracker::Stock::Reservation::PreOrderPaymentWS' => [
        domain_payment      => $self->{mock_psp},
        pre_order           => $pre_order,
        operator            => Test::XTracker::Data->get_application_operator,
        schema              => $self->{schema},
        payment_session_id  => $self->{payment_session_id},
        message_factory     => Test::XTracker::MessageQueue->new( {
            schema => $self->{schema},
        } ),
        %$attributes,
    ]);

}

sub _new_object__process__lives_ok {
    my ($self,  $arguments ) = @_;

    my $object = $self->_new_object_ok( $arguments->{pre_order}, $arguments->{object_attributes} );
    my $result = undef;

    lives_ok( sub { $result = $object->process },
        'lives ok' );

    return ok( $result,
        'Got a true result' );

}

sub _new_object__process__dies_ok {
    my ($self,  $arguments ) = @_;

    my $object = $self->_new_object_ok( $arguments->{pre_order}, $arguments->{object_attributes} );

    return throws_ok( sub { $object->process },
        qr/$arguments->{expected_error_message}/ );

}
