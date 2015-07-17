package Test::NAP::CustomerCare::PreOrder;

use NAP::policy 'tt', 'test';
use parent 'NAP::Test::Class';

=head1 NAME

Test::NAP::CustomerCare::PreOrder - Test the Pre-Order process

=head1 DESCRIPTION

Test the Pre-Order processes.

#TAGS preorder

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::PreOrder;
use Test::XT::Flow;

use XTracker::Config::Local         qw( config_var );
use XTracker::Utilities             qw( format_currency_2dp apply_discount );
use XTracker::Database::Pricing     qw( get_product_selling_price );

use XTracker::Constants             qw( :application );
use XTracker::Constants::FromDB     qw(
                                        :authorisation_level
                                        :customer_category
                                    );


sub startup : Test( startup => no_plan ) {
    my $self    = shift;

    $self->SUPER::startup;

    $self->{channel}    = Test::XTracker::Data->channel_for_nap;

    $self->{dc_currency}= $self->rs('Public::Currency')->find( {
        currency => config_var( 'Currency', 'local_currency_code' ),
    } );

    $self->{framework}  = Test::XT::Flow->new_with_traits( {
        traits  => [
            'Test::XT::Flow::CustomerCare',
            'Test::XT::Flow::Reservations',
        ],
    } );

    $self->framework->login_with_permissions( {
        perms => {
            $AUTHORISATION_LEVEL__MANAGER => [
                'Stock Control/Reservation',
                'Customer Care/Customer Search',
                'Customer Care/Order Search',
            ],
        },
        dept => 'Personal Shopping',
    } );
    $self->{operator} = $self->mech->logged_in_as_object;

    # get another Operator
    $self->{another_operator} = $self->rs('Public::Operator')
                                        ->search( {
        id => { 'NOT IN' => [ $APPLICATION_OPERATOR_ID, $self->{operator}->id ] },
    } )->first;

    # get all Reservation Sources so one can be used when creating a Pre-Order
    $self->{sources} = [
        $self->rs('Public::ReservationSource')->search({is_active => 'true'})->all,
    ];

    $self->{types} = [
        $self->rs('Public::ReservationType')->all,
    ];

    # create a Shipping Address that can be used for
    # Pre-Orders Customers who've never placed an Order
    $self->{shipping_address} = Test::XTracker::Data->create_order_address_in('current_dc');
}

sub shutdown : Test( shutdown => no_plan ) {
    my $self    = shift;

    $self->SUPER::shutdown;
}

sub setup : Test( setup => no_plan ) {
    my $self    = shift;

    $self->SUPER::setup;

    $self->{products} = Test::XTracker::Data::PreOrder->create_pre_orderable_products();

    $self->{customer} = Test::XTracker::Data->create_dbic_customer( {
        channel_id => $self->{channel}->id,
    } );

    $self->{max_pre_order_id} = $self->rs('Public::PreOrder')
                                        ->get_column('id')->max // 0;

    Test::XTracker::Data->save_config_group_state('PreOrder');
    Test::XTracker::Data->save_config_group_state('PreOrderDiscountCategory');
}

sub teardown : Test( teardown => no_plan ) {
    my $self    = shift;

    $self->SUPER::teardown;

    Test::XTracker::Data->restore_config_group_state('PreOrderDiscountCategory');
    Test::XTracker::Data->restore_config_group_state('PreOrder');
}


=head1 TESTS

=head2 test_discount_drop_down

Tests the Discount Drop-Down is populated correctly.

=cut

sub test_discount_drop_down : Tests {
    my $self = shift;

    my $customer = $self->{customer};
    my $products = $self->{products};
    my $address  = $self->{shipping_address};

    my %tests = (
        "Shouldn't see Drop-Down with 'can_apply_discount' flag set to FALSE" => {
            setup => {
                can_apply_discount => 0,
            },
            expect => {
                see_drop_down => 0,
            },
        },
        "Should see Drop-Down with 'can_apply_discount' flag set to TRUE" => {
            setup => {
                can_apply_discount => 1,
                max_discount       => 30,
                discount_increment => 5,
                categories => undef,
            },
            expect => {
                see_drop_down   => 1,
                first_option    => 0,
                last_option     => 30,
                increment       => 5,
                selected_option => 0,
            },
        },
        "Check for 'default' option when Customer has a Discount" => {
            setup => {
                use_category_for_customer => $CUSTOMER_CATEGORY__EIP,
                can_apply_discount => 1,
                max_discount       => 20,
                discount_increment => 5,
                categories => [
                    [ $CUSTOMER_CATEGORY__EIP, 10 ],
                ],
            },
            expect => {
                see_drop_down   => 1,
                first_option    => 0,
                last_option     => 20,
                increment       => 5,
                selected_option => 10,
                default_option  => 10,
            },
        },
        "Check 'default' option is NOT shown when Customer has a ZERO Discount" => {
            setup => {
                use_category_for_customer => $CUSTOMER_CATEGORY__EIP,
                can_apply_discount => 1,
                max_discount       => 20,
                discount_increment => 5,
                categories => [
                    [ $CUSTOMER_CATEGORY__EIP, 0 ],
                ],
            },
            expect => {
                see_drop_down   => 1,
                first_option    => 0,
                last_option     => 20,
                increment       => 5,
                selected_option => 0,
                default_option  => undef,
            },
        },
    );

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";

        my $test   = $tests{ $label };
        my $setup  = $test->{setup};
        my $expect = $test->{expect};

        $customer->discard_changes->update( {
            category_id => delete $setup->{use_category_for_customer} // $CUSTOMER_CATEGORY__NONE,
        } );

        my $categories = delete $setup->{categories};
        my %category_setup;
        foreach my $category_option ( @{ $categories } ) {
            my ( $category_id, $discount_amount ) = @{ $category_option };
            my $category = $self->rs('Public::CustomerCategory')->find( $category_id );
            $category_setup{ $category->category } = $discount_amount;
        }

        Test::XTracker::Data->set_pre_order_discount_settings( $self->{channel}, {
            %{ $setup },
            set_category => \%category_setup,
        } );

        $self->framework->flow_mech__preorder__select_products( {
            customer_id             => $customer->id,
            shipment_address_id     => $address->id,
            skip_pws_customer_check => 1,
        } );

        my $pg_data = $self->pg_data()->{product_search_box};
        my $discount_dd = $pg_data->{'Select Discount'};
        $self->_check_discount_drop_down( $discount_dd, {
            drop_down_shown => $expect->{see_drop_down},
            %{ $expect },
        } );
    }
}

