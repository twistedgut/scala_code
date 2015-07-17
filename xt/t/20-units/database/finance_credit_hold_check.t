#!/usr/bin/env perl

use NAP::policy "tt", 'test';

use Test::XTracker::Data;
use Test::XTracker::Data::Order;
use XTracker::Constants::FromDB     qw(
                                        :order_status
                                        :customer_class
                                        :shipment_type
                                    );

use_ok( 'XTracker::Database::Finance', qw(
                                            get_credit_hold_orders
                                            get_credit_check_orders
                                            get_credit_hold_check_priority
                                    ) );
can_ok( 'XTracker::Database::Finance', qw(
                                            get_credit_hold_orders
                                            get_credit_check_orders
                                            get_credit_hold_check_priority
                                    ) );

my $schema      = Test::XTracker::Data->get_schema();

#------------------------
test_helper_functions( $schema, 1 );
test_credit_check_hold( $schema, 1 );
test_credit_check_nominated_day_selection_urgency($schema);
test_credit_check_priority($schema);
#------------------------

done_testing;

# test some helper functions use by the main 'get_credit_hold_orders'
# and 'get_credit_check_orders' functions
sub test_helper_functions {
    my ( $schema, $run )    = @_;

    my %high_priority   = (
            $CUSTOMER_CLASS__EIP            => 'EIP',
            $CUSTOMER_CLASS__IP             => 'IP',
            $CUSTOMER_CLASS__PR             => 'PR',
            $CUSTOMER_CLASS__HOT_CONTACT    => 'Hot Contact',
        );

    my %finance_priority    = (
            'Premier'   => {
                    priority    => 1,
                    row => {
                        shipment_type_id  => $SHIPMENT_TYPE__PREMIER,
                        customer_class_id => $CUSTOMER_CLASS__NONE,
                    },
                },
            'AMEX'      => {
                    priority    => 2,
                    row => {
                        shipment_type_id  => $SHIPMENT_TYPE__DOMESTIC,
                        source            => 'AMEX',
                        customer_class_id => $CUSTOMER_CLASS__NONE,
                    },
                },
            'High Priority Customer'    => {
                    priority    => 4,
                    row => {
                        shipment_type_id  => $SHIPMENT_TYPE__DOMESTIC,
                        customer_class_id => $CUSTOMER_CLASS__EIP,
                    },
                },
            'None'      => {
                    priority    => 0,
                    row => {
                        shipment_type_id  => $SHIPMENT_TYPE__DOMESTIC,
                        customer_class_id => $CUSTOMER_CLASS__NONE,
                    },
                },
            'Premier Has Priority'  => {
                    priority    => 1,
                    row => {
                        shipment_type_id  => $SHIPMENT_TYPE__PREMIER,
                        source            => 'AMEX',
                        customer_class_id => $CUSTOMER_CLASS__EIP,
                    },
                },
            'AMEX Has Priority' => {
                    priority    => 2,
                    row => {
                        shipment_type_id  => $SHIPMENT_TYPE__DOMESTIC,
                        source            => 'AMEX',
                        customer_class_id => $CUSTOMER_CLASS__EIP,
                    },
                },
        );

    SKIP: {
        skip "skipping 'test_helper_functions'", 1      if ( !$run );

        note "TEST: test_helper_functions";

        note "testing 'get_finance_high_priority_classes'";
        my $high_priority_classes   = $schema->resultset('Public::CustomerClass')->get_finance_high_priority_classes;
        cmp_ok( scalar( keys %{ $high_priority_classes } ), '==', scalar( keys %high_priority ),
                                                    "Got the expected number of High Priority Classes: ".scalar( keys %high_priority ) );
        foreach my $class_id ( keys %high_priority ) {
            ok( exists( $high_priority_classes->{ $class_id } ), "Found High Priority Class: $class_id - ".$high_priority{ $class_id } );
            isa_ok( $high_priority_classes->{ $class_id }, "XTracker::Schema::Result::Public::CustomerClass", "and value for class in hash" );
        }

        note "testing 'get_credit_hold_check_priority'";
        foreach my $test_name ( keys %finance_priority ) {
            my $test    = $finance_priority{ $test_name };

            # call the function passing $high_priority_classes and the simulation of the row data
            my $tmp = get_credit_hold_check_priority( $high_priority_classes, $test->{row} );
            cmp_ok( $tmp, '==', $test->{priority}, "got Expected priority for priority test: $test_name - ".$test->{priority} );
        }
    };

    return;
}

