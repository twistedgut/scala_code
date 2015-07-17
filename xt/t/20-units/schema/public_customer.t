#!/usr/bin/env perl

use NAP::policy "tt", qw( test class );

BEGIN {
    extends 'NAP::Test::Class';
    with $_ for qw{ Test::Role::WithSchema };
};

use Mock::Quick;
use JSON qw/decode_json/;

use HTTP::Status        qw( :constants );

use DateTime;
use DateTime::Format::DateParse;

use Test::XTracker::Data;
use Test::XT::Data;
use Test::XT::Domain::Payment::Mock;

use XT::Net::Seaview::Client;
use XT::Net::Seaview::TestUserAgent;
use XT::Net::Seaview::Exception::ClientError;
use XTracker::Config::Local qw( config_var );
use XTracker::Constants qw( $APPLICATION_OPERATOR_ID );
use XTracker::Constants::FromDB qw(
    :flag
    :customer_category
    :customer_class
    :order_status
    :customer_action_type
    :service_attribute_type
    );

=head1 NAME

Test::XTracker::Schema::Result::Public::Customer

=head1 DESCRIPTION

Runs various tests against the Test::XTracker::Schema::Result::Public::Customer
class.

NOTE:

This was moved from t/20-units/class/Test/XTracker/Schema/Result/Public/Customer.pm,
as Test::Class::Load was intefering with Test::XT::Domain::Payment::Mock.

TODO: This should be merged with t/20-units/schema/customer.t

=head1 TESTS

=cut

sub startup : Test( startup => 0 ) {
    my $self    = shift;

    $self->{user_agent} = 'XT::Net::Seaview::TestUserAgent';
    $self->{schema}     = Test::XTracker::Data->get_schema();
    $self->{dbh}        = $self->{schema}->storage->dbh;
    $self->{channels}   = [ Test::XTracker::Data->get_enabled_channels->all ];
    $self->{payment}    = Test::XT::Domain::Payment::Mock->new( { initialise_only => 1 } );
    $self->{seaview}    = XT::Net::Seaview::Client->new( {
        schema          => $self->{schema},
        useragent_class => config_var("Seaview", "useragent_class"),
    } );

}

sub setup : Test( setup => 8 ) {
    my $self = shift;

    $self->schema->txn_begin;

    my $cust_email  = Test::XTracker::Data->create_unmatchable_customer_email( $self->dbh );

    foreach my $channel ( @{ $self->{channels} } ) {
        my $data    = Test::XT::Data->new_with_traits( {
            traits  => [
                'Test::XT::Data::Channel',
                'Test::XT::Data::Customer',
                'Test::XT::Data::Order',
            ],
        } );
        $data->channel( $channel );
        $data->email( $cust_email );

        $self->{customers}{ $channel->id }  = $data->customer;

        # create an Order for the Customer
        $self->{orders}{ $channel->id }     = $data->dispatched_order(
            channel     => $channel,
            customer    => $data->customer,
        );
    }
}

sub teardown : Test( teardown => 0 ) {
    my $self = shift;

    $self->schema->txn_rollback;
}

sub customer_on_finance_watch_on_any_channel : Tests {
    my $self = shift;

    foreach my $channel ( Test::XTracker::Data->get_enabled_channels->all ) {
        note "Sales Channel: " . $channel->name;

        my $customer = $self->{customers}{ $channel->id };

        my $flags = $customer->on_all_channels->search_related('customer_flags', {
            flag_id => $FLAG__FINANCE_WATCH,
        } );

        if ( ! $flags || $flags->count == 0 ) {
            ok( ! $customer->is_on_finance_watch_on_any_channel,
                "... and the customer is not on Finance Watch");
            note( "Setting Finance Watch flag" );
            my $new_flag = $customer->customer_flags->find_or_create( {
                flag_id => $FLAG__FINANCE_WATCH,
            } );
            ok( $customer->is_on_finance_watch_on_any_channel,
                "... and the customer is now on Finance Watch");
            $new_flag->delete;
        }
        else {
            ok( $customer->is_on_finance_watch_on_any_channel,
                "... and the customer is on Finance Watch");
            note( "Removing Finance watch flag" );
            while ( my $flag = $flags->next ) {
                $flag->delete;
            }
            ok( ! $customer->is_on_finance_watch_on_any_channel,
                "... and the customer is no longer on Finance Watch");
            note( "Putting the customer back on Finance Watch");
            my $new_flag = $customer->customer_flags->find_or_create( {
                flag_id => $FLAG__FINANCE_WATCH,
            } );
            ok( $customer->is_on_finance_watch_on_any_channel,
                "... and the customer is on Finance Watch");
        }
    }
}

sub is_an_eip : Tests {
    my $self = shift;

    foreach my $channel ( Test::XTracker::Data->get_enabled_channels->all ) {
        note "Sales Channel: " . $channel->name;

        my $customer = $self->{customers}{ $channel->id };

        if ( ! $customer->category->customer_class_id == $CUSTOMER_CLASS__EIP ) {
            ok( $customer->is_an_eip, "... and the customer is an EIP");
        }
        else {
            ok( ! $customer->is_an_eip, "... and the customer is not an EIP");
            my $old_class = $customer->category->customer_class_id;

            # Change the class so that we can verify it works properly
            $customer->category->customer_class_id($CUSTOMER_CLASS__EIP);
            ok( $customer->is_an_eip, "... but now the customer is an EIP!");

            # and now change it back!
            $customer->discard_changes;
            ok( ! $customer->is_an_eip, "... and the customer is not an EIP again");
        }
    }
}

sub has_orders_on_credit_hold_on_any_channel : Tests {
    my $self = shift;

    foreach my $channel ( Test::XTracker::Data->get_enabled_channels->all ) {
        note "Sales Channel: " . $channel->name;

        my $customer = $self->{customers}{ $channel->id };

        my $on_hold = $customer->related_orders_in_status($ORDER_STATUS__CREDIT_HOLD);
        if ( ! $on_hold || $on_hold->count == 0 ) {
            ok(!$customer->has_orders_on_credit_hold_on_any_channel,
                "... who has no orders on Credit Hold");

            if ( $customer->orders && $customer->orders->count > 0 ) {
                my $order = $customer->orders->first;

                note("Setting an order on credit hold");
                $order->set_status_credit_hold($APPLICATION_OPERATOR_ID);
                ok($customer->has_orders_on_credit_hold_on_any_channel,
                    "... and now has an order on Credit Hold");

                note("Taking order back off credit hold");
                $order->set_status_accepted($APPLICATION_OPERATOR_ID);
                ok(!$customer->has_orders_on_credit_hold_on_any_channel,
                    "... and now no orders on Credit Hold");
            }
        }
        else {
            ok($customer->has_orders_on_credit_hold_on_any_channel,
                "... and (s)he has orders on Credit Hold");

            note("Taking order(s) off credit hold");
            my $orders = $customer->related_orders_in_status($ORDER_STATUS__CREDIT_HOLD);
            while ( my $order = $orders->next ) {
                $order->set_status_accepted($APPLICATION_OPERATOR_ID);
            }

            ok(!$customer->has_orders_on_credit_hold_on_any_channel,
                "... and now no orders on Credit Hold");

            note("Putting them back on credit hold");
            while ( my $order = $orders->next ) {
                $order->set_status_credit_hold($APPLICATION_OPERATOR_ID);
            }

            ok($customer->discard_changes->has_orders_on_credit_hold_on_any_channel,
                "... and now orders on Credit Hold again");
        }
    }
}