=head2 test_applying_discount_on_product_select_page

Tests that the Discount gets Applied when using it on the Product
Selection page (or the First page in placing a Pre-Order).

=cut

sub test_applying_discount_on_product_select_page : Tests() {
    my $self = shift;

    my $customer = $self->{customer};
    my $products = $self->{products};
    my $address  = $self->{shipping_address};

    # set the Discount Percentage to use
    my $discount_to_use = 15;

    my @product_ids = map { $_->id } @{ $products };
    # set the Expected Discounted Product prices
    my $expect_product_price = $self->_set_products_price( {
            customer    => $customer,
            address     => $address,
            products    => $products,
            start_price => 100,
            discount_to_use => $discount_to_use,
        } )->{products};

    my %tests = (
        "With ZERO Discount Chosen no Discount Prices Shown" => {
            setup => {
                choose_discount => 0,
            },
            expect => {
                discount_prices_shown => 0,
                discount_on_pre_order_rec => 0,
                discount_operator_id => $self->{operator}->id,
            },
        },
        "With ${discount_to_use}% Discount Chosen, Discount Prices are Shown" => {
            setup => {
                choose_discount => $discount_to_use,
            },
            expect => {
                discount_prices_shown => 1,
                discount_on_pre_order_rec => $discount_to_use,
                discount_operator_id => $self->{operator}->id,
            },
        },
        "With Discount Option Turned Off, no Discount Prices Shown" => {
            setup => {
                turn_on_discount => 0,
            },
            expect => {
                discount_prices_shown => 0,
                discount_on_pre_order_rec => 0,
                discount_operator_id => undef,
            }
        },
    );

    my $pre_order_rs     = $self->rs('Public::PreOrder');
    my $max_pre_order_id = $self->{max_pre_order_id};

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test    = $tests{ $label };
        my $setup   = $test->{setup};
        my $expect  = $test->{expect};

        # default to Discount being turned On
        my $turn_on_discount = $setup->{turn_on_discount} // 1;

        Test::XTracker::Data->set_pre_order_discount_settings( $self->{channel}, {
            can_apply_discount => $turn_on_discount,
            max_discount       => 30,
            discount_increment => 5,
        } );

        $self->framework->flow_mech__preorder__select_products( {
                customer_id             => $customer->id,
                shipment_address_id     => $address->id,
                invoice_address_id      => $address->id,
                skip_pws_customer_check => 1,
            } )
                ->flow_mech__preorder__select_products_submit( {
                    (
                        $turn_on_discount
                        ? ( discount_percentage => $setup->{choose_discount} )
                        : ()
                    ),
                    currency_id         => $self->{dc_currency}->id,
                    pids                => join( ' ', @product_ids ),
                } );

        # get at least one Variant per Product
        # which can be submitted to be Pre-Ordered
        my @variants_to_use;
        my %select_hash;

        my %got_prices;
        my %got_discount_prices;
        my %expect_prices;
        my %expect_discount_prices;

        my $expect_pre_order_item_prices;
        my $expect_pre_order_item_original_prices;

        my $pg_data = $self->pg_data()->{product_list};
        foreach my $pid ( @product_ids ) {
            my $product_data = $pg_data->{ $pid };
            ok( defined $product_data, "Found details for PID: ${pid}" );

            my $got_price          = $product_data->{price};
            my $got_discount_price = $product_data->{discount_price};

            $got_prices{ $pid } = {
                total => $got_price->{total_price},
                %{ $got_price->{price_parts} },
            };
            $expect_prices{ $pid } = $expect_product_price->{ $pid }{price};

            # check Original Prices Shown
            ok( defined $got_price, "Original Price shown for PID: ${pid}" );

            if ( $expect->{discount_prices_shown} ) {
                # check Discounted Price
                ok( $got_discount_price, "Discount Price Shown for PID: ${pid}" );
                $got_discount_prices{ $pid } = {
                    total => $got_discount_price->{total_price},
                    %{ $got_discount_price->{price_parts} },
                };
                $expect_discount_prices{ $pid } = $expect_product_price->{ $pid }{discount_price};
            }
            else {
                ok( !$got_discount_price, "No Discount Price Shown" )
                                or diag "FAIL: Discount Price was Shown: " . p( $got_discount_price );
            }

            # get a Variant to use & setup the prices that
            # should appear on the Pre-Order Item record
            my ( $product ) = grep { $_->id eq $pid } @{ $products };
            my $variant     = $product->variants->first;
            $expect_pre_order_item_prices->{ $variant->id } = {
                (
                    $expect->{discount_prices_shown}
                    ? %{ $got_discount_price->{price_parts} }
                    : %{ $got_price->{price_parts} }
                )
            };
            $expect_pre_order_item_original_prices->{ $variant->id } = $got_price->{price_parts};
            push @variants_to_use, $variant;
            $select_hash{ "#quantity_".$variant->sku} = $variant->id."_1";
        }

        cmp_deeply( \%got_prices, \%expect_prices, "Product Prices as Expected on page" )
                                    or diag "ERROR - Product Prices: Got: " . p( %got_prices ) .
                                                             ", Expected: " . p( %expect_prices );
        cmp_deeply( \%got_discount_prices, \%expect_discount_prices, "Product Discount Prices as Expected on page" )
                                    or diag "ERROR - Product Discount Prices: Got: " . p( %got_discount_prices ) .
                                                                   ", Expected: " . p( %expect_discount_prices );

        $self->framework->flow_mech__preorder__select_products__submit_skus_submit( {
            reservation_source_id => $self->{sources}[0]->id,
            reservation_type_id => $self->{types}[0]->id,
           %select_hash
        });

        # check the Discount has been applied to the actual Pre-Order
        my $pre_order = $pre_order_rs->search( { id => { '>' => $max_pre_order_id } } )->first;
        isa_ok( $pre_order, 'XTracker::Schema::Result::Public::PreOrder', "got a new Pre-Order record" );
        $max_pre_order_id = $pre_order->id;

        cmp_ok( $pre_order->applied_discount_percent, '==', $expect->{discount_on_pre_order_rec},
                                "Correct Discount Percentage appears on the Pre-Order record" );
        if ( defined $expect->{discount_operator_id} ) {
            cmp_ok( $pre_order->applied_discount_operator_id, '==', $expect->{discount_operator_id},
                                "and the Discount Operator Id has been set as Expected" );
        }
        else {
            ok( !defined $pre_order->applied_discount_operator_id, "No Discount Operator Id has been set" );
        }

        # check prices on the Pre-Order Items
        my %got_items = map {
            $_->variant_id => {
                unit_price => format_currency_2dp( $_->unit_price ),
                tax        => format_currency_2dp( $_->tax ),
                duty       => format_currency_2dp( $_->duty ),
            },
        } $pre_order->pre_order_items->all;
        cmp_deeply( \%got_items, $expect_pre_order_item_prices, "and Pre-Order Item Prices as Expected" );

        # check original prices on the Pre-Order Items
        %got_items = map {
            $_->variant_id => {
                unit_price => format_currency_2dp( $_->original_unit_price ),
                tax        => format_currency_2dp( $_->original_tax ),
                duty       => format_currency_2dp( $_->original_duty ),
            },
        } $pre_order->pre_order_items->all;
        cmp_deeply( \%got_items, $expect_pre_order_item_original_prices, "and Pre-Order Item Original Prices as Expected" );
    }
}