# test the main 'get_credit_hold_orders' and 'get_credit_check_orders' functions
# to see that orders with different customer categories get flagged appropriately
sub test_credit_check_hold {
    my ( $schema, $run )    = @_;

    SKIP: {
        skip "skipping 'test_credit_check_hold'", 1         if ( !$run );

        note "TEST: test_credit_check_hold";

        my ($channel,$pids) = Test::XTracker::Data->grab_products({
            how_many => 1,
            channel => 'NAP',
        });

        my $high_priority_classes   = $schema->resultset('Public::CustomerClass')->get_finance_high_priority_classes;

        my $ra_tests = [
            {
                label           => 'Credit Check',
                function        => \&get_credit_check_orders,
                status_id       => $ORDER_STATUS__CREDIT_CHECK,
                shipment_type   => [
                        $SHIPMENT_TYPE__PREMIER,
                        $SHIPMENT_TYPE__DOMESTIC,
                    ],
                customer_class  => [
                        $CUSTOMER_CLASS__IP,
                        $CUSTOMER_CLASS__NONE,
                    ],
            },
            {
                label           => 'Credit Hold',
                status_id       => $ORDER_STATUS__CREDIT_HOLD,
                function        => \&get_credit_hold_orders,
                shipment_type   => [
                        $SHIPMENT_TYPE__PREMIER,
                        $SHIPMENT_TYPE__DOMESTIC,
                    ],
                customer_class  => [
                        $CUSTOMER_CLASS__IP,
                        $CUSTOMER_CLASS__NONE,
                    ],
            },
        ];

        my %expected_fields = (
                'Credit Check'  => [ qw(
                            number sales_channel date age value currency name gift flags priority
                            namecheck addrcheck possiblefraud cv2_avs warningFlags categoryFlags
                            customer_class_id customer_category_id customer_class customer_category
                            shipment_country nominated_dispatch_in nominated_credit_check_urgency
                            nominated_dispatch_time nominated_earliest_selection_time cpl
                    ) ],
                'Credit Hold'   => [ qw(
                            number sales_channel value currency name gift flags priority
                            cv2_avs warningFlags categoryFlags
                            customer_class_id customer_category_id customer_class customer_category
                            shipment_country date
                    ) ],
            );

        my $cust_cat_rs = $schema->resultset('Public::CustomerCategory');
        my $order = create_order({
            channel => $channel,
            pids => $pids
        });
        my $shipment    = $order->get_standard_class_shipment;
        my $ship_addr   = $shipment->shipment_address;
        $channel        = $order->channel->name;
        my $customer    = $order->customer;
        my $cust_name   = $customer->first_name . " " . $customer->last_name;

        foreach my $rh_test (@$ra_tests) {
            note "Testing: ".$rh_test->{label};

            # update the Order Status
            $order->update( { order_status_id => $rh_test->{status_id} } );

            # go through all the Customer Classes
            foreach my $class_id ( @{ $rh_test->{customer_class} } ) {
                my $category    = $cust_cat_rs->search( { customer_class_id => $class_id } )->first;
                my $cust_class  = $category->customer_class;
                note "using customer class: ".$cust_class->class.", category: ".$category->id." - ".$category->category;

                # update the Customer's Category
                $customer->update( { category_id => $category->id } );

                foreach my $ship_type_id ( @{ $rh_test->{shipment_type} } ) {

                    note "using shipment type: ".$ship_type_id;

                    # update the Shipment's Type
                    $shipment->update( { shipment_type_id => $ship_type_id } );

                    my $expected_priority   = get_credit_hold_check_priority( $high_priority_classes, {
                                                                                        shipment_type_id    => $ship_type_id,
                                                                                        customer_class_id   => $cust_class->id,
                                                                                    } );

                    # get the appropriate list
                    my $list    = $rh_test->{function}( $schema );
                    ok( exists( $list->{ $channel }{ $order->id } ), "Found Order Id in Correct Sales Channel in list" );
                    my $row     = $list->{ $channel }{ $order->id };

                    # check fields exists
                    is_deeply(
                        [ sort keys %{ $row } ],
                        [ sort @{ $expected_fields{ $rh_test->{label} } } ],
                        "got ALL expected fields in Row Data"
                    );

                    # check priority as expected
                    cmp_ok( $row->{priority}, '==', $expected_priority, "Priority set as expected: $expected_priority" );

                    # check Customer Category and Category Class
                    cmp_ok( $row->{customer_class_id}, '==', $cust_class->id, "Customer Class Id as expected: ".$cust_class->id );
                    cmp_ok( $row->{customer_category_id}, '==', $category->id, "Customer Category Id as expected: ".$category->id );
                    is( $row->{customer_class}, $cust_class->class, "Customer Class name as expected: ".$cust_class->class );
                    is( $row->{customer_category}, $category->category, "Customer Category name as expected: ".$category->category );

                    # check correct Customer Name is used and Shipping Country is used
                    is( $row->{name}, $cust_name, "Customer name as expected: ".$cust_name );
                    is( $row->{shipment_country}, $ship_addr->country, "Shipment Country as expected: ".$ship_addr->country );
                }
            }
        }

    };

    return;
}

