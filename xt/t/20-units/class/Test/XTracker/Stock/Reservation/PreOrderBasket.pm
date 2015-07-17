package Test::XTracker::Stock::Reservation::PreOrderBasket;

use NAP::policy "tt", qw( test );

use parent 'NAP::Test::Class';

=head1 NAME

Test::XTracker::Stock::Reservation::PreOrderBasket

=head1 DESCRIPTION

Test XTracker::Stock::Reservation::PreOrderBasket

=head1 TESTS

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::PreOrder;
use Test::XTracker::Mock::Handler;

use XTracker::Constants::FromDB         qw( :currency
                                            :pre_order_status
                                            :pre_order_item_status );
use XTracker::Constants::Reservations   qw( :reservation_messages
                                            :reservation_types
                                            :pre_order_packaging_types );
use XTracker::Constants::Payment        qw( :psp_channel_mapping
                                            :psp_return_codes
                                            :pre_order_payment_api_messages );
use XTracker::Database::Shipment        qw( get_address_shipping_charges );

use XTracker::Stock::Reservation::PreOrderBasket;

use Test::MockModule;


sub startup : Test(startup) {
    my ($self) = @_;

    $self->SUPER::startup;

    $self->{schema} = Test::XTracker::Data->get_schema();

    $self->{mock_designer_service} = Test::MockModule->new('XT::Service::Designer');
    $self->{mock_designer_service}->mock(
        get_restricted_countries_by_designer_id => sub {
            note '** In Mocked get_restricted_countries_by_designer_id **';
            # Return an empty country list.
            return [];
        }
    );
}

sub setup : Tests() {
    my $self = shift;

    $self->SUPER::setup;
}

sub teardown :Test(teardown) {
    my ($self) = @_;

    $self->SUPER::teardown();
}

sub shut_down : Test(shutdown) {
    my $self = shift;
    $self->SUPER::shutdown();

    # just make sure the Mock doesn't interfere with other tests
    $self->{mock_designer_service}->unmock_all();
    delete $self->{mock_designer_service};
}

=head2 test_pre_order_with_no_params

Call PerOrderBasket with no parameters

=cut

sub test_basket_with_no_params : Tests() {
    my ($self) = @_;

    my $mock_handler = Test::XTracker::Mock::Handler->new({
        param_of => {}
    });

    my $basket = new_ok('XTracker::Stock::Reservation::PreOrderBasket' => [$mock_handler]);
    $basket->process();

}

=head2 test_pre_order_with_no_params

Call PreOrderBasket with ID for incomplete Pre Order

=cut

sub test_basket_for_incomplete_pre_order_id : Tests() {
    my ($self) = @_;

    my $pre_order = Test::XTracker::Data::PreOrder->create_incomplete_pre_order();

    my $mock_handler = Test::XTracker::Mock::Handler->new({
        param_of => {
            pre_order_id => $pre_order->id,
        }
    });

    my $basket = new_ok('XTracker::Stock::Reservation::PreOrderBasket' => [$mock_handler]);
    $basket->process();

    my $data = $mock_handler->{data};

    isa_ok($data->{customer}, 'XTracker::Schema::Result::Public::Customer', 'Customer DBIx object found');
    isa_ok($data->{shipment_address}, 'XTracker::Schema::Result::Public::OrderAddress', 'Shipment Addrss object');
    isa_ok($data->{invoice_address}, 'XTracker::Schema::Result::Public::OrderAddress', 'Invoice Address DBIx objec');

    cmp_ok(keys(%{$data->{variants}}), '==', $pre_order->pre_order_items->count, 'Correct number of Pre Order Items found');

    foreach my $item ($pre_order->pre_order_items) {
        ok(exists($data->{variants}{$item->variant_id}), 'Item found');
    }

}

=head2 test_pre_order_with_payment_already

Call PreOrderBasket when a Pre-Order has already got a Pre-Order Payment Record assigned.

=cut