=head2 test_discount_on_basket_page

This tests that the Discount selected on the Select Products page is shown correctly on the Basket
page.

=cut

sub test_discount_on_basket_page :Tests() {
    my $self = shift;

    my $customer = $self->{customer};
    my $products = $self->{products};
    my $address  = $self->{shipping_address};

    my @product_ids     = map { $_->id } @{ $products };
    my @variants_to_use = map { $_->variants->first } @{ $products };

    # set the Product Price and get back the Expected Discounted Prices
    my $price_set = $self->_set_products_price( {
        customer    => $customer,
        address     => $address,
        products    => $products,
        start_price => 100,
        discount_to_use => 15,
    } );

    my %tests = (
        "Test Basket page without any Discount Applied" => {
            setup => {
                choose_discount => 0,
                change_discount => {
                    on_select_products_page => 10,
                    on_basket_page          => 5,
                },
            },
            expect => {
                price_key => 'price',
            },
        },
        "Test Basket page with Discount Ability Turned Off" => {
            setup => {
                turn_on_discount => 0,
            },
            expect => {
                price_key => 'price',
            },
        },
        "Test Basket page with 15% Applied" => {
            setup => {
                choose_discount => 15,
                change_discount => {
                    on_select_products_page => 10,
                    on_basket_page          => 5,
                },
            },
            expect => {
                price_key => 'discount_price',
            },
        },
        "Test Basket page with Discount Ability Turned Off, but set with initial Discount of 15%" => {
            setup => {
                turn_on_discount => 0,
                choose_discount  => 15,
            },
            expect => {
                price_key => 'price',
                discount_applied => 0,
            },
        },
    );
    # common arguments for the Create Pre-Order method
    my %common_pre_order_args = (
        channel             => $self->{channel},
        customer            => $customer,
        shipment_address    => $address,
        variants            => \@variants_to_use,
    );

    TEST:
    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test   = $tests{ $label };
        my $setup  = $test->{setup};
        my $expect = $test->{expect};

        # default to Discount being turned On
        my $turn_on_discount = $setup->{turn_on_discount} // 1;

        Test::XTracker::Data->set_pre_order_discount_settings( $self->{channel}, {
            can_apply_discount => $turn_on_discount,
            max_discount       => 30,
            discount_increment => 5,
        } );

        my $price_to_use    = ( $setup->{choose_discount} ? 'discount_price' : 'price' );
        my $discount_to_use = $setup->{choose_discount} // 0;
        $expect->{discount_applied} //= $discount_to_use;

        $self->_set_discount_price( $price_set, $customer, $address, $discount_to_use );
        my $pre_order = Test::XTracker::Data::PreOrder->create_incomplete_pre_order( {
            %common_pre_order_args,
            discount_percentage => $discount_to_use,
            discount_operator   => ( $turn_on_discount ? $self->{operator} : undef ),
            item_product_prices => {
                map { $_ => $price_set->{products}{ $_ }{ $price_to_use } }
                    keys %{ $price_set->{products} },
            },
        } );

        $self->framework->flow_mech__preorder__basket( $pre_order->id );

        $self->_check_discount_drop_down( $self->pg_data()->{pre_order_discount_drop_down}, {
            drop_down_shown     => $turn_on_discount,
            only_check_selected => 1,
            selected_option     => $expect->{discount_applied},
        } );
        $self->_check_discount_column( 'pre_order_items', $turn_on_discount, $discount_to_use );
        $self->_check_basket_items( $price_set, $expect->{price_key}, \@variants_to_use );
        $self->_check_totals( $price_set->{total}, $expect->{price_key}, $expect->{discount_applied} );
        $self->_check_pre_order_rec_totals( $pre_order, $price_set->{total}, $expect->{price_key} );

        $self->framework->flow_mech__preorder__basket__edit_items();
        my $pg_data = $self->pg_data();
        $self->_check_discount_drop_down( $pg_data->{product_search_box}{'Select Discount'}, {
            drop_down_shown     => $turn_on_discount,
            only_check_selected => 1,
            selected_option     => $expect->{discount_applied},
        } );

        next TEST       unless ( $setup->{change_discount} );

        note "from the Product Select page choose a different Discount and flow through to the Basket page";
        $discount_to_use = $setup->{change_discount}{on_select_products_page};
        $self->_set_discount_price( $price_set, $customer, $address, $discount_to_use );

        my %select_hash = map { "#quantity_".$_->sku  =>  $_->id."_1" } @variants_to_use;
        $self->framework->flow_mech__preorder__select_products_submit( {
            with_discount_if_on => $discount_to_use,
            pids                => join( ' ', @product_ids ),
        } )
            ->flow_mech__preorder__select_products__submit_skus_submit(
                { %select_hash }
            );

        $self->_check_discount_column( 'pre_order_items', $turn_on_discount, $discount_to_use );
        $self->_check_basket_items( $price_set, 'discount_price', \@variants_to_use );
        $self->_check_totals( $price_set->{total}, 'discount_price', $discount_to_use );
        $self->_check_pre_order_rec_totals( $pre_order, $price_set->{total}, 'discount_price' );

        note "change the Discount from the Basket page";
        $discount_to_use = $setup->{change_discount}{on_basket_page};
        $self->_set_discount_price( $price_set, $customer, $address, $discount_to_use );

        $self->framework->flow_mech__preorder__basket__change_discount( $discount_to_use );

        $self->_check_discount_column( 'pre_order_items', $turn_on_discount, $discount_to_use );
        $self->_check_basket_items( $price_set, 'discount_price', \@variants_to_use );
        $self->_check_totals( $price_set->{total}, 'discount_price', $discount_to_use );
        $self->_check_pre_order_rec_totals( $pre_order, $price_set->{total}, 'discount_price' );
    }
}