sub has_order_on_credit_check_on_any_channel : Tests {
    my $self = shift;

    foreach my $channel ( Test::XTracker::Data->get_enabled_channels->all ) {
        note "Sales Channel: " . $channel->name;

        my $customer = $self->{customers}{ $channel->id };

        my $credit_check = $customer->related_orders_in_status($ORDER_STATUS__CREDIT_CHECK);
        if ( ! $credit_check || $credit_check->count == 0 ) {
            ok(!$customer->has_order_on_credit_check_on_any_channel,
                "... who has no orders on Credit Check");

            if ( $customer->orders && $customer->orders->count > 0 ) {
                my $order = $customer->orders->first;
                my $old_status = $order->order_status_id;

                note("Setting an order on credit check");
                $order->change_status_to(
                    $ORDER_STATUS__CREDIT_CHECK,
                    $APPLICATION_OPERATOR_ID
                );
                ok($customer->has_order_on_credit_check_on_any_channel,
                    "... now has order on Credit Check");

                note("Setting order status back");
                $order->change_status_to( $old_status, $APPLICATION_OPERATOR_ID );
                ok(!$customer->has_order_on_credit_check_on_any_channel,
                    "... has no orders on Credit Check again");
            }
        }
        else {
            ok($customer->has_order_on_credit_check_on_any_channel,
                "... and (s)he has an order on Credit Check");

            note("Taking order(s) off credit check");
            my $orders = $customer->related_orders_in_status($ORDER_STATUS__CREDIT_CHECK);
            while ( my $order = $orders->next ) {
                $order->set_status_accepted($APPLICATION_OPERATOR_ID);
            }

            ok(!$customer->has_order_on_credit_check_on_any_channel,
                "... now has no orders on Credit Check");

            note("Putting them back on credit check");
            while ( my $order = $orders->next ) {
                $order->change_status_to(
                    $ORDER_STATUS__CREDIT_CHECK,
                    $APPLICATION_OPERATOR_ID
                );
            }
            ok($customer->has_order_on_credit_check_on_any_channel,
                "... has an order on Credit Check again");
        }
    }
}

sub is_staff_on_any_channel : Tests {
    my $self = shift;

    foreach my $channel ( Test::XTracker::Data->get_enabled_channels->all ) {
        note "Sales Channel: " . $channel->name;

        my $customer = $self->{customers}{ $channel->id };

        $customer->update( { category_id => $CUSTOMER_CATEGORY__STAFF } );
        ok($customer->is_staff_on_any_channel, "... and (s)he is staff");

        $customer->update( { category_id => $CUSTOMER_CATEGORY__NONE } );
        ok( ! $customer->is_staff_on_any_channel, "... and (s)he is not staff");
    }
}

sub orders_within_period_not_cancelled : Tests {
    my $self = shift;

    my @channels = Test::XTracker::Data->get_enabled_channels->all;

    my $order_data = Test::XTracker::Data::Order->create_new_order({
        channel => $channels[0]
    });

    my $customer = $order_data->{customer_object};
    ok($customer, "I have a customer ...");

    my $orders = $customer->orders_within_period_not_cancelled( {
        count => 1,
        period => 'hour',
    });

    ok($orders && $orders->count > 0,
        "Found orders placed within last hour");
}

sub orders_aged_on_any_channel : Tests {
    my $self = shift;

    foreach my $channel ( Test::XTracker::Data->get_enabled_channels->all ) {
        note "Sales Channel: " . $channel->name;

        my $customer = $self->{customers}{ $channel->id };

        my $orders = $customer->orders_aged_on_any_channel( {
            count => 5,
            period => 'day',
        } );

        ok( $orders && $orders->count > 0,
            "... found ".$orders->count." orders in last 5 days for them");
    }
}

sub has_placed_order_in_last_n_periods : Tests {
    my $self = shift;

    my @channels = Test::XTracker::Data->get_enabled_channels->all;
    my $order_data = Test::XTracker::Data::Order->create_new_order({
        channel => $channels[0]
    });

    my $customer = $order_data->{customer_object};
    ok($customer, "I have a customer ...");

    ok($customer->has_placed_order_in_last_n_periods( {
            count => 1,
            period => 'hour',
            on_all_channels => 1
        } ),
            "... Found orders placed in last hour");

    dies_ok( sub { $customer->has_placed_order_in_last_n_periods() },
        "calls to has_placed_order_in_last_n_periods without params die" );

    dies_ok( sub { $customer->has_placed_order_in_last_n_periods( {
            count => 1
        } ) },
        "calls to has_placed_order_in_last_n_periods without period die" );

    dies_ok( sub { $customer->has_placed_order_in_last_n_periods( {
            period => 'day'
        } ) },
        "calls to has_placed_order_in_last_n_periods without count die" );

    dies_ok( sub { $customer->has_placed_order_in_last_n_periods( {
            count => 1,
            period => 'moon'
        } ) },
        "calls to has_placed_order_in_last_n_periods with invalid period die" );
}

sub total_spend_in_last_n_period : Tests {
    my $self = shift;

    foreach my $channel ( Test::XTracker::Data->get_enabled_channels->all ) {
        note "Sales Channel: " . $channel->name;

        my $customer = $self->{customers}{ $channel->id };

        my $total_shipment_value = 0;
        my $total_original_value = 0;

        my $orders = $customer->orders_aged( '6 month' );

        while ( my $order = $orders->next ) {
            # add 10 to the Shipping Charge to make
            # sure that the Shipment Total is different
            # to the Order's original 'total_value'
            my $shipment = $order->get_standard_class_shipment;
            $shipment->update( {
                shipping_charge => $shipment->shipping_charge + 10,
            } );

            $total_shipment_value += $order->get_total_value_in_local_currency;
            $total_original_value += $order->get_total_value_in_local_currency( {
                want_original_purchase_value => 1,
            } );
        }

        cmp_ok( $customer->discard_changes->total_spend_in_last_n_period( {
                count => 6,
                period => 'month',
            } ), '==', $total_shipment_value,
            "Total Spend matches Shipment Total Value"
        );

        cmp_ok( $customer->total_spend_in_last_n_period( {
                count => 6,
                period => 'month',
                want_original_purchase_value => 1,
            } ), '==', $total_original_value,
            "Total Spend with 'want_original_purchase_value' argument matches Original Order Total Value"
        );
    }
}

sub total_spend_in_last_n_period_on_all_channels : Tests {
    my $self = shift;

    foreach my $channel ( Test::XTracker::Data->get_enabled_channels->all ) {
        note "Sales Channel: " . $channel->name;

        my $customer = $self->{customers}{ $channel->id };

        my $total_shipment_value = 0;
        my $total_original_value = 0;

        my $orders = $customer->orders_aged_on_any_channel( {
            count => 6,
            period => 'month',
        } );

        while ( my $order = $orders->next ) {
            # add 10 to the Shipping Charge to make
            # sure that the Shipment Total is different
            # to the Order's original 'total_value'
            my $shipment = $order->get_standard_class_shipment;
            $shipment->update( {
                shipping_charge => $shipment->shipping_charge + 10,
            } );

            $total_shipment_value += $order->get_total_value_in_local_currency;
            $total_original_value += $order->get_total_value_in_local_currency( {
                want_original_purchase_value => 1,
            } );
        }

        cmp_ok( $customer->discard_changes->total_spend_in_last_n_period_on_all_channels( {
                count => 6,
                period => 'month',
            } ), '==', $total_shipment_value,
            "Total Spend matches Shipment Total Value"
        );

        cmp_ok( $customer->total_spend_in_last_n_period_on_all_channels( {
                count => 6,
                period => 'month',
                want_original_purchase_value => 1,
            } ), '==', $total_original_value,
            "Total Spend with 'want_original_purchase_value' argument matches Original Order Total Value"
        );
    }
}