sub test_pre_order_with_payment_already : Tests() {
    my $self    = shift;

    my $redirect_url    = "";

    my $pre_order       = Test::XTracker::Data::PreOrder->create_incomplete_pre_order();
    my $pre_order_id    = $pre_order->id;

    # get a list of Pre-Order Item Ids to compare with later
    my @expected_ids    = map { $_->id } sort { $a->id <=> $b->id } $pre_order->pre_order_items->all;

    my $mock_handler    = Test::XTracker::Mock::Handler->new({
                param_of => {
                    pre_order_id => $pre_order->id,
                },
                mock_methods => {
                    redirect_to => sub {
                            my ( $handler, $url )   = @_;
                            $redirect_url   = $url;
                            return 'REDIRECTED';
                        },
                },
            });

    # assign a payment to the Pre-Order
    my $psp_refs    = Test::XTracker::Data->get_new_psp_refs();
    $pre_order->create_related( 'pre_order_payment', {
                                        preauth_ref => $psp_refs->{preauth_ref},
                                        psp_ref     => $psp_refs->{psp_ref},
                                    } );

    my $basket  = new_ok( 'XTracker::Stock::Reservation::PreOrderBasket' => [ $mock_handler ] );
    my $result  = $basket->process();

    is( $result, 'REDIRECTED', "Basket Returned Re-Directed" );
    like( $redirect_url, qr{/StockControl/Reservation/PreOrder/Payment\?pre_order_id=$pre_order_id},
                        "Re-Directed to the correct URL" );

    # get a list of Pre-Order Item Ids to compare with
    my @got_ids = map { $_->id } sort { $a->id <=> $b->id } $pre_order->discard_changes->pre_order_items->all;
    is_deeply( \@got_ids, \@expected_ids, "Pre-Order Item Ids have NOT been changed" );

    return;
}

=head2 test_shipping_options_for_pre_order

Call PreOrderBasket to test that Shipping Options are being set properly for a New Pre-Order and an
incomplete Pre-Order.

=cut