=head2 test_discount_on_payment_page

Tests that the Discount is shown on the Pre-Order payment page.

=cut

sub test_discount_on_payment_page : Tests {
    my $self = shift;

    my $customer = $self->{customer};
    my $products = $self->{products};
    my $address  = $self->{shipping_address};

    my @product_ids     = map { $_->id } @{ $products };
    my @variants_to_use = map { $_->variants->first } @{ $products };

    my $discount_to_use = 15;

    # set the Product Price and get back the Expected Discounted Prices
    my $price_set = $self->_set_products_price( {
        customer    => $customer,
        address     => $address,
        products    => $products,
        start_price => 100,
        discount_to_use => $discount_to_use,
    } );

    my %tests = (
        "With Discount Functionality Turned Off" => {
            setup => {
                turn_on_discount => 0,
            },
            expect => {
                discount_messages => 0,
            },
        },
        "With Discount Set as ${discount_to_use}%" => {
            setup => {
                discount_to_use => $discount_to_use,
            },
            expect => {
                discount_applied_message => 1,
            },
        },
        "With Discount Set at ZERO" => {
            setup => {
                discount_to_use => 0,
            },
            expect => {
                zero_discount_message => 1,
            },
        },
    );

    # common arguments for the Create Pre-Order method
    my %common_pre_order_args = (
        channel             => $self->{channel},
        customer            => $customer,
        shipment_address    => $address,
        variants            => \@variants_to_use,
    );

    foreach my $label ( keys %tests ) {
        note "Testing: $label";
        my $test    = $tests{ $label };
        my $setup   = $test->{setup};
        my $expect  = $test->{expect};

        # default to Discount being turned On
        my $turn_on_discount = $setup->{turn_on_discount} // 1;
        $expect->{discount_messages} //= 1;

        Test::XTracker::Data->set_pre_order_discount_settings( $self->{channel}, {
            can_apply_discount => $turn_on_discount,
            max_discount       => 30,
            discount_increment => 5,
        } );

        my $price_to_use    = ( $setup->{discount_to_use} ? 'discount_price' : 'price' );
        my $discount_to_use = $setup->{discount_to_use} // 0;

        $self->_set_discount_price( $price_set, $customer, $address, $discount_to_use );
        my $pre_order = Test::XTracker::Data::PreOrder->create_incomplete_pre_order( {
            %common_pre_order_args,
            discount_percentage => $discount_to_use,
            discount_operator   => ( $turn_on_discount ? $self->{operator} : undef ),
            item_product_prices => {
                map { $_ => $price_set->{products}{ $_ }{ $price_to_use } }
                    keys %{ $price_set->{products} },
            },
        } );

        $self->framework->flow_mech__preorder__basket( $pre_order->id )
                        ->flow_mech__preorder__basket__payment;
        my $pg_data = $self->pg_data();

        my $expect_total = $price_set->{total}{ $price_to_use };
        like( $pg_data->{payment_total}, qr/${expect_total}/, "Total Payment Due as Expected" );

        if ( $expect->{discount_messages} ) {
            like( $pg_data->{payment_total_discount}, qr/includes.*${discount_to_use}[.0-9]*\%/i,
                            "got 'Includes Discount' message" )     if ( $expect->{discount_applied_message} );
            ok( !$pg_data->{payment_total_discount}, "didn't get 'Includes Discount' message" )
                                                    if ( !$expect->{discount_applied_message} );

            like( $pg_data->{payment_total_zero_discount}, qr/no discount/i,
                            "got 'No Discount' message" )           if ( $expect->{zero_discount_message} );
            ok( !$pg_data->{payment_total_zero_discount}, "didn't get 'no Discount' message" )
                                                    if ( !$expect->{zero_discount_message} );
        }
        else {
            ok( !defined $pg_data->{payment_total_discount}, "No Discount Applied Message" )
                            or diag "ERROR - Discount Applied Message: " . p( $pg_data->{payment_total_discount} );
            ok( !defined $pg_data->{payment_total_zero_discount}, "No ZERO Discount Message" )
                            or diag "ERROR - ZERO Discount Message: " . p( $pg_data->{payment_total_zero_discount} );
        }
    }
}