sub is_credit_checked : Tests {
    my $self = shift;

    my $now = $self->schema->db_now;

    foreach my $channel ( Test::XTracker::Data->get_enabled_channels->all ) {
        note "Sales Channel: " . $channel->name;

        my $customer = $self->{customers}{ $channel->id };

        my @customers   = $customer->on_all_channels->all;

        # make All Customers NOT Credit Checked
        $_->update( { credit_check => undef } )   foreach ( @customers );
        ok( ! $customer->is_credit_checked,
                "... and (s)he has not been credit checked" );

        # make All Customers Credit Checked
        $_->update( { credit_check => $now } )   foreach ( @customers );
        ok( $customer->is_credit_checked,
                "... and (s)he has been credit checked");
    }
}

sub has_orders_older_than_not_cancelled : Tests {
    my $self = shift;

    my @channels = Test::XTracker::Data->get_enabled_channels->all;
    my $order_data = Test::XTracker::Data::Order->create_new_order( {
        channel => $channels[0],
    } );
    my $customer = $order_data->{customer_object};
    my $order    = $order_data->{order_object};

    # make sure the Customer has a unique Email Address
    # and so won't link to any other Customer
    $customer->update( {
        email => Test::XTracker::Data->create_unmatchable_customer_email( $self->dbh ),
    } );

    # get the DB Date as of now
    my $date = $self->schema->db_now;
    $date->subtract( seconds => 10 );
    $order->update( { date => $date } );
    $customer->discard_changes;

    ok($customer->has_orders_older_than_not_cancelled({
            count => 1,
            period => 'second',
        }), "Customer has orders older than 1 second");

    ok( ! $customer->has_orders_older_than_not_cancelled({
            count => 500,
            period => 'year',
        }), "Customer does not have orders older than 500 years");

}

# _add_order_ok
#
# Call $customer->add_order and make sure the new order row matches
# the XT::Data::Order data. Return the new order row.

sub _add_order_ok {
    my ($self,  $args ) = @_;

    my $channel = delete $args->{channel};

    # Make sure we have HashRefs defined for all other keys, as they
    # are custom options for each object below.
    $args->{ $_ } //= {} foreach qw( address name money order tender );

    my $customer = Test::XTracker::Data->find_customer( {
        channel_id => $channel->id,
    } );

    isa_ok( $customer, 'XTracker::Schema::Result::Public::Customer' );

    # Get the next valid order number.
    my $order_nr = Test::XTracker::Data->get_order_number;

    note "Creating order with order_nr '$order_nr'";

    # Create the XT::Data:* objects ...

    my $address = XT::Data::Address->new( {
        schema       => $self->{schema},
        line_1       => 'Line 1',
        line_2       => 'Line 2',
        line_3       => '',
        town         => 'Town city',
        county       => 'County',
        country_code => 'GB',
        postcode     => 'W12',
        urn          => 'customer_urn',
        last_modified => DateTime->now( time_zone => 'local' ),
        %{ $args->{address} },
    } );

    my $name = XT::Data::CustomerName->new( {
        title               => 'title',
        first_name          => 'first_name',
        last_name           => 'last_name',
        %{ $args->{name} },
    } );

    my $money = XT::Data::Money->new( {
        schema              => $self->{schema},
        currency            => 'GBP',
        value               => 123,
        %{ $args->{money} },
    } );


    my $xt_order = XT::Data::Order->new( {
        schema                  => $self->{schema},
        billing_address         => $address,
        billing_email           => 'noone@nowhere.com',
        billing_name            => $name,
        channel_name            => $channel->web_name,
        order_number            => $order_nr,
        order_date              => DateTime->now( time_zone => 'floating' ),
        customer_name           => $name,
        customer_number         => 123,
        customer_ip             => '127.0.0.1',
        placed_by               => 'placed_by',
        used_stored_credit_card => 0,
        delivery_address        => $address,
        delivery_name           => $name,
        gross_total             => $money,
        is_gift_order           => 0,
        sticker                 => undef,
        gift_credit             => $money,
        store_credit            => $money,
        tenders                 => [
            XT::Data::Order::Tender->new( {
                schema               => $self->{schema},
                id                   => '1',
                rank                 => '1',
                value                => $money,
                psp_reference        => 'psp_reference',
                payment_pre_auth_ref => 'payment_pre_auth_ref',
                payment_settle_ref   => 'payment_settle_ref',
                fulfilled            => 1,
                valid                => 1,
                type                 => 'Store Credit',
                %{ $args->{tender} },
            } ),
        ],
        %{ $args->{order} },
    } );

    # Create the new order row on the customer object.
    my $db_order = $customer->add_order( $xt_order );

    # Make sure we the right order and customer data.
    isa_ok( $db_order, 'XTracker::Schema::Result::Public::Orders' );
    cmp_ok( $db_order->order_nr, '==', $order_nr, 'The order has the correct order number' );
    cmp_ok( $db_order->customer_id, '==', $customer->id, 'The order is attached to the correct customer' );

    # Now do some more in-depth tests ...

    cmp_deeply( { $db_order->get_columns }, superhashof( {
        order_nr                => $xt_order->order_number,
        basket_nr               => $xt_order->order_number,
        invoice_nr              => '',
        session_id              => '',
        cookie_id               => '',
        date                    => $self->{schema}->storage->datetime_parser->format_datetime(
                                    $xt_order->order_date
                                ),
        total_value             => $xt_order->gross_total->value,
        gift_credit             => $xt_order->extract_money( 'gift_credit' ),
        store_credit            => $xt_order->extract_money( 'store_credit' ),
        customer_id             => $customer->id,
        credit_rating           => 1,
        card_issuer             => '-',
        card_scheme             => '-',
        card_country            => '-',
        card_hash               => '-',
        cv2_response            => '-',
        order_status_id         => 0,
        email                   => $xt_order->billing_email,
        telephone               => $xt_order->primary_phone,
        mobile_telephone        => $xt_order->mobile_phone,
        comment                 => '',
        currency_id             => $xt_order->currency_id,
        channel_id              => $xt_order->channel->id,
        use_external_tax_rate   => $xt_order->use_external_salestax_rate,
        used_stored_card        => $xt_order->used_stored_credit_card,
        ip_address              => $xt_order->customer_ip,
        placed_by               => $xt_order->placed_by,
        sticker                 => $xt_order->sticker,
        order_status_id         => $ORDER_STATUS__ACCEPTED,
    } ), 'The order fields all match' );

    my $invoice_address = { $db_order->invoice_address->get_columns };

    my $address_date = delete $invoice_address->{last_modified};

    # Comparing the date seperatley, due to timezone weirdness. the schema
    # datetime_parser would format the timezone with minutes, DBIx::Class
    # would not.
    ok( ! DateTime->compare(
            $self->{schema}
                ->storage
                ->datetime_parser
                ->parse_datetime( $address_date ),
            $address->last_modified
        ), 'Address last_modified date is correct'
    );

    cmp_deeply( $invoice_address, superhashof( {
        first_name      => $name->first_name,
        last_name       => $name->last_name,
        address_line_1  => $address->line_1,
        address_line_2  => $address->line_2,
        address_line_3  => $address->line_3,
        towncity        => $address->town,
        county          => $address->county,
        country         => $address->country->country,
        postcode        => $address->postcode,
        address_hash    => $xt_order->address_hash( 'billing' ),
        urn             => $address->urn->as_string,
    } ), 'The address fields all match' );

    # Finally, return the new order.

    return $db_order;

}