sub test_shipping_options_for_pre_order : Tests() {
    my ($self) = @_;

    $self->{schema}->txn_begin;

    # create a Pre-Order so we can use its Address, Products etc.
    my $data_source = Test::XTracker::Data::PreOrder->create_incomplete_pre_order();
    my $address     = Test::XTracker::Data->create_order_address_in('current_dc');
    my @variants    = map { $_->variant } $data_source->pre_order_items->all;
    my @products    = map { $_->product } @variants;

    # create some shipping options to be used when creating the new Pre-Order
    my $shipping_options    = $self->_create_shipping_options( $data_source, $address );

    my $expected_shipping_options   = $self->_get_shipping_options_for_pre_order( $data_source, $address );

    note "Create a brand new Pre-Order using the Basket page";
    my $mock_handler = $self->_build_mock_handler( 'new', $data_source, $address, \@variants );

    my $basket  = new_ok( 'XTracker::Stock::Reservation::PreOrderBasket' => [ $mock_handler ] );
    $basket->process();

    # get the 'data' hash populated in the handler
    my $data        = $mock_handler->{data};
    my $pre_order   = $data->{pre_order}->discard_changes;
    isa_ok( $pre_order, 'XTracker::Schema::Result::Public::PreOrder', "Pre-Order created" );
    cmp_ok( $pre_order->pre_order_items->count, '==', @variants, "and has the correct number of Items" );
    is_deeply(
        { map { $_->{id} => $_->{sku} } @{ $data->{shipment_options} } },
        { map { $_->{id} => $_->{sku} } values %{ $expected_shipping_options } },
        "Shipment Options presented to the user are as expected"
    );
    my $pre_order_id= $pre_order->id;

    # check shipping option is there and valid
    ok( defined $pre_order->shipping_charge_id, "Shipping Charge Found" );
    ok( exists( $expected_shipping_options->{ $pre_order->shipping_charge_id } ),
                                "and Charge is a Valid one" );

    # now simulate changing the Shipping Option on the 2nd page, pick
    # one of the new ones created because we can safely play with those
    my ( $new_charge )  = grep { $_->id != $pre_order->shipping_charge_id }     # don't want the one we've already got
                                values %{ $shipping_options->{new} };
    $pre_order->update( { shipping_charge_id => $new_charge->id } );

    note "Simulate having gone back to the Basket page to remove a Variant and re-submit, after having changed the Shipping Charge";
    my @new_variants    = @variants;
    shift @new_variants;    # drop one of the variants
    $mock_handler   = $self->_build_mock_handler( 'existing', $pre_order, $address, \@new_variants );

    $basket = new_ok( 'XTracker::Stock::Reservation::PreOrderBasket' => [ $mock_handler ] );
    $basket->process();

    $data       = $mock_handler->{data};
    $pre_order  = $data->{pre_order}->discard_changes;
    cmp_ok( $pre_order->id, '==', $pre_order_id, "Pre-Order returned still the same Pre-Order as before" );
    cmp_ok( $pre_order->pre_order_items->count, '==', @new_variants, "and has the correct number of Items" );
    cmp_ok( $pre_order->shipping_charge_id, '==', $new_charge->id, "and the Shipping Charge is what it was changed to" );
    is_deeply(
        { map { $_->{id} => $_->{sku} } @{ $data->{shipment_options} } },
        { map { $_->{id} => $_->{sku} } values %{ $expected_shipping_options } },
        "Shipment Options presented to the user are as expected"
    );

    note "Remove the Pre-Order's Shipping Charge from being available, should choose another one when re-submitting the Basket page";
    $new_charge->country_shipping_charges->delete;
    delete $expected_shipping_options->{ $new_charge->id };

    $mock_handler   = $self->_build_mock_handler( 'existing', $pre_order, $address, \@variants );

    $basket = new_ok( 'XTracker::Stock::Reservation::PreOrderBasket' => [ $mock_handler ] );
    $basket->process();

    $data       = $mock_handler->{data};
    $pre_order  = $data->{pre_order}->discard_changes;
    cmp_ok( $pre_order->id, '==', $pre_order_id, "Pre-Order returned still the same Pre-Order as before" );
    cmp_ok( $pre_order->pre_order_items->count, '==', @variants, "and has the correct number of Items" );
    ok( defined $pre_order->shipping_charge_id, "There is a Shipping Charge on the record" );
    cmp_ok( $pre_order->shipping_charge_id, '!=', $new_charge->id, "and it's different from the previous charge" );
    ok( exists( $expected_shipping_options->{ $pre_order->shipping_charge_id } ), "but it is still a Valid charge" );
    is_deeply(
        { map { $_->{id} => $_->{sku} } @{ $data->{shipment_options} } },
        { map { $_->{id} => $_->{sku} } values %{ $expected_shipping_options } },
        "Shipment Options presented to the user are as expected"
    );

    $self->{schema}->txn_rollback;
}


=head2 test_can_not_continue_with_pre_order_with_live_product

This tests that a Pre-Order can't be continued if at least one of
the Products Pre-Ordered as subsequently become Live.

=cut