=head2 test_latest_operator_assigned_to_discount

Test that it is always the latest Operator Assigned to the Discount and not
the first Operator who created the initial Pre-Order record.

=cut

sub test_latest_operator_assigned_to_discount : Tests() {
    my $self = shift;

    my $customer = $self->{customer};
    my $products = $self->{products};
    my $address  = $self->{shipping_address};

    my @product_ids     = map { $_->id } @{ $products };
    my @variants_to_use = map { $_->variants->first } @{ $products };

    my $discount_to_use = 15;

    # set the Product Price and get back the Expected Discounted Prices
    my $price_set = $self->_set_products_price( {
        customer    => $customer,
        address     => $address,
        products    => $products,
        start_price => 100,
        discount_to_use => $discount_to_use,
    } );

    my $logged_in_operator = $self->{operator};
    my $other_operator     = $self->{another_operator};

    my %tests = (
        "Discount set as ZERO" => {
            setup => {
                discount_to_use => 0,
                created_by      => $other_operator,
            },
            expect => {
                discount => 0,
                operator => $logged_in_operator,
            },
        },
        "Discount Functionality is turned Off" => {
            setup => {
                turn_on_discount => 0,
            },
            expect => {
                discount => 0,
                operator => undef,
            },
        },
        "Discount Functionality is turned Off, but Pre-Order originally had ${discount_to_use}% Discount" => {
            setup => {
                turn_on_discount => 0,
                discount_to_use  => $discount_to_use,
                created_by       => $other_operator,
            },
            expect => {
                discount => 0,
                operator => undef,
            },
        },
        "Discount set as ${discount_to_use}%" => {
            setup => {
                discount_to_use => $discount_to_use,
                created_by      => $other_operator,
            },
            expect => {
                discount => $discount_to_use,
                operator => $logged_in_operator,
            },
        },
    );

    # common arguments for the Create Pre-Order method
    my %common_pre_order_args = (
        channel             => $self->{channel},
        customer            => $customer,
        shipment_address    => $address,
        variants            => \@variants_to_use,
    );

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test    = $tests{ $label };
        my $setup   = $test->{setup};
        my $expect  = $test->{expect};

        # default to Discount being turned On
        my $turn_on_discount = $setup->{turn_on_discount} // 1;

        Test::XTracker::Data->set_pre_order_discount_settings( $self->{channel}, {
            can_apply_discount => $turn_on_discount,
            max_discount       => 30,
            discount_increment => 5,
        } );

        my $price_to_use    = ( $setup->{discount_to_use} ? 'discount_price' : 'price' );
        my $discount_to_use = $setup->{discount_to_use} // 0;

        $self->_set_discount_price( $price_set, $customer, $address, $discount_to_use );
        my $pre_order = Test::XTracker::Data::PreOrder->create_incomplete_pre_order( {
            %common_pre_order_args,
            discount_percentage => $discount_to_use,
            discount_operator   => $setup->{created_by},
            item_product_prices => {
                map { $_ => $price_set->{products}{ $_ }{ $price_to_use } }
                    keys %{ $price_set->{products} },
            },
        } );

        $self->framework->flow_mech__preorder__basket( $pre_order->id )
                        ->flow_mech__preorder__basket__payment;

        $pre_order->discard_changes;
        cmp_ok( $pre_order->applied_discount_percent, '==', $expect->{discount},
                                    "Discount on 'pre_order' record is as Expected" );
        if ( $expect->{operator} ) {
            cmp_ok( $pre_order->applied_discount_operator_id, '==', $expect->{operator}->id,
                                    "Discount Operator on 'pre_order' record is as Expected" );
        }
        else {
            ok( !defined $pre_order->applied_discount_operator_id,
                                    "Discount Operator on 'pre_order' record is 'undef'" )
                                        or diag "ERROR - Operator NOT 'undef': " . $pre_order->applied_discount_operator_id;
        }
    }
}

=head2 test_discount_shown_on_summary_page

Tests that the Discount is shown on the Pre-Order Summary page.

=cut