=head2 test_add_order_tenders

Test the add_order method.

Make sure the tenders are handled correctly.

=cut

sub test_add_order_tenders : Tests {
    my $self = shift;

    $self->{schema}->txn_do( sub {

        foreach my $channel ( Test::XTracker::Data->get_enabled_channels->all ) {

            note 'Testing for channel: ' . $channel->name;

            my $order;

            # Note: We have to specify an id instead of relying on the sequence
            # because the sequence will be removed from XT at some point - product
            # and voucher ids in the real system are generated by fulcrum and
            # so any sequence in XT is irrelevant.
            my $voucher_id = Test::XTracker::Data->next_id([qw{voucher.product product}]);

            # We need a valid voucher code, so create one.
            my $voucher = $self->{schema}->resultset('Voucher::Code')->find_or_create( {
                code            => 'TEST_VOUCHER_' . $channel->web_name,
                voucher_product => {
                    id                       => $voucher_id,
                    name                     => 'Test Voucher',
                    operator_id              => $APPLICATION_OPERATOR_ID,
                    channel_id               => $channel->id,
                    value                    => 1,
                    currency_id              => $self->{schema}->resultset('Public::Currency')->first->id,
                    is_physical              => 0,
                    disable_scheduled_update => 0,
                },
            } );
            note $voucher->voucher_product->id;

            isa_ok( $voucher, 'XTracker::Schema::Result::Voucher::Code' );

            note 'Testing with no voucher_code';

            # Create the order.
            $order = $self->_add_order_ok( {
                channel => $channel,
                tender  => { type => 'Store Credit', voucher_code => '' },
            } );

            cmp_ok( $order->tenders->count, '==', 1, 'One tender created' );
            ok( ! $order->tenders->first->voucher_code_id, 'No voucher code' );

            note 'Testing with existing voucher_code';

            # Create the order.
            $order = $self->_add_order_ok( {
                channel => $channel,
                tender  => { type => 'Voucher Credit', voucher_code => $voucher->code },
            } );

            cmp_ok( $order->tenders->count, '==', 1, 'One tender created' );
            cmp_ok( $order->tenders->first->voucher_code_id, '==', $voucher->id, 'Correct voucher' );

            note 'Testing with unknown voucher_code';

            my $orders_tender = $self->{schema}->resultset('Orders::Tender');
            my $tender_count = $orders_tender->count;

            # Create the order.
            throws_ok(
                sub {
                    $order = $self->_add_order_ok( {
                        channel => $channel,
                        tender  => { type => 'Voucher Credit', voucher_code => 'XX NON-EXISTENT XX' },
                     } )
                },
                qr/couldn't find voucher with code 'XX NON-EXISTENT XX' on the system/,
                'add_order dies as expected'
            );

            cmp_ok( $tender_count, '==', $orders_tender->count, 'No tenders created' );

        }

    } );

}

=head2 test_add_order_language_preference

Test the add_order method.

Make sure the language_preference is handled correctly.

=cut

sub test_add_order_language_preference : Tests {
    my $self = shift;

    $self->{schema}->txn_do( sub {

        my $language = $self->{schema}
            ->resultset('Public::Language')
            ->first;

        isa_ok( $language, 'XTracker::Schema::Result::Public::Language' );

        foreach my $channel ( Test::XTracker::Data->get_enabled_channels->all ) {

            note 'Testing for channel: ' . $channel->name;

            foreach my $preference ( undef, $language->code ) {

                # Create the order.
                my $order = $self->_add_order_ok( {
                    channel => $channel,
                    order   => { language_preference => $preference },
                } );

                if ( $preference ) {

                    cmp_ok(
                        $order->customer_language_preference_id,
                        '==',
                        $language->id,
                        'customer_language_preference_id is set correctly'
                    );

                } else {

                    ok(
                        !defined $order->customer_language_preference_id,
                        'customer_language_preference_id is not set'
                    );

                }

            }

        }

    } );

}


=head2 test_add_order_source_app

Test the add_order method.

Make sure the source_app_name and source_app_version are handled correctly.

=cut

sub test_add_order_source_app : Tests {
    my $self = shift;

    $self->{schema}->txn_do( sub {

        foreach my $channel ( Test::XTracker::Data->get_enabled_channels->all ) {

            note 'Testing for channel: ' . $channel->name;

            my %tests = (
                'No app name or version' => { },
                'Only an app name' => {
                    source_app_name => 'source_app_name',
                },
                'Only an app version' => {
                    source_app_version => 'source_app_version',
                },
                'Both an app name and version' => {
                    source_app_name => 'source_app_name',
                    source_app_version => 'source_app_version',
                }
            );

            while ( my ( $name, $test ) = each %tests ) {

                # Create the order.
                my $order = $self->_add_order_ok( {
                    channel => $channel,
                    order   => $test,
                } );

                if ( keys %$test ) {

                    my $order_attribute = $order->order_attribute;
                    isa_ok( $order_attribute, "XTracker::Schema::Result::Public::OrderAttribute", "Order Attribute Record is what it should be");

                    cmp_ok(
                        $order_attribute->source_app_name // '',
                        'eq',
                        $test->{source_app_name} // '',
                        'Got the correct source_app_name'
                    );

                    cmp_ok(
                        $order_attribute->source_app_version // '',
                        'eq',
                        $test->{source_app_version} // '',
                        'Got the correct source_app_version'
                    );

                } else {

                    ok( ! defined $order->order_attribute, 'There is no order attribute' );

                }

            }

        }

    } );

}

sub test_has_new_high_value_action : Tests {
    my $self = shift;

    foreach my $channel ( Test::XTracker::Data->get_enabled_channels->all ) {

        my $customer = Test::XTracker::Data->find_customer( {
            channel_id => $channel->id,
        } );

        ok( $customer, "I have a customer ..." );

        # Test that we get FALSE when there are no high value records.
        $customer->customer_actions->delete;
        cmp_ok( $customer->customer_actions->count, '==', 0, 'Customer has no customer_actions records' );
        ok( ! $customer->has_new_high_value_action,'Customer has no "New High Value" flag' );

        # Test that we get TRUE when there is one high value record.
        $customer->customer_actions->create( {
            operator_id             => $APPLICATION_OPERATOR_ID,
            customer_action_type_id => $PUBLIC_CUSTOMER_ACTION_TYPE__NEW_HIGH_VALUE,
        } );
        cmp_ok( $customer->customer_actions->count, '==', 1, 'Customer has ONE customer_actions record' );
        ok( $customer->has_new_high_value_action, 'Customer has a "New High Value" flag' );

        # Test that we still get TRUE when there is more than one high value record.
        $customer->customer_actions->create( {
            operator_id             => $APPLICATION_OPERATOR_ID,
            customer_action_type_id => $PUBLIC_CUSTOMER_ACTION_TYPE__NEW_HIGH_VALUE,
        } );
        cmp_ok( $customer->customer_actions->count, '==', 2, 'Customer has TWO customer_actions records' );
        ok( $customer->has_new_high_value_action, 'Customer STILL has a "New High Value" flag' );

    }
}