sub nominated_day_times {
    my $times = Test::XTracker::Data::Order->nominated_day_times(@_);
    delete $times->{import_dispatch_time};
    return $times;
}

# test that 'get_credit_hold_orders' sets the nominated_dispatch_in
# and nominated_credit_check_urgency are set correctly
sub test_credit_check_nominated_day_selection_urgency {
    my ($schema) = @_;

    my $channel = Test::XTracker::Data->channel_for_business(name => "NAP");

    # Create one order with nominated day within the urgency window,
    # one order with nominated day just outside the urgency window,
    # one order with nominated day,
    # three orders without nominated day and
    # one with nominated day.
    my $orders_config = [
        {
            setup => {
                %{nominated_day_times(0, $channel)},
                nominated_selection_within_hours => 2, # Within the 4h urgency window
            },
            expected => {
                column_value                   => " (?:second|minute)s?",
                nominated_credit_check_urgency => 1,
            },
        },
        {
            setup => {
                %{nominated_day_times(0, $channel)},
                nominated_selection_within_hours => 6, # Outside the 4h urgency window
            },
            expected => {
                column_value                   => " (?:second|minute)s?",
                nominated_credit_check_urgency => 0,
            },
        },
        {
            setup => nominated_day_times(1, $channel),
            expected => {
                column_value => "1 day",
                nominated_credit_check_urgency => 0,
            },
        },
        ( {
            setup => {
                nominated_delivery_date => undef,
                nominated_dispatch_time => undef,
            },
            expected => {
                column_value                   => "",
                nominated_credit_check_urgency => 0,
            },
        } ) x 3,
        {
            setup => nominated_day_times(3, $channel),
            expected => {
                column_value                   => "3 days",
                nominated_credit_check_urgency => 0,
            },
        },
    ];

    my @orders = create_test_orders({
        channel => $channel,
        test_cases => $orders_config,
    });


    my $channel_id_order = get_credit_check_orders( $schema );
    for my $order (@orders) {
        my $channel_name = $channel->name;
        my $order_row = $channel_id_order->{$channel_name}->{
            $order->{order}->id,
        };

        my $shipment_nominated_dispatch_in = $order_row->{nominated_dispatch_in};
        like(
            $shipment_nominated_dispatch_in,
            qr/$order->{expected}->{column_value}/,
            "Nominated Dispatch In for order (" . $order->{order}->id . ") is correct ($shipment_nominated_dispatch_in)",
        );

        my $credit_check_urgency = $order_row->{nominated_credit_check_urgency};
        is(
            $credit_check_urgency,
            $order->{expected}->{nominated_credit_check_urgency},
            "Credit Check Urgency for order (" . $order->{order}->id . ") is correct ($credit_check_urgency)",
        );

    }
}