sub test_discount_shown_on_summary_page : Tests() {
    my $self = shift;

    my $customer = $self->{customer};
    my $products = $self->{products};
    my $address  = $self->{shipping_address};

    my @product_ids     = map { $_->id } @{ $products };
    my @variants_to_use = map { $_->variants->first } @{ $products };

    my $discount_to_use = 15;

    # set the Product Price and get back the Expected Discounted Prices
    my $price_set = $self->_set_products_price( {
        customer    => $customer,
        address     => $address,
        products    => $products,
        start_price => 100,
        discount_to_use => $discount_to_use,
    } );

    my %tests = (
        "ZERO Discount" => {
            setup => {
                discount_to_use => 0,
            },
            expect => {
                to_see_discount => 0,
            },
        },
        "Discount Functionality Turned Off" => {
            setup => {
                turn_on_discount => 0,
                operator         => undef,
            },
            expect => {
                to_see_discount => 0,
            },
        },
        "Discount Functionality Turned Off but with a Pre-Order that had a ${discount_to_use}% Discount" => {
            setup => {
                turn_on_discount => 0,
                discount_to_use  => $discount_to_use,
            },
            expect => {
                to_see_discount => 1,
            },
        },
        "Discount set at ${discount_to_use}%" => {
            setup => {
                discount_to_use => $discount_to_use,
            },
            expect => {
                to_see_discount => 1,
            },
        },
    );

    # common arguments for the Create Pre-Order method
    my %common_pre_order_args = (
        channel             => $self->{channel},
        customer            => $customer,
        shipment_address    => $address,
        variants            => \@variants_to_use,
    );

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test    = $tests{ $label };
        my $setup   = $test->{setup};
        my $expect  = $test->{expect};

        # default to Discount being turned On
        my $turn_on_discount = $setup->{turn_on_discount} // 1;

        Test::XTracker::Data->set_pre_order_discount_settings( $self->{channel}, {
            can_apply_discount => $turn_on_discount,
            max_discount       => 30,
            discount_increment => 5,
        } );

        my $price_to_use    = ( $setup->{discount_to_use} ? 'discount_price' : 'price' );
        my $discount_to_use = $setup->{discount_to_use} // 0;
        my $operator        = ( exists( $setup->{operator} ) ? $setup->{operator} : $self->{operator} );

        $self->_set_discount_price( $price_set, $customer, $address, $discount_to_use );
        my $pre_order = Test::XTracker::Data::PreOrder->create_complete_pre_order( {
            %common_pre_order_args,
            discount_percentage => $discount_to_use,
            discount_operator   => $operator,
            item_product_prices => {
                map { $_ => $price_set->{products}{ $_ }{ $price_to_use } }
                    keys %{ $price_set->{products} },
            },
        } );

        $self->framework->mech__reservation__pre_order_summary( $pre_order->id );
        my $pg_data = $self->pg_data;

        $self->_check_discount_column( 'pre_order_item_list', $expect->{to_see_discount}, $discount_to_use );
        $self->_check_totals( $price_set->{total}, $price_to_use, $discount_to_use );
        if ( $expect->{to_see_discount} ) {
            my $expect_operator = $operator->name;
            ok( $pg_data->{discount_operator}, "Discount Operator is Shown" );
            like( $pg_data->{discount_operator}, qr/${expect_operator}/i, "and the Operator Name is as Expected" );
        }
        else {
            ok( !$pg_data->{discount_operator}, "No Discount Operator Shown" )
                                or diag "ERROR - Discount Operator Shown: " . p( $pg_data->{discount_operator} );
        }
    }
}

=head2 test_pre_order_search

Tests the Pre-Order search page including whether Discounts are shown or not.

=cut

sub test_pre_order_search : Tests() {
    my $self = shift;

    my $customer = $self->{customer};
    my $address  = $self->{shipping_address};

    my $discount_pre_order = Test::XTracker::Data::PreOrder->create_complete_pre_order( {
        channel             => $self->{channel},
        customer            => $customer,
        shipment_address    => $address,
        discount_percentage => 15,
        discount_operator   => $self->{operator},
    } );

    my $non_discount_pre_order = Test::XTracker::Data::PreOrder->create_complete_pre_order( {
        channel             => $self->{channel},
        customer            => $customer,
        shipment_address    => $address,
    } );

    $self->framework->flow_mech__preorder__search
                    ->flow_mech__preorder__search_submit( {
        customer_number => $customer->is_customer_number,
    } );
    my $pg_data = $self->pg_data()->{search_results};

    note "Check 'Discount' column is present for Discounted Pre-Order";
    $self->_check_discount_column( 'preorder_' . $discount_pre_order->id, 1, 15, $pg_data );

    note "Check 'Discount' column is NOT present for NON-Discounted Pre-Order";
    $self->_check_discount_column( 'preorder_' . $non_discount_pre_order->id, 0, 15, $pg_data );
}

=head2 test_customer_search

Tests the Customer Search page including making sure that on the 'Pre Orders' tab that
the Discount column is shown or not.

=cut

sub test_customer_search : Tests() {
    my $self = shift;

    my $customer = $self->{customer};
    my $address  = $self->{shipping_address};

    my $discount_pre_order = Test::XTracker::Data::PreOrder->create_complete_pre_order( {
        channel             => $self->{channel},
        customer            => $customer,
        shipment_address    => $address,
        discount_percentage => 15,
        discount_operator   => $self->{operator},
    } );

    my $non_discount_pre_order = Test::XTracker::Data::PreOrder->create_complete_pre_order( {
        channel             => $self->{channel},
        customer            => $customer,
        shipment_address    => $address,
    } );

    $self->framework->mech__reservation__customer_search
                    ->mech__reservation__customer_search_submit( {
                            customer_number => $customer->is_customer_number,
                        } )
                    ->mech__reservation__customer_search_results_click_on_customer( $customer->is_customer_number )
                    ;
    my $pg_data = $self->pg_data()->{pre_order_list};

    note "Check 'Discount' column is present for Discounted Pre-Order";
    $self->_check_discount_column( 'preorder_' . $discount_pre_order->id, 1, 15, $pg_data );

    note "Check 'Discount' column is NOT present for NON-Discounted Pre-Order";
    $self->_check_discount_column( 'preorder_' . $non_discount_pre_order->id, 0, 15, $pg_data );
}

=head2 test_discount_shown_on_order_view_page

Makes sure a Pre-Order Discount is displayed on the Order View page.

=cut

sub test_discount_shown_on_order_view_page : Tests() {
    my $self = shift;

    my $customer = $self->{customer};

    my $discounted_order = Test::XTracker::Data::PreOrder->create_order_linked_to_pre_order( {
        channel  => $customer->channel,
        customer => $customer,
        pre_order_args => {
            discount_percentage => 15,
            discount_operator   => $self->{operator},
        },
    } );
    my $non_discounted_order = Test::XTracker::Data::PreOrder->create_order_linked_to_pre_order( {
        channel  => $customer->channel,
        customer => $customer,
    } );

    note "Check 'Discount' is shown on Order View page for Discounted Pre-Order's Order";
    $self->framework->flow_mech__customercare__orderview( $discounted_order->id );
    my $pg_data = $self->pg_data()->{meta_data}{'Order Details'}{'Pre-Order Number'};
    is( $pg_data->{value}, $discounted_order->get_preorder->pre_order_number, "got correct Pre-Order Number" );
    is( $pg_data->{discount}, $discounted_order->get_preorder->applied_discount_percent,
                                    "got expected Discount" );

    note "Check 'Discount' is NOT shown on Order View page for NON-Discounted Pre-Order's Order";
    $self->framework->flow_mech__customercare__orderview( $non_discounted_order->id );
    $pg_data = $self->pg_data()->{meta_data}{'Order Details'}{'Pre-Order Number'};
    is( $pg_data->{value}, $non_discounted_order->get_preorder->pre_order_number, "got correct Pre-Order Number" );
    ok( !defined $pg_data->{discount}, "NO Discount is shown" )
                                or "ERROR - Discount Shown: " . p( $pg_data->{discount} );
}