sub test_set_new_high_value_action : Tests {
    my $self = shift;

    foreach my $channel ( Test::XTracker::Data->get_enabled_channels->all ) {

        my $customer = Test::XTracker::Data->find_customer( {
            channel_id => $channel->id,
        } );

        ok( $customer, "I have a customer ..." );

        my $is_customer_number = $customer->is_customer_number;

        # Create a SubRef, as we call the same thing twice.
        my $set_new_high_value_action = sub {
            $customer->set_new_high_value_action( {
                operator_id => $APPLICATION_OPERATOR_ID,
            } );
        };

        # Make sure the customer has no associated customer actions.
        $customer->customer_actions->delete;

        # Check the table count.
        cmp_ok( $customer->customer_actions->count, '==', 0, 'Customer has no customer_actions records' );

        # The method should succeed when there are no 'New High Value' records for
        # this customer.
        lives_ok(
            sub{ $set_new_high_value_action->() }, # needs a specific sub{} statement.
            'set_new_high_value_action did not die with no existing actions'
        );

        # Check the table count.
        cmp_ok( $customer->customer_actions->count, '==', 1, 'Customer has ONE customer_actions record' );

        # The method should fail when there are existing 'New High Value' records for
        # this customer.
        throws_ok(
            sub{ $set_new_high_value_action->() }, # needs a specific sub{} statement.
            qr/Customer $is_customer_number already has a 'New High Value' flag/,
            'set_new_high_value_action died with existing actions'
        );

        # Check the table count.
        cmp_ok( $customer->customer_actions->count, '==', 1, 'Customer STILL has ONE customer_actions record' );

    }
}

sub test_get_card_token : Tests {
    my $self = shift;

    # Grab a customer.
    my $customer = Test::XTracker::Data->find_customer( {
        channel_id => Test::XTracker::Data->get_local_channel->id,
    } );

    isa_ok( $customer, 'XTracker::Schema::Result::Public::Customer', 'The new customer' );

    # Update customer record to have a valid URN.
    $customer->update( {
        account_urn => 'urn:nap:account:fe9ab17a-85b7-11e2-9f14-b4b52f51d098',
    } );

    # Calling the method returns the correct token.
    is(
        $customer->get_card_token,
        'ae51266b7f88867bf8de9749d0905683',
        'Card token is correct for a valid URN'
    );

    # Update customer record to have the magic urn which will return a 404.
    $customer->update( {
        account_urn => 'urn:nap:account:NONE',
    } );

    # Now make sure the method dies with the right error.
    throws_ok(
        sub{ $customer->get_card_token },
        qr/\[Seaview Client Error\] 404 : Account does not have a card token/,
        'get_card_token dies as expected for a non existent card token'
    );

    # Update customer record to have no URN.
    $customer->update( {
        account_urn => '',
    } );

    is(
        $customer->get_card_token,
         undef,
        'Card token is undef as expected'
    );

}


sub test_create_card_token : Tests {
    my $self = shift;

    # Grab a customer.
    my $customer = Test::XTracker::Data->find_customer( {
        channel_id => Test::XTracker::Data->get_local_channel->id,
    } );

    isa_ok( $customer, 'XTracker::Schema::Result::Public::Customer', 'The new customer' );

    # Update the customer record to have a valid URN.
    $customer->update( {
        account_urn => 'urn:nap:account:fe9ab17a-85b7-11e2-9f14-b4b52f51d098',
    } );

    # Make sure the mock PSP returns the correct token.
    $self->{payment}->get_new_card_token;

    # Now make sure the method returns a valid card token.
    is(
        $customer->create_card_token,
        'ae51266b7f88867bf8de9749d0905683',
        'Card token is correct for a valid URN'
    );

    # Turn on mocking for this test.
    $self->{payment}->with_mock_lwp( sub {

        # Cache the original token, so we can restore it later and not
        # break other tests.
        my $old_token = $self->{payment}->new_card_token;

        # Now make the PSP returns no token.
        $self->{payment}->set_new_card_token( undef );
        $self->{payment}->get_new_card_token;

        # Which should result in the method dying.
        throws_ok(
            sub{ $customer->create_card_token },
            qr/Problem creating card token/,
            'create_card_token dies as expected for a non existent card token'
        );

        # Now restore the original token.
        $self->{payment}->set_new_card_token( $old_token );

    } );

}

sub test_get_or_create_card_token : Tests {
    my $self = shift;

    # Grab a customer.
    my $customer = Test::XTracker::Data->find_customer( {
        channel_id => Test::XTracker::Data->get_local_channel->id,
    } );

    isa_ok( $customer, 'XTracker::Schema::Result::Public::Customer', 'The new customer' );

    # Update customer record to have a valid URN.
    $customer->update( {
        account_urn => 'urn:nap:account:fe9ab17a-85b7-11e2-9f14-b4b52f51d098',
    } );

    # Make sure the mock PSP returns the correct token.
    $self->{payment}->get_new_card_token;

    # Now make sure the method returns a valid card token.
    is(
        $customer->get_or_create_card_token,
        'ae51266b7f88867bf8de9749d0905683',
        'Card token is correct for a valid URN'
    );

    # Instead of relying on the URN to determine what response will be
    # returned, we'll request specific responses in sequence.
    $self->{user_agent}->add_to_response_queue( 'card_token_GET', 404 );
    $self->{user_agent}->add_to_response_queue( 'card_token_GET', 200 );

    # This should still work, as it will call create_card_token (as a
    # result of the 404 - Not Found).
    is(
        $customer->get_or_create_card_token,
        'ae51266b7f88867bf8de9749d0905683',
        'Card token is correct for a valid URN'
    );

    # Now make sure that when a different HTTP error is thrown, we get
    # a specific error message from the method.
    $self->{user_agent}->add_to_response_queue( 'card_token_GET', 418 );
    $self->{user_agent}->add_to_response_queue( 'card_token_GET', 200 );

    # This should fail with a method specific error.
    throws_ok(
        sub{ $customer->get_or_create_card_token },
        qr{Problem creating card token},
        'get_or_create_card_token fails as expected'
    );

}

=head2 test_calculate_customer_value

Currently being tested in t/20-units/database/customer_value.t as part of it's
related methods.

=head2 test_get_customer_value_from_service

=cut

sub test_get_customer_value_from_service : Tests {
    my $self = shift;

    # Grab a customer.
    my $customer = Test::XTracker::Data->create_dbic_customer( {
        channel_id => Test::XTracker::Data->get_local_channel->id,
    } );

    # Get the customer's URN.
    my $urn = $customer->account_urn;
    $urn =~ s/urn:nap:account://;

    $self->{user_agent}->clear_response_queue('customer_bosh_GET');
    $self->{user_agent}->add_to_response_queue( customer_bosh_GET => 200 );
    $self->{user_agent}->clear_last_customer_bosh_GET_request;

    my $bosh_key = 'customer_value_'
      . config_var('DistributionCentre', 'name');

    cmp_ok( $customer->get_customer_value_from_service,
        'eq',
        'Test Value',
        'The result of calling "get_customer_value_from_service" is "Test Value"' );

    cmp_deeply( $self->{user_agent}->get_last_customer_bosh_GET_request, [
        # Should be an HTTP::Request object.
        methods(
            content => '',
            uri     => methods(
                as_string => re( qr|/bosh/account/$urn/customer_value| ),
            ),
        ),
        {
            urn => $urn,
            key => $bosh_key,
        } ],
        'The GET request to /bosh/account is correct' );

}