sub test_can_not_continue_with_pre_order_with_live_product : Tests() {
    my $self = shift;

    # create new Customer & Products
    my $customer   = Test::XTracker::Data->create_dbic_customer( {
        channel_id => Test::XTracker::Data->channel_for_nap()->id,
    } );
    my $products   = Test::XTracker::Data::PreOrder->create_pre_orderable_products();
    my @prod_chann = map { $_->product_channel } @{ $products };

    # create an Incomplete Pre-Order
    my $pre_order = Test::XTracker::Data::PreOrder->create_incomplete_pre_order( {
        customer => $customer,
        products => $products,
    } );
    my $pre_order_id = $pre_order->id;

    my $redirect_url = '';

    # create a mock handler with just the Pre-Order Id in it to simulate the
    # click on the 'continue' link from the Pre-Order Search results page
    require XTracker::Session;
    $XTracker::Session::SESSION = {};       # make sure the Session has something in it
    my $mock_handler = Test::XTracker::Mock::Handler->new( {
        param_of => {
            pre_order_id => $pre_order_id,
        },
        mock_methods => {
            redirect_to => sub {
                    my ( $handler, $url )   = @_;
                    $redirect_url = $url;
                    return 'REDIRECTED';
                },
        },
        session => XTracker::Session->session(),
    } );
    my $basket = new_ok( 'XTracker::Stock::Reservation::PreOrderBasket' => [ $mock_handler ] );

    # set one of the Products to be Live
    $prod_chann[0]->discard_changes->update( { live => 1 } );

    # simulate calling the page
    my $result = $basket->process();

    is( $result, 'REDIRECTED', "Basket Returned Re-Directed" );
    like( $redirect_url, qr{SelectProducts\?.*pre_order_id=$pre_order_id.*variants=\d+},
                        "Re-Directed to the correct URL" );

    my $expected_warn_message = sprintf( $RESERVATION_MESSAGE__UNABLE_TO_PRE_ORDER_SKUS, '' );
    like(
        $mock_handler->{session}{xt_error}{message}{WARN},
        qr/\Q${expected_warn_message}\E/i,
        "The Expected Warning Message was set in the Session"
    );


    # clear the Session so other tests aren't effected
    $XTracker::Session::SESSION = undef;
}


#---------------------------------------------------------------------------

sub _get_shipping_options_for_pre_order {
    my ( $self, $pre_order, $address, $always_keep_sku )    = @_;

    my %options = get_address_shipping_charges(
        $self->{schema}->storage->dbh,
        $pre_order->customer->channel_id,
        {
            country  => $address->country,
            postcode => $address->postcode,
            state    => $address->county,
        },
        {
            exclude_nominated_day   => 0,
            always_keep_sku         => $always_keep_sku // '',
            customer_facing_only    => 1,
            exclude_for_shipping_attributes => $pre_order->get_item_shipping_attributes,
        }
    );

    return \%options;
}

sub _create_shipping_options {
    my ( $self, $pre_order, $address )  = @_;

    # get current options
    my $orig_options    = $self->_get_shipping_options_for_pre_order( $pre_order, $address );
    my ( $an_option )   = values( %{ $orig_options } );

    # get the original Charges records
    my $shipping_charge_rs  = $self->{schema}->resultset('Public::ShippingCharge');
    my %orig_options_obj    = map { $_ => $shipping_charge_rs->find( $_ ) }
                                    keys %{ $orig_options };


    my $channel = $pre_order->channel;
    # now create some extras based on the one we found
    my %new_options_obj;
    foreach my $counter ( 1..2 ) {
        my $charge  = $channel->create_related( 'shipping_charges', {
            sku         => sprintf( 'MADE_UP_SKU-%03d', $counter ),
            description => "Made up SKU ${counter}",
            charge      => 10.50 * $counter,
            currency_id => $pre_order->currency_id,
            class_id    => $an_option->{class_id},
        } );

        # now assign it to the Pre-Order's Country
        $address->country_ignore_case->create_related( 'country_shipping_charges', {
            shipping_charge_id  => $charge->id,
            channel_id          => $channel->id,
        } );

        $new_options_obj{ $charge->id } = $charge->discard_changes;
    }

    return {
        orig    => \%orig_options_obj,
        new     => \%new_options_obj,
    };
}

sub _build_mock_handler {
    my ( $self, $type, $pre_order, $address, $variants )    = @_;

    return Test::XTracker::Mock::Handler->new( {
        param_of => {
            (
                $type eq 'new'
                ? ( customer_id => $pre_order->customer_id )
                : ( pre_order_id => $pre_order->id )
            ),
            variants                => [ map { $_->id } @{ $variants } ],
            currency_id             => $pre_order->currency_id,
            reservation_source_id   => $pre_order->reservation_source_id,
            reservation_type_id     => $pre_order->reservation_type_id,
            shipment_address_id     => $address->id,
            invoice_address_id      => $address->id,
        },
        mock_methods => {
            process_template => sub { return 1; },
        },
    } );
}