sub test_address_is_valid_for_pre_order__when_address_is_valid : Tests {
    my $self = shift;

    my $customer = $self->{customer};
    my $address  = $self->{shipping_address};

    # Remember the original address.
    my %original_address = $address->get_columns;

    # Update the address to contain known values for all columns, except the
    # id column, which we must ignore.
    delete $original_address{id};
    $address->update( { map { $_ => $_ } keys %original_address } );

    $self->framework->flow_mech__preorder__select_products( {
        customer_id             => $customer->id,
        shipment_address_id     => $address->id,
        invoice_address_id      => $address->id,
        skip_pws_customer_check => 1,
    } );

    my $data = $self->pg_data;

    ok( exists $data->{shipment_address_text},
        'The shipment address is present for a valid address' );

    cmp_ok( $data->{shipment_address_text}, 'eq',
        sprintf( '%s %s %s, %s, %s, %s, %s, %s, %s',
            $address->first_name,
            $address->last_name,
            $address->address_line_1,
            $address->address_line_2,
            $address->address_line_3,
            $address->towncity,
            $address->postcode,
            $address->county,
            $address->country ),
        '  .. and the address matches' );

    # Restore the address.
    $address->update( \%original_address );

}


sub test_address_is_valid_for_pre_order__when_address_is_not_valid : Tests {
    my $self = shift;

    my $customer = $self->{customer};
    my $address  = $self->{shipping_address};

    # Remember the First Name and set it to be blank.
    my $old_first_name = $address->first_name;
    $address->update( { first_name => '' } );

    $self->framework->catch_error(
        qr/No shipping address for this customer/,
        'An exception is thrown, as expected, when there is no address for the customer',
        flow_mech__preorder__select_products => ( {
            customer_id             => $customer->id,
            shipment_address_id     => $address->id,
            invoice_address_id      => $address->id,
            skip_pws_customer_check => 1,
        } )
    );

    my $data = $self->pg_data;

    ok( exists $data->{shipment_address_none},
        'The shipment address is NOT present for an ivalid address' );

    cmp_ok( $data->{shipment_address_none}, 'eq',
        'This customer has no previous shipping address to be used for a Pre-Order.',
        '  .. and the message is correct' );

    # Restore the First Name.
    $address->update( { first_name => $old_first_name } );

}

#----------------------------------------------------------------------------------

# helper to check the contents of the Discount Drop-Down
sub _check_discount_drop_down {
    my ( $self, $drop_down, $args ) = @_;

    if ( !$args->{drop_down_shown} ) {
        ok( !defined $drop_down, "Couldn't see Discount Drop-Down" )
                        or diag "ERROR - Could see Discount Drop-Down: " . p( $drop_down );
        return;
    }

    # check the Selected Option
    my $selected_option = $args->{selected_option} // $args->{only_check_selected} // '0';
    is( $drop_down->{select_selected}[0], $selected_option,
                            "Selected Option is as Expected: ${selected_option}" );

    return      if ( $args->{only_check_selected} );

    # check for an Option marked as the Default
    my ( $got_default_value ) = grep { $_->[1] =~ m/default/i  }
                                            @{ $drop_down->{select_values} };
    if ( defined $args->{default_option} ) {
        is( $got_default_value->[0], $args->{default_option},
                            "Default Option is as Expected: " . $args->{default_option} );
    }
    else {
        ok( !defined $got_default_value, "No Default Option was found" );
    }

    # now check the range of Values in the Options
    my @expected_range;
    my $counter = $args->{first_option};
    while ( $counter <= $args->{last_option} ) {
        push @expected_range, $counter;
        $counter += $args->{increment};
    }

    my @got_range = map { $_->[0] } @{ $drop_down->{select_values} };
    cmp_deeply( \@got_range, \@expected_range, "range of Options is as Expected" )
                        or diag "Range of Options Unexpected: Got: " . p( @got_range )
                                                         . ", Expected: " . p( @expected_range );

    return;
}

# check Discount Shown on Basket page
sub _check_discount_column {
    my ( $self, $page_key, $discount_on, $expect_discount, $pg_data ) = @_;

    # when not passed in get the Page Data itself
    $pg_data //= $self->pg_data();
    my ( $discount_column ) = map { $_->{Discount} }
                                grep { exists( $_->{Discount} ) }
                                    @{ $pg_data->{ $page_key } };
    if ( $discount_on ) {
        $expect_discount = sprintf( '%0.2f', $expect_discount );
        like( $discount_column, qr/${expect_discount}/, "Discount Column is shown and has the correct Discount" );
    }
    else {
        ok( !$discount_column, "No Discount Column shown" );
    }

    return;
}

# check the Items on the Basket page
sub _check_basket_items {
    my ( $self, $price_set, $price_type, $variants ) = @_;

    my $got_prices = $self->_get_basket_prices_from_page( $variants );
    my $expect_prices = {
        map {
            $_ => $price_set->{products}{ $_ }{ $price_type },
        } keys %{ $price_set->{products} },
    };
    cmp_deeply( $got_prices, $expect_prices, "Item Prices on the Page as Expected" )
                                or diag "ERROR - Item Prices: Got: " . p( $got_prices )
                                                      . ", Expect: " . p( $expect_prices );
    return;
}