=head2 test__update_customer_value_in_service__when_disabled

Make sure nothing happens when the config setting is disabled.

=cut

sub test__update_customer_value_in_service__when_disabled : Tests {
    my $self = shift;

    $self->_set_system_config_customer_value( 'Off' );

    # Grab a customer.
    my $channel  = Test::XTracker::Data->get_local_channel;
    my $customer = Test::XTracker::Data->create_dbic_customer( {
        channel_id => $channel->id,
    } );

    # Delete all the related logs.
    $customer->customer_service_attribute_logs->delete;

    $self->{user_agent}->clear_response_queue('customer_bosh_PUT');
    $self->{user_agent}->add_to_response_queue( customer_bosh_PUT => 200 );
    $self->{user_agent}->clear_last_customer_bosh_PUT_request;

    ok( ! $customer->update_customer_value_in_service,
        'update_customer_value_in_service returns undef when disabled' );

    ok( ! $self->{user_agent}->get_last_customer_bosh_PUT_request,
        'The PUT request to /bosh/account was undef (not called)' );

    cmp_ok( $customer->customer_service_attribute_logs->count,
        '==',
        0,
        'There are no log entries' );

}

=head2 test__update_customer_value_in_service

Make sure the method is called correctly when the config setting is enabled.

=cut

sub test__update_customer_value_in_service__when_enabled : Tests {
    my $self = shift;

    $self->_set_system_config_customer_value( 'On' );

    # Grab a customer.
    my $channel  = Test::XTracker::Data->get_local_channel;
    my $customer = Test::XTracker::Data->create_dbic_customer( {
        channel_id => $channel->id,
    } );

    # Delete all the related logs.
    $customer->customer_service_attribute_logs->delete;

    # Get the customer's URN.
    my $full_urn = $customer->account_urn;
    ( my $urn = $full_urn ) =~ s/urn:nap:account://;

    my $data = {
        $channel->id => {
            spend => [
                {
                    net         => { value   => 100 },
                    currency    => 'GBP',
                },
                {
                    net         => { value   => 200 },
                    currency    => 'USD',
                }
            ],
        }
    };

    $self->_test__update_customer_value_in_service__with_channel_id_mismatch(
        $customer, $data );

    $self->_test__update_customer_value_in_service__without_parameters(
        $customer, $data, $full_urn, $urn );

    # Override the DateTime 'now' method so it returns a different date the
    # second time the log entry is created.
    my $date_time = qtakeover 'DateTime';
    $date_time->override(
        now => sub {
            # As described in the DateTime documentation, "DateTime->now" is
            # the same as "DateTime->from_epoch( epoch => time )". So we use
            # this to prevent recursive calls of 'now'.
            return DateTime->from_epoch( epoch => time )->add( hours => 1 ) } );

    $self->_test__update_customer_value_in_service__with_parameters(
        $customer, $data, $full_urn, $urn );

}

sub _test__update_customer_value_in_service__with_channel_id_mismatch {
    my ($self,  $customer, $data ) = @_;

    subtest 'Test update_customer_value_in_service With Channel ID Mismatch' => sub {

        $data = {
            $customer->channel->id + 1 => $data->{ $customer->channel->id },
        };

        throws_ok(
            sub { $customer->update_customer_value_in_service( $data ) },
            qr/\[update_customer_value_in_service\] Channel ID Mismatch/,
            'Got "Channel ID Mismatch" error for a different channel' );

    };

}

sub _test__update_customer_value_in_service__without_parameters {
    my ($self,  $customer, $data, $full_urn, $urn ) = @_;

    subtest 'Test update_customer_value_in_service Without Parameters' => sub {

        # Override the XTracker::Schema::Result::Public::Customer 'calculate_customer_value'
        # method to return know data.
        my $calculate_customer_value = qtakeover 'XTracker::Schema::Result::Public::Customer';
        $calculate_customer_value->override(
            calculate_customer_value => sub { return $data } );

        $self->_test__update_customer_value_in_service__make_call(
            $customer,
            $full_urn,
            $urn,
            [['GBP',10000],['USD',20000]],
            'Only one log entry was created',
            ignore() );

    };

}

sub _test__update_customer_value_in_service__with_parameters {
    my ($self,  $customer, $data, $full_urn, $urn ) = @_;

    subtest 'Test update_customer_value_in_service With Parameters' => sub {

        my $last_timestamp = $customer
            ->customer_service_attribute_logs
            ->first
            ->last_sent;

        local $data->{ $customer->channel->id }->{spend}->[0]->{currency}       = 'EUR';
        local $data->{ $customer->channel->id }->{spend}->[0]->{net}->{value}   = 300;
        local $data->{ $customer->channel->id }->{spend}->[1]->{currency}       = 'AUD';
        local $data->{ $customer->channel->id }->{spend}->[1]->{net}->{value}   = 400;

        $self->_test__update_customer_value_in_service__make_call(
            $customer,
            $full_urn,
            $urn,
            [['EUR',30000],['AUD',40000]],
            'There is STILL only one log entry',
            code( sub { shift->epoch > $last_timestamp->epoch } ),
            $data );

    };

}

sub _test__update_customer_value_in_service__make_call {
    my ($self,  $customer, $full_urn, $urn, $expected, $log_message, $last_sent_check, @parameters ) = @_;

    $self->{user_agent}->clear_response_queue('customer_bosh_PUT');
    $self->{user_agent}->add_to_response_queue( customer_bosh_PUT => 200 );
    $self->{user_agent}->clear_last_customer_bosh_PUT_request;

    my $bosh_key = 'customer_value_'
      . config_var('DistributionCentre', 'name');

    cmp_ok( $customer->update_customer_value_in_service( @parameters ),
        'eq',
        "${full_urn}:bosh:${bosh_key}",
        "The result of calling 'update_customer_value_in_service' is '${full_urn}:bosh:${bosh_key}'" );

    my $expected_data = {
        'channel' => $customer->channel->web_name,
        'total_spend' =>
          [ map { {'spend_currency' => $_->[0], 'spend' => $_->[1]} } @$expected ],
    };

    my $last_bosh_PUT_request
      = $self->{user_agent}->get_last_customer_bosh_PUT_request;

    my $request_content = decode_json $last_bosh_PUT_request->[0]->content;

    cmp_deeply( $request_content, $expected_data, 'PUT content looks correct');

    cmp_deeply( $last_bosh_PUT_request, [
        # Should be an HTTP::Request object.
        methods(
            uri     => methods(
                as_string => re( qr|/bosh/account/$urn/$bosh_key| ),
            ),
        ) , {
            urn => $urn,
            key => $bosh_key,
        } ],
        'The PUT request to /bosh/account is correct' );

    cmp_ok( $customer->customer_service_attribute_logs->count,
        '==',
        1,
        $log_message );

    cmp_deeply( { $customer->customer_service_attribute_logs->first->get_inflated_columns }, superhashof( {
            customer_id                 => $customer->id,
            service_attribute_type_id   => $SERVICE_ATTRIBUTE_TYPE__CUSTOMER_VALUE,
            last_sent                   => $last_sent_check,
        } ),
        ' .. and it is correct' );

}