sub create_test_orders {
    my($args) = @_;
    my $test_cases = $args->{test_cases} || die "test_cases not passed as arg";
    my $channel = $args->{channel} || die "test_cases not passed as arg";
    my @orders;

    for my $order_config (@{$test_cases}) {
        my (undef, $pids) = Test::XTracker::Data->grab_products({
            how_many => 1,
            channel  => 'NAP',
        });

        #my $order = _create_test_order( $channel->id, $pids );
        my $order = create_order({
            channel => $channel,
            pids => $pids
        });
        push(
            @orders,
            {
                expected => $order_config->{expected},
                order    => $order,
            },
        );
        $order->update({ order_status_id => $ORDER_STATUS__CREDIT_CHECK });

        # Set the nominated day
        my $shipment = $order->get_standard_class_shipment;
        my $shipment_update = { %{$order_config->{setup}} };
        my $nominated_selection_within_hours = delete $shipment_update->{nominated_selection_within_hours};
        if($nominated_selection_within_hours) {
            $shipment_update->{nominated_earliest_selection_time} = DateTime->now->add(
                hours => $nominated_selection_within_hours,
            );
        }

        note "Setting nominated_dispatch_time (" . ($shipment_update->{nominated_dispatch_time} // "") . ") etc";
        $shipment->update($shipment_update);
    }

    return @orders;
}

sub test_credit_check_priority {
    my ($schema) = @_;

    my $channel = Test::XTracker::Data->channel_for_business(name => "NAP");

    my $priority_tests = [
        {
            description => 'premier & not nominated day',
            setup => {
                nominated_delivery_date => undef,
                nominated_dispatch_time => undef,
                shipment_type_id => $SHIPMENT_TYPE__PREMIER,
            },
            expected => {
                credit_hold_check_priority     => 1,
            },
        },
        {
            description => 'domestic & not nominated day',
            setup => {
                nominated_delivery_date => undef,
                nominated_dispatch_time => undef,
                shipment_type_id => $SHIPMENT_TYPE__DOMESTIC,
            },
            expected => {
                credit_hold_check_priority     => 0,
            },
        },
        {
            description => 'premier & nominated day',
            setup => {
                %{nominated_day_times(0, $channel)},
                shipment_type_id => $SHIPMENT_TYPE__PREMIER,
            },
            expected => {
                credit_hold_check_priority     => 1,
            },
        },
        {
            description => 'domestic & nominated day',
            setup => {
                %{nominated_day_times(0, $channel)},
                shipment_type_id => $SHIPMENT_TYPE__DOMESTIC,
            },
            expected => {
                credit_hold_check_priority     => 5,
            },
        },
    ];

    my @orders = create_test_orders({
        channel => $channel,
        test_cases => $priority_tests,
    });

    my $channel_id_order = get_credit_check_orders( $schema );
    for my $order (@orders) {
        my $channel_name = $channel->name;
        my $order_row = $channel_id_order->{$channel_name}->{
            $order->{order}->id,
        };

        is($order_row->{priority},
            $order->{expected}->{credit_hold_check_priority},
            "Priority matched - ".
                $order->{expected}->{credit_hold_check_priority});

    }
}

#----------------------------------------------------------------------------------------------

sub create_order {
    my($args) = @_;
    my $shipment = Test::XTracker::Data->create_domestic_order(
        channel => $args->{channel},
        pids => $args->{pids},
    )->shipments->first;

    my $order = $shipment->order;
    note "Order: ". $order->id ." Shipment: ". $shipment->id;
    return $order;
}