# check the Totals shown on the Basket & Summary page
sub _check_totals {
    my ( $self, $expect_totals, $total_key, $discount_applied ) = @_;

    my $pg_data = $self->pg_data();

    my $got_total = _strip_value_str( $pg_data->{pre_order_total} );
    is( $got_total, $expect_totals->{ $total_key }, "Total Payment Due as Expected" );

    my $got_original_total_cell = $pg_data->{pre_order_original_total};
    if ( $discount_applied ) {
        # get the total part of the cell
        $got_original_total_cell =~ m/discount: .(?<total>.*)/;
        is( _strip_value_str( $+{total} ), $expect_totals->{price}, "Original Total as Expected" );
    }
    else {
        ok( !defined $got_original_total_cell, "Original Total NOT shown on page" )
                            or diag "ERROR - Original Total is Shown: " . p( $got_original_total_cell );
    }

    return;
}

# check the Totals on the actual Pre-Order record
sub _check_pre_order_rec_totals {
    my ( $self, $pre_order, $expect, $price_key ) = @_;

    $pre_order->discard_changes;

    is( $pre_order->total_uncancelled_value_formatted, $expect->{ $price_key },
                        "Pre-Order record Total as Expected" );
    is( $pre_order->get_total_without_discount_formatted, $expect->{price},
                        "Pre-Order record Original Total as Expected" );

    return;
}

# helper to get the prices on the page by Product Id
sub _get_basket_prices_from_page {
    my ( $self, $variants ) = @_;

    # translate Column Headings to useful names
    my %heading_map = (
        Price   => 'unit_price',
        Tax     => 'tax',
        Duty    => 'duty',
        Total   => 'total',
    );

    my %retval;

    my $items = $self->pg_data()->{pre_order_items};

    ITEM:
    foreach my $item ( @{ $items } ) {
        # find the Variant for the SKU
        my ( $variant ) = grep { $_->sku eq $item->{SKU} } @{ $variants };
        next ITEM       if ( !$variant );

        foreach my $heading ( keys %heading_map ) {
            my $value = _strip_value_str( $item->{ $heading } );    # only what the number
            $retval{ $variant->product_id }{ $heading_map{ $heading } } = $value;
        }
    }

    return \%retval;
}

# helper to set the Prices for a list of Products,
# will return the Expected Discount price for each
# Product so it can be compared against in tests
sub _set_products_price {
    my ( $self, $args ) = @_;

    my $customer = $args->{customer};
    my $address  = $args->{address};
    my $products = $args->{products};

    my %expect_product_price;

    my $price_total    = 0;

    my $price = $args->{start_price};
    foreach my $product ( @{ $products } ) {
        $self->_set_single_product_price( $product, $price );
        # need to get the Tax & Duties for the Product
        $expect_product_price{ $product->id }{price} = $self->_get_price_parts(
            $customer,
            $address,
            $product->id,
        );

        # increase the totals using the un-formatted prices
        $price_total    += delete $expect_product_price{ $product->id }{price}{_raw_total};

        $price += 50;
    }

    my %retval = (
        products => \%expect_product_price,
        total    => {
            price => format_currency_2dp( $price_total ),
        },
    );
    $self->_set_discount_price( \%retval, $customer, $address, $args->{discount_to_use} );

    return \%retval;
}

# helper to set the Prices for a Product
sub _set_single_product_price {
    my ( $self, $product, $price ) = @_;

    # remove any existing Prices
    $product->discard_changes;
    $product->price_adjustments->delete;
    $product->price_region->delete;
    $product->price_country->delete;
    $product->price_default->delete;

    $product->create_related( 'price_default', {
        price       => $price,
        currency_id => $self->{dc_currency}->id,
        complete    => 1,
    } );

    return $product->discard_changes;
}

# helper to return the discounted & original
# product price including tax and duties
sub _get_price_parts {
    my ( $self, $customer, $address, $pid, $discount ) = @_;

    my ( $unit_price, undef, undef ) = get_product_selling_price( $self->dbh, {
        customer_id => $customer->id,
        product_id  => $pid,
        county      => $address->county,
        country     => $address->country,
        order_currency_id => $self->{dc_currency}->id,
        order_total => 0,
        pre_order_discount => $discount // 0,
    } );

    my ( undef, $tax, $duty ) = get_product_selling_price( $self->dbh, {
        customer_id => $customer->id,
        product_id  => $pid,
        county      => $address->county,
        country     => $address->country,
        order_currency_id => $self->{dc_currency}->id,
        order_total => $unit_price,
        pre_order_discount => $discount // 0,
    } );

    return {
        unit_price => format_currency_2dp( $unit_price ),
        tax        => format_currency_2dp( $tax ),
        duty       => format_currency_2dp( $duty ),
        total      => format_currency_2dp( $unit_price + $tax + $duty ),
        _raw_total => $unit_price + $tax + $duty,
    };
}

# set the Discount for a hash of Products
sub _set_discount_price {
    my ( $self, $price_hash, $customer, $address, $discount ) = @_;

    my $products = $price_hash->{products};

    my $total = 0;
    foreach my $pid ( keys %{ $products } ) {
        my $price = $products->{ $pid }{price};

        my $price_parts = $self->_get_price_parts( $customer, $address, $pid, $discount );
        $total         += delete $price_parts->{_raw_total};
        $products->{ $pid }{discount_price} = $price_parts;
    }

    $price_hash->{total}{discount_price} = format_currency_2dp( $total );

    # return the price hash anyway
    return $price_hash;
}

# helper to strip everything from a string
# except a number which includes decimal point
# and comma, Eg. '1,200.00' would still be returned
sub _strip_value_str {
    my $value = shift;

    return  if ( !defined $value );

    $value =~ s/[^\d\,\.\-]//g;
    return $value;
}

sub framework {
    my $self    = shift;
    return $self->{framework};
}

sub mech {
    my $self    = shift;
    return $self->framework->mech;
}

sub pg_data {
    my $self    = shift;
    return $self->framework->mech->as_data;
}