sub _set_system_config_customer_value {
    my ($self,  $value ) = @_;

    $self->schema->resultset('SystemConfig::ConfigGroup')
        ->find( {
            name        => 'SendToBOSH',
            channel_id  => undef } )
        ->find_related( config_group_settings => {
            setting => 'Customer Value' } )
        ->update( {
            value => $value } );

}

=head2 test_get_pre_order_discount_percent

This tests the 'get_pre_order_discount_percent' method that returns the
percentage discount a Customer should have for a Pre-Order.

=cut

sub test_get_pre_order_discount_percent : Tests() {
    my $self = shift;

    # get a random Customer
    my ( $customer ) = values %{ $self->{customers} };
    my $channel      = $customer->channel;

    my @category     = $self->rs('Public::CustomerCategory')
                              ->search( {
            category => { '!=' => 'None' },
    } )->all;

    my %tests = (
        "'can_apply_discount' flag is Off but with Categories that have defaults" => {
            setup => {
                use_category_for_customer => $category[0],
                can_apply_discount        => 0,
                categories => [
                    # category, discount
                    [ $category[0], 10 ],
                    [ $category[1], 10 ],
                    [ $category[2], 10 ],
                ],
            },
            expect => {
                discount => undef,
            },
        },
        "'can_apply_discount' flag is On but with NO Categories" => {
            setup => {
                use_category_for_customer => $category[0],
                can_apply_discount        => 1,
                categories => undef,
            },
            expect => {
                discount => undef,
            },
        },
        "Discount is On but Customer's Category is NOT one of the ones in Config" => {
            setup => {
                use_category_for_customer => $category[0],
                can_apply_discount        => 1,
                categories => [
                    # category, discount
                    [ $category[1], 10 ],
                    [ $category[2], 10 ],
                    [ $category[3], 10 ],
                ],
            },
            expect => {
                discount => undef,
            },
        },
        "Discount is On and Customer' Category is in the Config" => {
            setup => {
                use_category_for_customer => $category[0],
                can_apply_discount        => 1,
                categories => [
                    # category, discount
                    [ $category[0], 10 ],
                    [ $category[1], 20 ],
                    [ $category[2], 30 ],
                ],
            },
            expect => {
                discount => 10,
            },
        },
        "Discount is On and Customer' Category is in the Config but is set to ZERO" => {
            setup => {
                use_category_for_customer => $category[0],
                can_apply_discount        => 1,
                categories => [
                    # category, discount
                    [ $category[0], 0 ],
                    [ $category[1], 20 ],
                    [ $category[2], 30 ],
                ],
            },
            expect => {
                discount => 0,
            },
        },
        "Discount is On and Customer' Category is in the Config and is a Decimal" => {
            setup => {
                use_category_for_customer => $category[0],
                can_apply_discount        => 1,
                categories => [
                    # category, discount
                    [ $category[0], 8.5 ],
                    [ $category[1], 20 ],
                    [ $category[2], 30 ],
                ],
            },
            expect => {
                discount => 8.5,
            },
        },
        "Discount is On with only ONE Category set in Config" => {
            setup => {
                use_category_for_customer => $category[0],
                can_apply_discount        => 1,
                categories => [
                    # category, discount
                    [ $category[0], 0.75 ],
                ],
            },
            expect => {
                discount => 0.75,
            },
        },
        "Discount is On with only ONE Category set in Config and not the Customers" => {
            setup => {
                use_category_for_customer => $category[0],
                can_apply_discount        => 1,
                categories => [
                    # category, discount
                    [ $category[1], 1.75 ],
                ],
            },
            expect => {
                discount => undef,
            },
        },
    );

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test    = $tests{ $label };
        my $setup   = $test->{setup};
        my $expect  = $test->{expect};

        my $cust_category = delete $setup->{use_category_for_customer};
        $customer->discard_changes->update( {
            category_id => $cust_category->id,
        } );

        #
        # build & set the System Config Arguments
        #
        my $set_categories = delete $setup->{categories};
        # all other arguments should be
        # used to set-up the System Config
        my $config_args = {
            set_category => undef,
            %{ $setup },
        };
        if ( $set_categories ) {
            $config_args->{set_category} = {
                map { $_->[0]->category => $_->[1] } @{ $set_categories }
            };
        }
        Test::XTracker::Data->set_pre_order_discount_settings( $channel, $config_args );

        my $got = $customer->get_pre_order_discount_percent;
        if ( defined $expect->{discount} ) {
            is( $got, $expect->{discount}, "Got the Expected Discount returned" );
        }
        else {
            ok( !defined $got, "Got Expected 'undef' Discount returned" );
        }
    }
}

=head2 test_logging_of_replacing_card_tokens

Tests that when replacing a Card Token for a Customer on their Seaview Account
that a log entry is made to the xTracker Log. Do this by Mocking Log4perl to
capture Log Messages and then cheking them.

=cut

sub test_logging_of_replacing_card_tokens : Tests() {
    my $self = shift;

    my $customer = $self->{customers}{ Test::XTracker::Data->get_local_channel->id };

    # define two anonymous sub-routines that can be called
    # within the Mocked 'XT::Net::Seaview::Client->get_card_token'
    # to throw an exception or be a noop and allow execution to
    # continue, throwing an error won't make the tests die but that
    # it will trigger the Try/Catch clauses within other methods
    my $throw_get_card_token_sub = sub {    # die with an expected exception
         XT::Net::Seaview::Exception::ClientError->throw( {
            code  => HTTP_NOT_FOUND,
            error => "TEST TOLD ME TO",
         } );
    };
    # just die without an expected exception goes down a different code path
    my $die_get_card_token_sub  = sub { die "TEST TOLD ME TO"; };
    my $noop_get_card_token_sub = sub { return; };


    # define the Tests to run, in the setup the 'mock_get_card_token' Array Ref
    # represents what should happen to the Mocked 'get_card_token' method each
    # time it is called throughout the code path, so for example the first time it
    # gets called it can die/throw an execption and the second time it can proceed
    my %tests = (
        "Check when 'get_or_create_card_token' fails to get anything back from Seaview including a usable Exception" => {
            setup => {
                method_to_test      => 'get_or_create_card_token',
                mock_get_card_token => [
                    $die_get_card_token_sub,
                    $noop_get_card_token_sub,
                ],
            },
            expect => {
                # define the expected Error messages that should be
                # logged in the order that they should be generated
                logs => [
                    { level => 'warn', message => qr/Could not get card token from Seaview/i, no_token_check => 1 },
                    { level => 'info', message => qr/Got from PSP a Card Token/i },
                    { level => 'info', message => qr/replaced Seaview Card Token/i },
                ],
            },
        },
        "Check with 'get_or_create_card_token' when Card Token is Created" => {
            setup => {
                method_to_test      => 'get_or_create_card_token',
                mock_get_card_token => [
                    $throw_get_card_token_sub,
                    $noop_get_card_token_sub,
                ],
            },
            expect => {
                logs => [
                    { level => 'info', message => qr/Got from PSP a Card Token/i },
                    { level => 'info', message => qr/replaced Seaview Card Token/i },
                    { level => 'info', message => qr/Got a new Card Token/i },
                ],
            },
        },
        "Check with 'get_or_create_card_token' when Seaview's Card Token is used - normal operation should have NO Logs" => {
            setup => {
                method_to_test      => 'get_or_create_card_token',
                mock_get_card_token => [
                    $noop_get_card_token_sub,
                ],
            },
            expect => {
                logs => [ ],
            },
        },
        "Check 'get_or_create_card_token' when Customer doesn't have a URN" => {
              setup => {
                method_to_test => 'get_or_create_card_token',
                customer_urn   => undef,
            },
            expect => {
                logs => [
                    { level => 'warn', message => qr/Could not get card token from Seaview/i, no_token_check => 1 },
                    { level => 'info', message => qr/Got from PSP a Card Token/i,  },
                    { level => 'warn', message => qr/No Seaview Account to update with Card Token/i },
                ],
            },
        },
        "Check 'create_card_token' when New Token can't be got from PSP" => {
            setup => {
                method_to_test => 'create_card_token',
                psp_card_token => undef,
            },
            expect => {
                logs => [
                    { level => 'info',  message => qr/Got from PSP a Card Token/i,   no_token_check => 1 },
                    { level => 'fatal', message => qr/Problem creating card token/i, no_token_check => 1 },
                ],
                to_die => 1,
            },
        },
        "Check 'create_card_token' when Seaview can't be updated with a New Token" => {
            setup => {
                method_to_test      => 'create_card_token',
                mock_get_card_token => [
                    $throw_get_card_token_sub,
                ],
            },
            expect => {
                logs => [
                    { level => 'info', message => qr/Got from PSP a Card Token/i },
                    { level => 'warn', message => qr/Couldn't Replace Seaview with Card Token/i },
                ],
            },
        },
        "Check 'create_card_token' when Seaview can be updated with a New Token" => {
            setup => {
                method_to_test      => 'create_card_token',
                mock_get_card_token => [
                    $noop_get_card_token_sub,
                ],
            },
            expect => {
                logs => [
                    { level => 'info', message => qr/Got from PSP a Card Token/i },
                    { level => 'info', message => qr/replaced Seaview Card Token/i },
                ],
            },
        },
        "Check 'create_card_token' when Customer doesn't have a URN" => {
            setup => {
                method_to_test => 'create_card_token',
                customer_urn   => undef,
            },
            expect => {
                logs => [
                    { level => 'info', message => qr/Got from PSP a Card Token/i },
                    { level => 'warn', message => qr/No Seaview Account to update with Card Token/i },
                ],
            },
        },
    );

    # just mock 'XT::Domain::Payment->get_new_card_token'
    my $mocked_psp_new_card_token = $self->{payment}->new_card_token;
    my $mocked_domain_payment     = qtakeover 'XT::Domain::Payment' => ();
    $mocked_domain_payment->override(
        get_new_card_token => sub {
            note "-----> IN MOCKED 'XT::Domain::Payment->get_card_token' method <-----";
            return {
                customerCardToken => $mocked_psp_new_card_token,
                message           => undef,
                error             => undef,
            };
        },
    );

    # set the defaults for Card Token and Customer URN
    my $default_new_card_token = $mocked_psp_new_card_token;
    my $default_customer_urn   = 'urn:nap:account:fe9ab17a-85b7-11e2-9f14-b4b52f51d098';

    # mock the 'XT::Net::Seaview::Client->get_card_token' method and
    # use this Array to get what it needs to do within each test
    my @tell_get_card_token_what_to_do = ();
    my $mocked_seaview_client = qtakeover 'XT::Net::Seaview::Client' => ();
    $mocked_seaview_client->override(
        get_card_token => sub {
            note "-----> IN MOCKED 'XT::Net::Seaview::Client->get_card_token' method <-----";
            my $what_to_do = shift @tell_get_card_token_what_to_do;
            $what_to_do->();
            return $mocked_seaview_client->original('get_card_token')->( @_ );
        },
    );

    # Mock 'Log::Log4perl::Logger'
    my @log_levels = qw( trace debug info warn error fatal );
    my $mocked_logger = qtakeover 'Log::Log4perl::Logger' => ();
    my @logged_messages;
    foreach my $level ( @log_levels ) {
        $mocked_logger->override(
            $level => sub {
                note "-----> IN MOCKED 'Log::Log4perl::Logger->${level}' method <-----";
                # get the caller of the method (go one back to get out of 'Mock::Quick'
                my @caller = caller(1);
                # only log messages by 'Public::Customer'
                push @logged_messages, { level => $level, message => $_[1] }
                            if ( $caller[0] =~ /Public::Customer$/ );
                return $mocked_logger->original( $level )->( @_ );
            },
        );
    }

    # the regex to match against an obscured Card Token
    my $card_token_re = qr/'[0-9,a-z]{2}\*+[0-9,a-z]{4}'/i;

    foreach my $label ( keys %tests ) {
        note "TESTING: ${label}";
        my $test   = $tests{ $label };
        my $setup  = $test->{setup};
        my $expect = $test->{expect};

        # set-up what the Mocked method should do for this test
        @tell_get_card_token_what_to_do = @{ $setup->{mock_get_card_token} // [] };

        # set the PSP Card Token, use the default unless the test explictly wants it to be 'undef'
        my $new_psp_card_token = $setup->{psp_card_token};
        $new_psp_card_token  //= $default_new_card_token    unless ( exists( $setup->{psp_card_token} ) );
        # set what the Mocked 'XT::Domain::Payment->get_new_card_token' will do
        $mocked_psp_new_card_token = $new_psp_card_token;

        # set the Customer URN, use the default unless the test explictly wants it to be 'undef'
        my $cust_urn = $setup->{customer_urn};
        $cust_urn  //= $default_customer_urn                unless ( exists( $setup->{customer_urn} ) );
        $customer->discard_changes->update( { account_urn => $cust_urn } );

        # clear what's already been Logged
        @logged_messages = ();

        # call the method to be tested on the Customer record
        my $method_to_call = $setup->{method_to_test};
        if ( $expect->{to_die} ) {
            dies_ok {
                $customer->$method_to_call();
            } "Called method '${method_to_call}' and die'd as expected";
        }
        else {
            lives_ok {
                $customer->$method_to_call();
            } "Called method '${method_to_call}'";
        }

        my @expected_logs   = @{ $expect->{logs} };
        my $got_number_logs = scalar @logged_messages;
        cmp_ok( $got_number_logs, '==', scalar( @expected_logs ),
                            "Got expected number of Log Messages" ) or diag "=====> " . p( @logged_messages );

        foreach my $number ( 1..$got_number_logs ) {
            my $got_log      = shift @logged_messages;
            my $expected_log = shift @expected_logs;

            is( $got_log->{level}, $expected_log->{level}, "Log - ${number} - Level is as Expected" );
            my $exp_msg = $expected_log->{message};
            like( $got_log->{message}, qr/${exp_msg}/i, "Log - ${number} - Message is as Expected" );

            if ( $expected_log->{no_token_check} ) {
                unlike( $got_log->{message}, qr/${card_token_re}/i, "Log - ${number} - Message doesn't have a Card Token in it" );
            }
            else {
                like( $got_log->{message}, qr/${card_token_re}/i, "Log - ${number} - Message has a Card Token in it" );
            }
        }
    }

    #
    # un-mock the various methods & classes
    #

    foreach my $level ( @log_levels ) {
        $mocked_logger->restore( $level );
    }
    $mocked_logger = undef;

    $mocked_domain_payment->restore('get_new_card_token');
    $mocked_domain_payment = undef;

    $mocked_seaview_client->restore('get_card_token');
    $mocked_seaview_client = undef;
}

Test::Class->runtests;
