package Test::XTracker::Schema::Result::Public::Orders;

use NAP::policy     qw( test class );

BEGIN {
    extends 'NAP::Test::Class';
    with $_ for qw{ Test::Role::WithSchema };
};

=head1 NAME

Test::XTracker::Schema::Result::Public::Orders

=head1 DESCRIPTION

Test XTracker::Schema::Result::Public::Orders

=cut

use XTracker::Config::Local qw( config_var );
use Test::XTracker::Data::Order;
use Test::XTracker::Data::PreOrder;
use Test::XTracker::Data;
use Test::XTracker::Mock::PSP;
use XTracker::Constants         qw( :application );
use XTracker::Constants::FromDB qw(
    :flag
    :order_status
    :shipment_item_status
    :shipment_status
    :shipment_type
    :security_list_status
    :shipment_item_returnable_state
    :shipment_item_on_sale_flag
    :shipment_hold_reason
    :orders_payment_method_class
    :renumeration_type
);

use XTracker::Database::Order;
use XTracker::Database::Shipment;
use XTracker::Database::Currency        qw( get_currencies_from_config get_local_conversion_rate );
use XTracker::Utilities                 qw( d2 );
use Test::XTracker::Mock::PSP;

=head1 METHODS

=head2 create_new_order_data

=cut

sub create_new_order_data {
    my ( $self, $args ) = @_;

    my $address = Test::XTracker::Data->create_order_address_in('current_dc');
    my @channels = Test::XTracker::Data->get_enabled_channels->all;
    my $order_data = Test::XTracker::Data::Order->create_new_order( {
            channel => $channels[0],
            address => $address,
            %{ $args // {} },
    } );

    return $order_data;
}

=head2 create_new_order

=cut

sub create_new_order {
    my ( $self, $args ) = @_;
    return $self->create_new_order_data( $args )->{order_object};
}

=head1 PRIVATE METHODS

=head2 _create_order

=cut

sub _create_order {
    my ( $args ) = @_;
    my $pids_to_use = $args->{pids_to_use};
    my $base        = $args->{base} || '';
    my ($order) = Test::XTracker::Data->apply_db_order({
        pids => $pids_to_use,
        base => $base,
    });

    note "Order Nr/Id: ".$order->order_nr."/".$order->id;
    note "Shipment Id: ".$order->shipments->first->id;

    return $order;
}

=head1 TESTS

=head2 startup

=cut

sub startup : Test( startup => no_plan ) {
    my $self = shift;
    $self->SUPER::startup;

    $self->{schema} = Test::XTracker::Data->get_schema();
    $self->{dbh}    = $self->{schema}->storage->dbh;

    Test::XTracker::Mock::PSP->use_all_mocked_methods();    # get the PSP Mock in a known state

    $self->{payment_method}{creditcard} =
        $self->rs('Orders::PaymentMethod')->search( {
            payment_method_class_id => $ORDERS_PAYMENT_METHOD_CLASS__CARD,
        } )->first;
    $self->{payment_method}{thirdparty} =
        $self->rs('Orders::PaymentMethod')->search( {
            payment_method_class_id => $ORDERS_PAYMENT_METHOD_CLASS__THIRD_PARTY_PSP,
        } )->first;
}

=head2 test_setup

=cut

sub test_setup : Tests( setup => no_plan ) {
    my $self = shift;

    # Start from a default state.
    Test::XTracker::Mock::PSP->set_payment_method('default');
    Test::XTracker::Mock::PSP->set_third_party_status('');
    Test::XTracker::Mock::PSP->set_card_history_to_default;

}

=head2 teardown

=cut

sub teardown : Test( teardown => no_plan ) {
    my $self = shift;
    $self->SUPER::teardown;

    # prevent other tests from maybe failing
    Test::XTracker::Mock::PSP->set_payment_method('default');
    Test::XTracker::Mock::PSP->set_third_party_status('');
    Test::XTracker::Mock::PSP->set_card_history_to_default;

    # prevent other Class tests from failing
    Test::XTracker::Mock::PSP->disable_mock_lwp;
}

=head2 test_shutdown

=cut

sub test_shutdown : Test( shutdown => no_plan ) {
    my $self = shift;
    $self->SUPER::shutdown;

    Test::XTracker::Mock::PSP->use_all_original_methods();
}

=head2 get_total_value_in_local_currency

=cut

sub get_total_value_in_local_currency : Tests {
    my $self = shift;

    # get available currencies for the DC and get
    # their Conversion Rates to the DC's Local Currency
    my $currencies  = get_currencies_from_config( $self->schema );
    foreach my $currency ( @{ $currencies } ) {
        $currency->{conversion_rate}    = get_local_conversion_rate( $self->dbh, $currency->{id} );
    }

    foreach my $channel ( Test::XTracker::Data->get_enabled_channels->all) {
        note "Sales Channel: " . $channel->name;

        my $order_data = Test::XTracker::Data::Order->create_new_order( {
            channel => $channel
        } );

        my $order = $order_data->{order_object};
        ok($order, "I have an order");

        my $shipment    = $order->get_standard_class_shipment;

        foreach my $currency ( @{ $currencies } ) {
            note "Currency: " . $currency->{name};

            $order->update( { currency_id => $currency->{id} } );

            # increase the Shipping Charge by 10, which won't
            # show up in the Order's 'total_value' column so
            # they will have different values
            $shipment->update( { shipping_charge => $shipment->shipping_charge + 10 } );
            $order->discard_changes;

            my $expected_original_value     = d2( $order->total_value );
            my $expected_shipment_value     = d2(
                $shipment->shipping_charge
              + $shipment->total_price
              + $shipment->total_tax
              + $shipment->total_duty
            );
            my $expected_original_converted = d2( $expected_original_value * $currency->{conversion_rate} );
            my $expected_shipment_converted = d2( $expected_shipment_value * $currency->{conversion_rate} );

            cmp_ok( d2( $order->get_total_value ), '==', $expected_shipment_value,
                "'get_total_value' returned Shipment's Total Value" );
            cmp_ok( d2( $order->get_total_value( { want_original_purchase_value => 1 } ) ), '==', $expected_original_value,
                "'get_total_value' with 'want_original_purchase_value' argument returned Order's Total Value" );

            cmp_ok( d2( $order->get_total_value_in_local_currency ), '==', $expected_shipment_converted,
                "'get_total_value_in_local_currency' returned the Shipment's Total Value in the DC's Currency" );
            cmp_ok( d2( $order->get_total_value_in_local_currency( { want_original_purchase_value => 1 } ) ), '==', $expected_original_converted,
                "'get_total_value_in_local_currency' with 'want_original_purchase_value' returned the Shipment's Total Value in the DC's Currency" );

            cmp_ok( d2( $order->get_original_total_value_in_local_currency ), '==', $expected_original_converted,
                "'get_original_total_value_in_local_currency' returned the Shipment's Total Value in the DC's Currency" );

            # Cancel the Shipment and Check the Total Value comes back as ZERO
            $shipment->update( { shipment_status_id => $SHIPMENT_STATUS__CANCELLED } );
            my $got = $order->get_total_value_in_local_currency;
            ok( defined $got,
                "'get_total_value_in_local_currency' called when an Order has a Cancelled Shipment returns a defined value" );
            cmp_ok( $order->get_total_value_in_local_currency, '==', 0, "and the Value is ZERO" );

            # Un-Cancel the Shipment
            $shipment->update( { shipment_status_id => $SHIPMENT_STATUS__PROCESSING } );
        }
    }
}

=head2 psp_info

=cut

sub psp_info : Tests {
    my $self = shift;

    my @channels = Test::XTracker::Data->get_enabled_channels->all;
    my $order_data = Test::XTracker::Data::Order->create_new_order( {
            channel => $channels[0],
    } );

    my $order = $order_data->{order_object};
    ok( $order, "order is created successfully");

    my $next_preauth = Test::XTracker::Data->get_next_preauth( $self->{schema}->storage->dbh );

    my $p_rec   = Test::XTracker::Data->create_payment_for_order( $order, {
        psp_ref     => $next_preauth,
        preauth_ref => $next_preauth,
    } );

    isa_ok( $p_rec, 'XTracker::Schema::Result::Orders::Payment' );

    # test payment_card_type method
    cmp_ok($order->payment_card_type, 'eq' ,'DisasterCard', "Got Payment card type from PSP");
    # test payment_card_avs_response method
    cmp_ok($order->payment_card_avs_response, 'eq' ,'ALL MATCH', "Got cv2avsStatus from PSP");

    # test methods : is_payment_card_new_for_custome and has_payment_card_been_used_before
    # when card history is null
    cmp_ok($order->is_payment_card_new_for_customer, '==' ,1, "Test1 - Payment Card is new for the customer");
    cmp_ok($order->has_payment_card_been_used_before, '==' ,0, "Test 2 - Payment Card is new");

    #create another order for this customer
    my $second_order_data = Test::XTracker::Data::Order->create_new_order( {
            channel  => $channels[0],
            customer => $order_data->{customer_object},
    });
    my $second_order = $second_order_data->{order_object};
    ok( $second_order, "Second Order got created successfully" );

    $p_rec   = Test::XTracker::Data->create_payment_for_order( $second_order, {
        psp_ref     => $next_preauth,
        preauth_ref => $next_preauth,
    } );

    #set card history to be not new
    Test::XTracker::Mock::PSP->set_card_history( [ {'orderNumber' => $order->order_nr}, ] );

    #test is_payment_card_new_for_customer
    cmp_ok($second_order->is_payment_card_new_for_customer, '==' ,0, "Test 3 - Payment Card is Not new for the customer");
    cmp_ok($second_order->has_payment_card_been_used_before, '==' ,1, "Test 4 - Payment Card is Not new");

    # create card history having random number and the current order number.
    $second_order->clear_method_cache;
    Test::XTracker::Mock::PSP->set_card_history( [ {'orderNumber' => '1234'},{orderNumber => $second_order->order_nr} ] );
    cmp_ok($second_order->is_payment_card_new_for_customer, '==' ,1, "Test 5 - Payment Card is new for this customer");
    cmp_ok($second_order->has_payment_card_been_used_before, '==' ,1, "Test 6 - Payment Card is Not new");

    note "check when there is No Card Payment the methods don't fall over";
    $order->clear_method_cache;
    $order->payments->delete;
    ok( !defined $order->get_psp_info, "'get_psp_info' returns 'undef'" );
    is( $order->payment_card_type, '', "'payment_card_type' returns an Empty String" );
    is( $order->payment_card_avs_response, '', "'payment_card_avs_response' returns an Empty String" );
    ok( !defined $order->has_payment_card_been_used_before, "'has_payment_card_been_used_before' returns 'undef'" );
    ok( !defined $order->is_payment_card_new_for_customer, "'is_payment_card_new_for_customer' returns 'undef'" );
    ok( !defined $order->is_payment_card_new, "'is_payment_card_new' returns 'undef'" );

    $order->is_in_hotlist;
    $second_order->is_in_hotlist;
    $order->is_in_hotlist;
    $second_order->is_in_hotlist;
}

=head2 shipping_address_used_before

=cut

sub shipping_address_used_before : Tests {
    my $self = shift;

    my $order = $self->create_new_order;
    ok( $order, "order is created succefully");

    my $address_id = $order->shipments->first->shipment_address_id;

    my $set = $self->schema->resultset('Public::Shipment')->search({
        shipment_address_id => $address_id,
        shipment_status_id => { '!=' => $SHIPMENT_STATUS__CANCELLED }
    });

    if ( $set->count > 1 ) {
        ok( $order->shipping_address_used_before, "address used before");
    }
    else {
        ok( ! $order->shipping_address_used_before, "address not used before");
    }
}

=head2 shipping_address_used_before_for_customer

=cut

sub shipping_address_used_before_for_customer : Tests {
    my $self = shift;

    my $order = $self->create_new_order;
    ok( $order, "order is created succefully");

    my $address_id = $order->shipments->first->shipment_address_id;

    my $set = $self->schema->resultset('Public::Shipment')->search({
        shipment_address_id => $address_id,
        shipment_status_id => { '!=' => $SHIPMENT_STATUS__CANCELLED },
        'orders.customer_id' => $order->customer_id
    },
    {
        'join' => { 'link_orders__shipments' => 'orders' },
    });

    if ( $set->count > 1 ) {
        ok( $order->shipping_address_used_before_for_customer,
            "shipping address used before for customer");
    }
    else {
        ok( ! $order->shipping_address_used_before_for_customer,
            "shipping address not used before for customer");
    }
}

=head2 test_get_standard_class_shipment_type_id

=cut

sub test_get_standard_class_shipment_type_id : Tests {
    my $self = shift;

    my $order_data = $self->create_new_order_data;
    my $order = $order_data->{order_object};
    my $shipment = $order_data->{shipment_object};

    cmp_ok(
        $order->get_standard_class_shipment_type_id(),
        '==',
        $shipment->shipment_type_id,
        "Standard Class Shipment Id returned"
    );
}

=head2 low_risk_shipping_country

=cut

sub low_risk_shipping_country : Tests {
    my $self = shift;
    my $address = Test::XTracker::Data->create_order_address_in('Norway'); # Norway is a known low risk country

    my @channels = Test::XTracker::Data->get_enabled_channels->all;
    my $order_data = Test::XTracker::Data::Order->create_new_order( {
            channel => $channels[0],
            address => $address,
    } );

    my $order = $order_data->{order_object};

    ok($order->low_risk_shipping_country,
            "Low risk shipping country correctly identified");

    $address = Test::XTracker::Data->create_order_address_in('IntlWorld'); # Turkey is not a known low risk country

    $order_data = Test::XTracker::Data::Order->create_new_order( {
            channel => $channels[0],
            address => $address,
    } );

    $order = $order_data->{order_object};
    ok( ! $order->low_risk_shipping_country,
        "This one is not a low risk country");

}

=head2 virtual_voucher

=cut

sub virtual_voucher : Tests {
    my $self = shift;

    my ( $channel, $pids )  = Test::XTracker::Data->grab_products({
        how_many => 1, channel => 'nap',
        phys_vouchers => {
            how_many => 1,
        },
        virt_vouchers => {
            how_many => 1,
        },
    });

    #create a order with normal products
    my $order = _create_order( { pids_to_use => [ $pids->[0] ] });
    cmp_ok( $order->contains_a_virtual_voucher, '==', 0, "Normal Order - Does not Contain virtual Voucher");
    cmp_ok( $order->contains_a_voucher, '==', 0, "Normal Order - Does not Contain Any Voucher");

    #create order with normal product and physical voucher
    $order = _create_order( { pids_to_use => [ $pids->[0], $pids->[1] ] });
    cmp_ok( $order->contains_a_virtual_voucher, '==', 0, "Physical Voucher Order - Does not Contain virtual Voucher");
    cmp_ok( $order->contains_a_voucher, '==', 1, "Physical Voucher Order - Contains a Voucher");

    #create order with normal product and virtual voucher
    $order = _create_order( { pids_to_use => [ $pids->[0], $pids->[2] ] });
    cmp_ok( $order->contains_a_virtual_voucher, '==', 1, "Virtual Voucher Order - Contains Virtual Voucher");
    cmp_ok( $order->contains_a_voucher, '==', 1, "Virtual Voucher Order - Contains a Voucher");

    #create a mixed order
    $order = _create_order( { pids_to_use => [ $pids->[0], $pids->[1],$pids->[2] ] });
    cmp_ok( $order->contains_a_virtual_voucher, '==', 1, "Mixed Order - Contains Virtual Voucher");
    cmp_ok( $order->contains_a_voucher, '==', 1, "Mixed Order - Contains a Voucher");

}

=head2 is_in_hotlist

=cut

sub is_in_hotlist: Tests {

    my $self = shift;


    my ( $channel, $pids )  = Test::XTracker::Data->grab_products({
        how_many => 1,
    });

    my $address = Test::XTracker::Data->order_address({
        address => "create",
        country => config_var('DistributionCentre','country'),
    });

    my $base = {
        invoice_address_id => $address->id,
    };
    my $order =_create_order({ pids_to_use => [ $pids->[0]], base => $base } );

    my $next_preauth = Test::XTracker::Data->get_next_preauth( $self->{schema}->storage->dbh );

    my $p_rec   = Test::XTracker::Data->create_payment_for_order( $order, {
        psp_ref     => $next_preauth,
        preauth_ref => $next_preauth,
    } );

    isa_ok( $p_rec, 'XTracker::Schema::Result::Orders::Payment' );

    my $hotlist_field = $self->schema->resultset('Public::HotlistField')->search({
        field => 'Street Address',
    });

    my $hotlist_rec = $channel->hotlist_values->create( {
        hotlist_field_id    => $hotlist_field->first->id,
        value               => 'Test Addr ' . $$,
    } );

    cmp_ok($order->is_in_hotlist, '==', '0', "Order with Normal Address is Not in hotlist");

    # Update invoice_address to hotlist one
    $order->clear_method_cache;
    $order->order_address->update({ address_line_1 => $hotlist_rec->value });
    cmp_ok($order->discard_changes->is_in_hotlist, '==', '1', "Order with blacklisted Invoice Address is in hotlist");

    #revert back the address line
    $order->clear_method_cache;
    $order->order_address->update({ address_line_1 => "abcd" });
    cmp_ok($order->discard_changes->is_in_hotlist, '==', '0', "Order Address not in hotlist");

    #update shipping address
    $order->clear_method_cache;
    my $shipment = $order->shipments->first;
    $shipment->shipment_address->update({ address_line_1 => $hotlist_rec->value });
    cmp_ok($order->discard_changes->is_in_hotlist, '==', '1', "Order with blacklisted Shipping Address is in hotlist");

}

=head2 is_ip_address_internal

=cut

sub is_ip_address_internal : Tests {
    my $self = shift;

    # Tests is_ip_address_internal is_ip_address_in_whitelist
    #       and is_ip_address_in_blacklist

    my $order = $self->create_new_order;

    # If the order does not have an IP address set it to localhost
    $order->ip_address('127.0.0.1') unless $order->ip_address;

    my $listed = $self->schema->resultset('Fraud::IpAddressList')->search({
        ip_address => $order->ip_address
    });

    if ( $listed && $listed->count > 0 ) {
        given ( $listed->first->status_id ) {
            when ( $SECURITY_LIST_STATUS__WHITELIST ) {
                ok( $order->is_ip_address_in_whitelist, "IP is whitelisted");
                ok( ! $order->is_ip_address_in_blacklist, "IP not blacklisted");
                ok( ! $order->is_ip_address_internal, "IP not internal");
            }
            when ( $SECURITY_LIST_STATUS__BLACKLIST ) {
                ok( $order->is_ip_address_in_blacklist, "IP is blacklisted");
                ok( ! $order->is_ip_address_in_whitelist, "IP not whitelisted");
                ok( ! $order->is_ip_address_internal, "IP not internal");
            }
            when ( $SECURITY_LIST_STATUS__INTERNAL ) {
                ok ( $order->is_ip_address_internal, "IP is internal");
                ok( ! $order->is_ip_address_in_whitelist, "IP not whitelisted");
                ok( ! $order->is_ip_address_in_blacklist, "IP not blacklisted");
            }
        }
    }
}

=head2 get_app_source

=cut

sub get_app_source : Tests {
    my $self = shift;

    my $order = $self->create_new_order;

    # Test condition where no attribute exists at all
    my $attributes = $self->schema->resultset('Public::OrderAttribute')->search( {
        orders_id => $order->id
    } )->delete_all;

    is_deeply( $order->get_app_source,
        { app_source_name => '', app_source_version => '' },
        "Empty strings returned when there is no order_attribute entry" );

    my $order_attribute = $self->schema->resultset('Public::OrderAttribute')->find_or_create( {
        orders_id => $order->id
    } );

    ok( defined $order->order_attribute, "Order attribute relationship exists" );

    # By default we're not expecting any attributes to be present but let's
    # make sure...
    $order_attribute->update( {
        source_app_name => undef,
        source_app_version => undef
    } );

    ok( ! defined $order_attribute->source_app_name, "source_app_name not defined" );
    ok( ! defined $order_attribute->source_app_version, "source_app_version not defined" );

    is_deeply( $order->get_app_source,
        { app_source_name => '', app_source_version => '' },
        "Empty strings present when we have no data" );

    $order_attribute->update( {
        source_app_name => 'Random Application',
        source_app_version => undef
    } );

    ok( defined $order_attribute->source_app_name, "source_app_name defined");
    ok( $order_attribute->source_app_name eq 'Random Application',
        "source_app_name has correct value" );

    is_deeply( $order->get_app_source,
        { app_source_name => 'Random Application', app_source_version => '' },
        "We have app_source_name and app_source_version is empty string" );

    $order_attribute->update( {
        source_app_name => undef,
        source_app_version => '1.0'
    } );

    ok( ! defined $order_attribute->source_app_name, "source_app_name not defined" );
    ok( defined $order_attribute->source_app_version, "source_app_version defined" );

    is_deeply( $order->get_app_source,
        { app_source_name => '', app_source_version => '' },
        "Empty strings present when we have version but no name" );

    $order_attribute->update( {
        source_app_name => 'Another Application',
        source_app_version => '2.0'
    } );

    ok( defined $order_attribute->source_app_name, "source_app_name defined");
    ok( defined $order_attribute->source_app_version, "source_app_version defined" );

    is_deeply( $order->get_app_source,
        {
            app_source_name => 'Another Application',
            app_source_version => '2.0'
        },
        "Correct strings returned for both name and version" );
}

=head2 test_has_psp_reference

Will test the 'has_psp_reference' method.

=cut

sub test_has_psp_reference : Tests() {
    my $self    = shift;

    my $order   = $self->create_new_order;

    my $payment = $order->payments->first;
    $payment->delete        if ( $payment );

    cmp_ok( $order->discard_changes->has_psp_reference, '==', '0',
                "'has_psp_reference' returns FALSE when NO 'orders.payment' record present" );

    my $psp_refs    = Test::XTracker::Data->get_new_psp_refs();
    Test::XTracker::Data->create_payment_for_order( $order, {
        psp_ref     => $psp_refs->{psp_ref},
        preauth_ref => $psp_refs->{preauth_ref},
    } );

    cmp_ok( $order->discard_changes->has_psp_reference, '==', '1',
                "'has_psp_reference' returns TRUE when an 'orders.payment' record IS present" );
}

=head2 test_ip_address_used_before

=cut

sub test_ip_address_used_before : Tests {
    my $self = shift;

    my $order = $self->create_new_order;

    # Set the IP address to localhost
    $order->update( { ip_address => '127.0.0.1' } );

    # We want to be sure we have 2 matching orders so add a new one
    # but we will need to ensure there is a clear couple of seconds
    # between the orders...
    $order->update( { date => \"date - interval '2 second'" } );
    $order->discard_changes;

    my $xt_data = Test::XT::Data->new_with_traits(
        traits => [ 'Test::XT::Data::Order', ]
    );
    my $xt_order = $xt_data->new_order( customer => $order->customer );
    my $new_order = $xt_order->{order_object};

    ok( $new_order, "I have a new order" );

    $new_order->update( { ip_address => '127.0.0.1' } );

    my $count = 0 + $new_order->discard_changes->ip_address_used_before;

    ok( $count, "IP Address has been used before - $count times" );

    my $plus_one = $new_order->ip_address_used_before( {
        include_current_order => 1
    } );

    ok( $count+1 == $plus_one, "Including this order increases the count by 1" );

    # Set the date on new_order to be in future so that it is impossible
    # that any order was placed within 2 seconds before it's date
    $new_order->update( { date => \"date + interval '3 minute'" } );
    $new_order->discard_changes;

    ok( ! $new_order->ip_address_used_before( {
        date_condition => 'order',
        period => 'second',
        count => 2 } ), "No orders with same IP in 2 seconds preceding this one" );

    TODO: {
        local $TODO = "ip_address_used_before based upon date condition of 'now' may fail but is never actually used";

        ok( ! $new_order->discard_changes->ip_address_used_before( {
            this_customer_only => 1,
            date_condition => 'now',
            period => 'second',
            count => 2 } ), "No orders with same IP in last 2 seconds" );
    }

    # Set ip_address to impossible value
    $new_order->ip_address('257.257.257.257');
    ok( ! $new_order->ip_address_used_before, "invalid IP address has NOT been used before" );

    note( "Test matching on cancelled orders" );
    my $cancelled_count = $new_order->ip_address_used_before( {
        cancelled_only => 1,
        date_condition => 'order',
        period => 'second',
        count => 2,
    } );

    $order->update( { order_status_id => $ORDER_STATUS__CANCELLED } );

    my $cancelled_plus_one = $new_order->ip_address_used_before( {
        cancelled_only => 1,
        date_condition => 'order',
        period => 'second',
        count => 2,
    } );

    ok( $cancelled_plus_one = $cancelled_count + 1, "Cancelled order count is correct" );

}

=head2 test_returnable_state_in_order_status_message

Tests that the Returnable State of the Shipment Item is set properly
in the 'returnable' key in the message payload.

=cut

sub test_returnable_state_in_order_status_message : Tests() {
    my $self    = shift;

    my %state_recs  = (
        map { $_->id => $_ }
            $self->rs('Public::ShipmentItemReturnableState')->all
    );

    my %tests   = (
        "When Item's Returnable State is 'Yes', then 'Y' should be found" => {
            state_id    => $SHIPMENT_ITEM_RETURNABLE_STATE__YES,
            expected    => 'Y',
        },
        "When Item's Returnable State is 'No', then 'N' should be found" => {
            state_id    => $SHIPMENT_ITEM_RETURNABLE_STATE__NO,
            expected    => 'N',
        },
        "When Item's Returnable State is 'CC Only', then 'N' should be found" => {
            state_id    => $SHIPMENT_ITEM_RETURNABLE_STATE__CC_ONLY,
            expected    => 'N',
        },
    );

    my $order_data = $self->create_new_order_data;
    my $order = $order_data->{order_object};
    my $shipment = $order_data->{shipment_object};
    my $ship_item= $shipment->shipment_items->order_by_sku->first;

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test = $tests{ $label };

        # update the State Record to have to outcome wanted
        $state_recs{ $test->{state_id} }->discard_changes->update( { returnable_on_pws => $test->{expected} } );

        # update the Item Record to be for the wanted State
        $ship_item->discard_changes;
        $ship_item->update( { returnable_state_id => $test->{state_id} } );

        my $message = $order->make_order_status_message;
        my $got     = $message->{orderItems}[0];
        is( $got->{returnable}, $test->{expected}, "'returnable' flag in message set to '" . $test->{expected} . "'" );
    }
}

=head2 test_is_paid_using_a_payment_method

Tests the methods 'is_paid_using_third_party_psp' & 'is_paid_using_credit_card'
which return TRUE or FALSE depending on whether all or part of the Order was paid
using a Third Party PSP such as 'PayPal' or directly using a Credit Card.

=cut

sub test_is_paid_using_a_payment_method : Tests {
    my $self    = shift;

    my $order   = $self->create_new_order;

    my %tests = (
        "When No Credit Card/Third Party Payment used at All, both should return FALSE" => {
            no_payment => 1,
            expect => {
                credit_card_method  => 0,
                third_party_method  => 0,
            },
        },
        "When a Card Payment used" => {
            payment_method  => $self->{payment_method}{creditcard},
            expect => {
                credit_card_method  => 1,
                third_party_method  => 0,
            },
        },
        "When a Third Party Payment used" => {
            payment_method  => $self->{payment_method}{thirdparty},
            expect => {
                credit_card_method  => 0,
                third_party_method  => 1,
            },
        },
    );

    my $payment_args = Test::XTracker::Data->get_new_psp_refs();

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test    = $tests{ $label };
        my $expect  = $test->{expect};

        my $payment = $order->discard_changes->payments->first;
        $payment->delete    if ( $payment );

        $payment_args->{payment_method} = $test->{payment_method};
        Test::XTracker::Data->create_payment_for_order( $order, $payment_args )
                            unless ( $test->{no_payment} );

        my $got = $order->is_paid_using_credit_card;
        ok( defined $got, "'is_paid_using_credit_card' method returned a defined value" );
        cmp_ok( $got, '==', $expect->{credit_card_method},
                            "and the value is as expected: " . $expect->{credit_card_method} );

        $got = $order->is_paid_using_third_party_psp;
        ok( defined $got, "'is_paid_using_third_party_psp' method returned a defined value" );
        cmp_ok( $got, '==', $expect->{third_party_method},
                            "and the value is as expected: " . $expect->{third_party_method} );
    }
}

=head2 test_is_paid_using_the_third_party_psp

Tests the method 'is_paid_using_the_third_party_psp' which returns TRUE or FALSE
depending on whether all or part of the Order was paid using a particular Third
Party PSP which is passed in as a parameter such as 'PayPal'.

=cut

sub test_is_paid_using_the_third_party_psp : Tests {
    my $self    = shift;

    my $order   = $self->create_new_order;

    my $third_party_method = $self->{payment_method}{thirdparty};

    my $test_payment_method = $self->rs('Orders::PaymentMethod')->update_or_create( {
        payment_method          => 'MadeUpPSP',
        payment_method_class_id => $ORDERS_PAYMENT_METHOD_CLASS__THIRD_PARTY_PSP,
        string_from_psp         => 'MADEUPPSP',
        display_name            => 'MadeUpPSP',
    } );

    my %tests = (
        "When No Card/Third Party Payment used at All, should return FALSE" => {
            no_payment => 1,
            parameter  => $third_party_method->payment_method,
            expect     => 0,
        },
        "When a Card Payment used, should return FALSE" => {
            payment_method  => $self->{payment_method}{creditcard},
            parameter       => $third_party_method->payment_method,
            expect          => 0,
        },
        "Ask for the Third Party PSP used and should return TRUE" => {
            payment_method  => $third_party_method,
            parameter       => $third_party_method->payment_method,
            expect          => 1,
        },
        "Ask for a different Third Party PSP to the one used and should return FALSE" => {
            payment_method  => $third_party_method,
            parameter       => 'MadeUpPSP',
            expect          => 0,
        },
        "Ask for a Third Party PSP that isn't in the DB and should return FALSE" => {
            payment_method  => $third_party_method,
            parameter       => 'FakePSP',
            expect          => 0,
        },
    );

    my $payment_args = Test::XTracker::Data->get_new_psp_refs();

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test = $tests{ $label };

        my $payment = $order->discard_changes->payments->first;
        $payment->delete    if ( $payment );

        $payment_args->{payment_method} = $test->{payment_method};
        Test::XTracker::Data->create_payment_for_order( $order, $payment_args )
                            unless ( $test->{no_payment} );

        my $got = $order->is_paid_using_the_third_party_psp( $test->{parameter} );
        ok( defined $got, "'is_paid_using_the_third_party_psp' method returned a defined value" );
        cmp_ok( $got, '==', $test->{expect}, "and the value is as expected: " . $test->{expect} );
    }

    # remove the Test Payment Method
    $test_payment_method->discard_changes->payments->delete;
    $test_payment_method->delete;
}

=head2 get_current_payment_status

Test that the get_current_payment_status method returns the value supplied by
the PSP or undef if not supplied by the PSP.

=cut

sub get_current_payment_status : Tests {
    my $self = shift;

    my @channels = Test::XTracker::Data->get_enabled_channels->all;
    my $order_data = Test::XTracker::Data::Order->create_new_order( {
            channel => $channels[0],
    } );

    my $order = $order_data->{order_object};
    ok( $order, "order is created successfully");

    my $next_preauth = Test::XTracker::Data->get_next_preauth( $self->{schema}->storage->dbh );
    my $payment_method = $self->rs('Orders::PaymentMethod')
                                ->search(
        {
            'payment_method_class.payment_method_class' => 'Third Party PSP',
        },
        {
            join => 'payment_method_class',
        }
    )->first;

    my $p_rec   = Test::XTracker::Data->create_payment_for_order( $order, {
        psp_ref     => $next_preauth,
        preauth_ref => $next_preauth,
        payment_method => $payment_method,
    } );

    isa_ok( $p_rec, 'XTracker::Schema::Result::Orders::Payment' );

    ok( ! $order->get_current_payment_status, "get_current_payment_status returns undef" )
        or diag explain $order->get_current_payment_status;

    # set payment info data we want for second order
    Test::XTracker::Mock::PSP->set_payment_method( $payment_method->string_from_psp );
    Test::XTracker::Mock::PSP->set_third_party_status('PENDING');

    #create another order for this customer
    my $second_order_data = Test::XTracker::Data::Order->create_new_order( {
            channel  => $channels[0],
            customer => $order_data->{customer_object},
    });
    my $second_order = $second_order_data->{order_object};
    ok( $second_order, "Second Order got created successfully" );

    $second_order->clear_method_cache;

    my $info = $second_order->get_psp_info;
    note p( $info );

    $next_preauth = Test::XTracker::Data->get_next_preauth( $self->{schema}->storage->dbh );

    $p_rec   = Test::XTracker::Data->create_payment_for_order( $second_order, {
        psp_ref     => $next_preauth,
        preauth_ref => $next_preauth,
        payment_method => $payment_method,
    } );

    cmp_ok( $second_order->get_current_payment_status, 'eq', 'PENDING', "Current payment status is PENDING" );

    # prevent other tests from maybe failing
    Test::XTracker::Mock::PSP->set_payment_method('default');
    Test::XTracker::Mock::PSP->set_third_party_status('');
}

=head2 test_get_total_value_less_credit_used

Tests the method that calculates the Total Value of the Order
less any Store or Voucher Credit used to pay for the Order.

=cut

sub test_get_total_value_less_credit_used : Tests {
    my $self = shift;

    # make a hash of Renumeration Type Constants
    # to a nice short name to be more descriptive
    my %tender_types = (
        'card'         => $RENUMERATION_TYPE__CARD_DEBIT,
        'store_credit' => $RENUMERATION_TYPE__STORE_CREDIT,
        'voucher'      => $RENUMERATION_TYPE__VOUCHER_CREDIT,
    );

    # create some vouchers to use the codes in the tests
    my ( $tmp, $vouchers ) = Test::XTracker::Data->grab_products( {
        how_many => 0,
        virt_vouchers => {
            how_many  => 1,
            want_code => 2,
        },
    } );
    my @voucher_codes = @{ $vouchers->[0]{voucher_codes} };

    my $order_data = $self->create_new_order_data( {
        products => 2,
    } );
    my $order          = $order_data->{order_object};
    my $shipment       = $order_data->{shipment_object};
    my @shipment_items = $shipment->shipment_items->all;

    # set-up the values for the Order, total Value will be: 370.00
    # the tests will check without any Cancelled Items and then Cancel
    # the first Item (total: 130.00) and check the result again
    $shipment->update( { shipping_charge => 10 } );
    $shipment_items[0]->update( { unit_price => 100, tax => 10, duty => 20 } );
    $shipment_items[1]->update( { unit_price => 200, tax => 10, duty => 20 } );
    my $total_value             = 370.00;
    my $item_to_cancel          = $shipment_items[0];
    my $total_cancel_item_value = 130.00;

    my %tests = (
        "Order Paid entirely by Card" => {
            setup => [
                { type => 'card', value => $total_value },
            ],
            expect => {
                before_cancel => $total_value,
                after_cancel  => ( $total_value - $total_cancel_item_value ),
            },
        },
        "Order Paid entirely by Store Credit" => {
            setup => [
                { type => 'store_credit', value => $total_value },
            ],
            expect => {
                before_cancel => 0,
                after_cancel  => 0,
            },
        },
        "Order Paid entirely by Gift Voucher" => {
            setup => [
                { type => 'voucher', value => $total_value, code => $voucher_codes[0]->id },
            ],
            expect => {
                before_cancel => 0,
                after_cancel  => 0,
            },
        },
        "Order Paid entirely by 2 Gift Vouchers" => {
            setup => [
                { type => 'voucher', value => ( $total_value / 2 ), code => $voucher_codes[0]->id },
                { type => 'voucher', value => ( $total_value / 2 ), code => $voucher_codes[1]->id },
            ],
            expect => {
                before_cancel => 0,
                after_cancel  => 0,
            },
        },
        "Order Paid by Store Credit & Gift Voucher" => {
            setup => [
                { type => 'store_credit', value => ( $total_value / 2 ) },
                { type => 'voucher',      value => ( $total_value / 2 ), code => $voucher_codes[0]->id },
            ],
            expect => {
                before_cancel => 0,
                after_cancel  => 0,
            },
        },
        "Order Paid by Card & Store Credit" => {
            setup => [
                { type => 'card',         value => ( $total_value / 2 ) },
                { type => 'store_credit', value => ( $total_value / 2 ) },
            ],
            expect => {
                before_cancel => ( $total_value / 2 ),
                after_cancel  =>  ( $total_value / 2 - $total_cancel_item_value ),
            },
        },
        "Order Paid by Card & Gift Voucher" => {
            setup => [
                { type => 'card',    value => ( $total_value / 2 ) },
                { type => 'voucher', value => ( $total_value / 2 ), code => $voucher_codes[0]->id },
            ],
            expect => {
                before_cancel => ( $total_value / 2 ),
                after_cancel  => ( $total_value / 2 - $total_cancel_item_value ),
            },
        },
        "Order Paid by Card, Store Credit & Gift Voucher" => {
            setup => [
                { type => 'card',         value => ( $total_value - 200 ) },
                { type => 'store_credit', value => 150 },
                { type => 'voucher',      value => 50, code => $voucher_codes[0]->id },
            ],
            expect => {
                before_cancel => ( $total_value - 200 ),
                after_cancel  => ( $total_value - 200 - $total_cancel_item_value ),
            },
        },
        "Order Paid by Card, Store Credit & 2 Gift Vouchers" => {
            setup => [
                { type => 'card',    value => ( $total_value - 200 ) },
                { type => 'voucher', value => 50,  code => $voucher_codes[0]->id },
                { type => 'voucher', value => 150, code => $voucher_codes[1]->id },
            ],
            expect => {
                before_cancel => ( $total_value - 200 ),
                after_cancel  => ( $total_value - 200 - $total_cancel_item_value ),
            },
        },
        "Order Paid by Card & Store Credit, but After Cancel Item Store Credit is greater than the Total Value" => {
            setup => [
                { type => 'card',         value => ( $total_value - 300 ) },
                { type => 'store_credit', value => 300 },
            ],
            expect => {
                before_cancel => ( $total_value - 300 ),
                after_cancel  => 0,     # should be ZERO and NOT negative
            },
        },
    );

    my $payment_args = Test::XTracker::Data->get_new_psp_refs;

    foreach my $label ( keys %tests ) {
        note "Testing: $label";
        my $test   = $tests{ $label };
        my $setup  = $test->{setup};
        my $expect = $test->{expect};

        $item_to_cancel->discard_changes->update( {
            shipment_item_status_id => $SHIPMENT_ITEM_STATUS__NEW
        } );
        $order->discard_changes->payments->delete;
        $order->tenders->delete;

        # create tenders for Order
        my $rank = 0;
        foreach my $tender ( @{ $setup } ) {
            $order->create_related( 'tenders', {
                voucher_code_id => $tender->{code},
                type_id         => $tender_types{ $tender->{type} },
                value           => $tender->{value},
                rank            => ++$rank,
            } );
            # create a Payment if 'card' is used
            Test::XTracker::Data->create_payment_for_order( $order, $payment_args )
                        if ( $tender->{type} eq 'card' );
        }

        my $got          = d2( $order->get_total_value_less_credit_used() );
        my $expect_value = d2( $expect->{before_cancel} );
        is( $got, $expect_value, "Before Cancelling an Item Value is as expected: ${expect_value}" );

        # now cancel an Item so the value is reduced
        $item_to_cancel->discard_changes->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__CANCELLED } );

        $got          = d2( $order->discard_changes->get_total_value_less_credit_used() );
        $expect_value = d2( $expect->{after_cancel} );
        is( $got, $expect_value, "After Cancelling an Item Value is as expected: ${expect_value}" );
    }
}


=head2 test_is_beyond_valid_payments_threshold

Test 'is_beyond_valid_payments_threshold' Method.

=cut

sub test_is_beyond_valid_payments_threshold : Tests {
    my $self = shift;

    my $order_data     = $self->create_new_order_data( { products => 1 } );
    my $order          = $order_data->{order_object};
    my $shipment       = $order_data->{shipment_object};

    # set-up the value of the Order to make the maths
    # simple to do in the tests, value: 100.00
    my $total_order_value = 100.00;
    $order->update( { pre_auth_total_value => $total_order_value } );
    $shipment->update( { shipping_charge => 0 } );
    $shipment->shipment_items->update( {
        unit_price => $total_order_value,
        tax        => 0,
        duty       => 0,
    } );

    my %tests = (
        "Value is 'Over' Payment Threshold using PSP" => {
            setup => {
                psp_response    => 'over',
                config_value    => 100,  # percent
                set_order_value => $total_order_value * 1.5,    # increase by 50%
            },
            expect => 1,
        },
        "Value is 'Under' Payment Threshold using PSP" => {
            setup => {
                psp_response    => 'under',
                config_value    => 0,   # percent
                set_order_value => $total_order_value * 1.5,    # increase by 50%
            },
            expect => 0,
        },
        "Value is 'Over' Payment Threshold using config setting as fallback" => {
            setup => {
                psp_response    => 'fail',
                config_value    => 40,     # percent
                set_order_value => $total_order_value * 1.5,    # increase by 50%
            },
            expect => 1,
        },
        "Value is 'Under' Payment Threshold using config setting as fallback" => {
            setup => {
                psp_response    => 'fail',
                config_value    => 60,     # percent
                set_order_value => $total_order_value * 1.5,    # increase by 50%
            },
            expect => 0,
        },
        "Value is 'Over' when there is no Card/Third Party Payment using config setting as fallback" => {
            setup => {
                psp_response    => 'fail',
                no_payment      => 1,
                config_value    => 40,     # percent
                set_order_value => $total_order_value * 1.5,    # increase by 50%
            },
            expect => 1,
            no_psp_request_check => 1,
        },
        "Value is 'Under' when there is no Card/Third Party Payment using config setting as fallback" => {
            setup => {
                psp_response    => 'fail',
                no_payment      => 1,
                config_value    => 60,     # percent
                set_order_value => $total_order_value * 1.5,    # increase by 50%
            },
            expect => 0,
            no_psp_request_check => 1,
        },
    );

    # get the config setting for the fallback
    my $config = \%XTracker::Config::Local::config;
    my $original_threshold = $config->{Valid_Payments}{valid_payments_threshold};

    # get PSP refs used to create a Payment
    my $payment_args = Test::XTracker::Data->get_new_psp_refs;

    # use this to get the request sent to the
    # PSP Service so the Amount can be tested
    my $mock_lwp = Test::XTracker::Mock::PSP->get_mock_lwp;

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test   = $tests{ $label };
        my $setup  = $test->{setup};
        my $expect = $test->{expect};

        # set-up the Payment & Tender for the Order
        $order->discard_changes->payments->delete;
        Test::XTracker::Data->create_payment_for_order( $order, $payment_args )
                    unless ( $setup->{no_payment} );
        $order->tenders->delete;
        $order->create_related( 'tenders', { value => $total_order_value, rank => 1,
            type_id => (
                $setup->{no_payment}
                ? $RENUMERATION_TYPE__STORE_CREDIT
                : $RENUMERATION_TYPE__CARD_DEBIT
            ),
        } );

        # adjust the Order Total by just updating
        # the only Shipment Item's Unit Price
        $shipment->discard_changes->shipment_items->update( {
            unit_price => $setup->{set_order_value},
        } );

        # set config to ZERO so it wouldn't play a part, unless a setting has been specified
        $config->{Valid_Payments}{valid_payments_threshold} = $setup->{config_value} // 0;

        # set what the PSP Service should return
        $mock_lwp->clear_requests;
        Test::XTracker::Mock::PSP->set_amount_exceeds_provider_threshold_response( $setup->{psp_response} );

        my $got = $order->discard_changes->is_beyond_valid_payments_threshold();
        cmp_ok( $got, '==', $expect, "'is_beyond_valid_payments_threshold' returned as Expected: '${expect}'" );

        unless ( $test->{no_psp_request_check} ) {
            my $request = $mock_lwp->get_last_request;
            # the amount is passed in the last part of the
            # URL, so test it to make sure it's in 'pence'
            my @path    = split( /\//, $request->uri->path );
            is( $path[-1], sprintf( '%d', ( $setup->{set_order_value} * 100 ) ),
                            "'newAmount' passed in the request is in 'pence' or USP: '" . $path[-1] . "'" );
        }
    }

    # restore the config setting
    $config->{Valid_Payments}{valid_payments_threshold} = $original_threshold;
}

=head2 accept_or_hold_order_after_fraud_check

Tests accepting an order - setting status to Processing and setting
status on all shipments to processing unless the shipment is on DDU hold
or hold for reasons other than Finance or Return.

=cut

sub accept_or_hold_order_after_fraud_check : Tests() {
    my $self = shift;

    my $order = $self->create_new_order();
    isa_ok( $order, 'XTracker::Schema::Result::Public::Orders' );

    my $shipment = $order->get_standard_class_shipment;
    isa_ok( $shipment, 'XTracker::Schema::Result::Public::Shipment' );

    my %tests = (
        FINANCE_HOLD    => {
            before  => $SHIPMENT_STATUS__FINANCE_HOLD,
            after   => $SHIPMENT_STATUS__PROCESSING,
        },
        HOLD            => {
            before  => $SHIPMENT_STATUS__HOLD,
            after   => $SHIPMENT_STATUS__HOLD,
        },
        DDU_HOLD        => {
            before  => $SHIPMENT_STATUS__DDU_HOLD,
            after   => $SHIPMENT_STATUS__DDU_HOLD,
        },
        RETURN_HOLD     => {
            before  => $SHIPMENT_STATUS__RETURN_HOLD,
            after   => $SHIPMENT_STATUS__PROCESSING,
        },
        EXCHANGE_HOLD   => {
            before  => $SHIPMENT_STATUS__EXCHANGE_HOLD,
            after   => $SHIPMENT_STATUS__PROCESSING,
        },
    );

    foreach my $test ( keys %tests ) {
        $self->{schema}->txn_begin;

        $order->update( {
            order_status_id => $ORDER_STATUS__CREDIT_HOLD,
        } );

        cmp_ok(
            $order->order_status_id,
            '==',
            $ORDER_STATUS__CREDIT_HOLD,
            'Order Status is Credit Hold'
        );

        $shipment->update( {
            shipment_status_id  => $tests{$test}->{before},
        } );

        cmp_ok(
            $shipment->shipment_status_id,
            '==',
            $tests{$test}->{before},
            "$test shipment has right 'before' status"
        );

        $order->accept_or_hold_order_after_fraud_check( $ORDER_STATUS__ACCEPTED );

        cmp_ok(
            $order->order_status_id,
            '==',
            $ORDER_STATUS__ACCEPTED,
            'Order Status is Accepted'
        );

        cmp_ok(
            $shipment->discard_changes->shipment_status_id,
            '==',
            $tests{$test}->{after},
            "$test shipment has correct 'after' status"
        );

        $self->{schema}->txn_rollback;
    }

    # Now test where the order is a pre-order
    my $pre_order = Test::XTracker::Data::PreOrder->create_complete_pre_order( { with_no_status_logs => 1 } );
    $order->create_related( 'link_orders__pre_orders', {
        pre_order_id    => $pre_order->id,
    } );

    # Yes this makes no sense for a pre_order but so what!
    $order->update( {
        order_status_id => $ORDER_STATUS__CREDIT_HOLD,
    } );

    cmp_ok(
        $order->order_status_id,
        '==',
        $ORDER_STATUS__CREDIT_HOLD,
        'Order Status is Credit Hold'
    );

    $shipment->update( {
        shipment_status_id  => $SHIPMENT_STATUS__FINANCE_HOLD,
    } );

    cmp_ok(
        $shipment->shipment_status_id,
        '==',
        $SHIPMENT_STATUS__FINANCE_HOLD,
        'PreOrder shipment is on Finance Hold',
    );

    $order->accept_or_hold_order_after_fraud_check( $ORDER_STATUS__ACCEPTED );

    cmp_ok(
        $order->discard_changes->order_status_id,
        '==',
        $ORDER_STATUS__ACCEPTED,
        'Order Status is now Accepted'
    );

    cmp_ok(
        $shipment->discard_changes->shipment_status_id,
        '==',
        $SHIPMENT_STATUS__PROCESSING,
        'PreOrder shipment is now Processing',
    );
}

=head2 test_change_status_to_with_cancelled_order

Test that attempting to use change_status_to method on an order with
a current status of CANCELLED resulted in an exception.

=cut

sub test_change_status_to_with_cancelled_order : Tests() {
    my $self = shift;

    my $order = $self->create_new_order();
    isa_ok( $order, 'XTracker::Schema::Result::Public::Orders' );

    $order->update( { order_status_id => $ORDER_STATUS__CANCELLED } );

    cmp_ok( $order->order_status_id,
            '==',
            $ORDER_STATUS__CANCELLED,
            'The order is cancelled'
          );

    throws_ok( sub {
            $order->change_status_to(
                $ORDER_STATUS__CREDIT_HOLD,
                $APPLICATION_OPERATOR_ID
            );
        },
        qr|Cannot change the status of order id .* with current status of CANCELLED|,
        'Attempt to change status dies with correct error'
    );
}

=head2 test_contains_sale_shipment

Test that contains_sale_shipment method returns 1 when any of the shipment
items have the sale flag (as passed with the order).

=cut

sub test_contains_sale_shipment : Tests() {
    my $self = shift;

    my $order = $self->create_new_order();

    my $shipment = $order->get_standard_class_shipment();

   $shipment->shipment_items->update_all( { sale_flag_id => $SHIPMENT_ITEM_ON_SALE_FLAG__NO } );

   ok( !$order->contains_sale_shipment, 'Does not have a sale shipment' );

   $shipment->shipment_items->first->update( { sale_flag_id => $SHIPMENT_ITEM_ON_SALE_FLAG__YES } );

   ok( $order->contains_sale_shipment, 'Has a sale shipment' );
}

=head2 test_order_total_matches_tender_total

Test the total for all the tenders matches the total for the order.

Tests the following methods:

    order_total_matches_tender_total
    order_total_does_not_match_tender_total (related convenience method)

=cut

sub test_order_total_matches_tender_total : Tests {
    my $self = shift;

    my $order = $self->create_new_order;
    my %tests = (
        'Zero Value Order, No Tender Rows' => {
            expected    => 1,
            setup       => {
                shipping_charge => 0,
                unit_price      => 0,
                tax             => 0,
                duty            => 0,
                tenders         => [],
            },
        },
        'Zero Value Order, One Tender Row (Zero Value)' => {
            expected    => 1,
            setup       => {
                shipping_charge => 0,
                unit_price      => 0,
                tax             => 0,
                duty            => 0,
                tenders         => [0],
            },
        },
        'Zero Value Order, Two Tender Rows (Both Zero Value)' => {
            expected    => 1,
            setup       => {
                shipping_charge => 0,
                unit_price      => 0,
                tax             => 0,
                duty            => 0,
                tenders         => [0,0],
            },
        },
        'Zero Value Order, One Tender Row (With a Value)' => {
            expected    => 0,
            setup       => {
                shipping_charge => 0,
                unit_price      => 0,
                tax             => 0,
                duty            => 0,
                tenders         => [100],
            },
        },
        'Zero Value Order, Two Tender Rows (Both With a Value)' => {
            expected    => 0,
            setup       => {
                shipping_charge => 0,
                unit_price      => 0,
                tax             => 0,
                duty            => 0,
                tenders         => [50,50],
            },
        },
        'Order With Value, No Tender Rows' => {
            expected    => 0,
            setup       => {
                shipping_charge => 10,
                unit_price      => 70,
                tax             => 10,
                duty            => 10,
                tenders         => [],
            },
        },
        'Order With Value, One Tender Row (Zero Value)' => {
            expected    => 0,
            setup       => {
                shipping_charge => 10,
                unit_price      => 70,
                tax             => 10,
                duty            => 10,
                tenders         => [0],
            },
        },
        'Order With Value, Two Tender Rows (Both Zero Value)' => {
            expected    => 0,
            setup       => {
                shipping_charge => 10,
                unit_price      => 70,
                tax             => 10,
                duty            => 10,
                tenders         => [0,0],
            },
        },
        'Order With Value, One Tender Row (With Incorrect Value)' => {
            expected    => 0,
            setup       => {
                shipping_charge => 10,
                unit_price      => 70,
                tax             => 10,
                duty            => 10,
                tenders         => [50],
            },
        },
        'Order With Value, Two Tender Rows (Both With Incorrect Values)' => {
            expected    => 0,
            setup       => {
                shipping_charge => 10,
                unit_price      => 70,
                tax             => 10,
                duty            => 10,
                tenders         => [25,25],
            },
        },
        'Order With Value, One Tender Row (With Correct Value)' => {
            expected    => 1,
            setup       => {
                shipping_charge => 10,
                unit_price      => 70,
                tax             => 10,
                duty            => 10,
                tenders         => [100],
            },
        },
        'Order With Value, Two Tender Rows (Both With Correct Values)' => {
            expected    => 1,
            setup       => {
                shipping_charge => 10,
                unit_price      => 70,
                tax             => 10,
                duty            => 10,
                tenders         => [50,50],
            },
        },
    );

    while ( my ( $name, $test ) = each %tests ) {

        subtest $name => sub {

            $self->{schema}->txn_do( sub {

                my $setup       = $test->{setup};
                my $expected    = $test->{expected};
                my $total_price = $setup->{shipping_charge} +
                                  $setup->{unit_price} +
                                  $setup->{tax} +
                                  $setup->{duty};
                my @tenders     = ref( $setup->{tenders} ) eq 'ARRAY'
                    ? @{ $setup->{tenders} }
                    : ();

                # Update the shipment to known values.
                $order->get_standard_class_shipment->update( {
                    shipping_charge => $setup->{shipping_charge},
                } );

                # Update the shipment to known values.
                $order->get_standard_class_shipment->shipment_items->first->update( {
                    unit_price  => $setup->{unit_price},
                    tax         => $setup->{tax},
                    duty        => $setup->{duty},
                } );

                # Remove and create order tenders if required.
                $order->tenders->delete;
                foreach my $tender_value ( @tenders ) {
                    $order->create_related( 'tenders', {
                        rank            => 0,
                        value           => $tender_value,
                        type_id         => $RENUMERATION_TYPE__CARD_DEBIT,
                    } );
                }

                # Make sure the order has the correct total value.
                cmp_ok( $order->discard_changes->get_total_value, '==',
                    $total_price, "Using total order value of $total_price" );

                # Make sure the tenders are as expected. We multiply by "1"
                # here to remove any numeric formatting the database has.
                cmp_bag( [ map { $_->value * 1 } $order->tenders->all ], [ @tenders ],
                    scalar @tenders
                        ? 'Using ' . ( scalar @tenders ) . ' tender(s) with the value(s): ' . join( ', ', @tenders )
                        : 'Using no tenders' );

                # Call the methods.
                my $match_result        = $order->order_total_matches_tender_total;
                my $non_match_result    = $order->order_total_does_not_match_tender_total;

                if ( $expected ) {

                    ok( $match_result, 'order_total_matches_tender_total returns a TRUE value' );
                    ok( ! $non_match_result, 'order_total_does_not_match_tender_total returns a FALSE value' );

                } else {

                    ok( ! $match_result, 'order_total_matches_tender_total returns a FALSE value' );
                    ok( $non_match_result, 'order_total_does_not_match_tender_total returns a TRUE value' );

                }

            } );

        };

    }
}

=head2 test_order_currency_matches_psp_currency

Test the currency of order matches currency we get from psp.

Test method : order_currency_matches_psp_currency

=cut

sub test_order_currency_matches_psp_currency : Tests {
    my $self = shift;

    my $order = $self->create_new_order;

    # create an 'orders.payment' record
    my $next_preauth = Test::XTracker::Data->get_next_preauth( $self->{schema}->storage->dbh );

    Test::XTracker::Data->create_payment_for_order( $order, {
        psp_ref     => $next_preauth,
        preauth_ref => $next_preauth,
    } );

    my %tests = (
        'GBP order currency, GBP psp currency' => {
            expected    => 1,
            setup       => {
                order_currency => 'GBP',
                psp_currency   => 'GBP'
            },
        },
        'GBP order currency, EUR psp currency' => {
            expected    => 0,
            setup       => {
                order_currency => 'GBP',
                psp_currency => 'EUR'
            },
        },
        'EUR order currency, no psp currency' => {
            expected => 0,
            setup       => {
                order_currency => 'GBP',
                psp_currency => ''
            },
        },
        'EUR order currency, GBP psp currency' => {
            expected => 0,
            setup       => {
                order_currency => 'EUR',
                psp_currency => 'GBP'
            },
        },
        'HKD order currency, HKD currency' => {
            expected => 1,
            setup       => {
                order_currency => 'HKD',
                psp_currency => 'HKD',
            },
        },
    );

    while ( my ( $name, $test ) = each %tests ) {

        subtest $name => sub {

            $self->{schema}->txn_do( sub {

                my $setup       = $test->{setup};
                my $expected    = $test->{expected};

                my $o_cur = $self->{schema}->resultset('Public::Currency')->search( { currency => $setup->{order_currency} } )->first;

                $order->update({ currency_id => $o_cur->id} );

                $order->clear_method_cache;
                Test::XTracker::Mock::PSP->set_payment_currency( $setup->{psp_currency} );

                # Call the method.
                my $match_result = $order->order_currency_matches_psp_currency;

                if ( $expected ) {
                    ok( $match_result, 'order_currency_matches_psp_currency returns a TRUE value' );
                } else {
                    ok( ! $match_result, 'order_currency_matches_psp_currency returns a FALSE value' );
                }

            } );

        };

    }
}

=head2 test_signature_required_methods

Test signature_required flags value of standard class shipment

Test method(s) :
    * is_signature_required_for_standard_class_shipment
    * is_signature_not_required_for_standard_class_shipment

=cut

sub test_signature_required_methods : Tests {
    my $self = shift;

    my $order = $self->create_new_order;

    ok( $order, "order is created succefully");

    my $shipment    = $order->get_standard_class_shipment;

    $shipment->update({ signature_required => 't'});
    ok( $order->is_signature_required_for_standard_class_shipment, "'is_signature_required_for_standard_class_shipment' Returned 'TRUE' ");
    ok( !($order->is_signature_not_required_for_standard_class_shipment), "'is_signature_not_required_for_standard_class_shipment' Returned 'FALSE'");

    $shipment->update({ signature_required => 'f'});
    ok( !($order->is_signature_required_for_standard_class_shipment), "'is_signature_required_for_standard_class_shipment' Returned 'FALSE'");
    ok( $order->is_signature_not_required_for_standard_class_shipment, "'is_signature_not_required_for_standard_class_shipment' Returned 'TRUE' ");

}

=head2 test_get_search_results_by_shipment_id_rs

Test the ResultSet method called 'get_search_results_by_shipment_id_rs' which
returns a result-set of Orders for a given list of Shipment Ids. This test
checks the fields that come back as well as looking for the '1st Order' order flag

=cut

sub test_get_search_results_by_shipment_id_rs : Tests() {
    my $self = shift;

    $self->schema->txn_begin;

    # a subset of the list of fields that are expected
    # to be returned, in particualr the fields from the
    # joins to other tables
    my @expect_fields = qw(
        order_nr
        first_order_flag
        order_currency
        first_name
        last_name
        customer_category_id
        customer_category
        customer_class_id
        customer_class
        channel_name
        channel_config_section
        shipment_id
        shipment_class_id
        shipment_class
        shipment_type_id
        shipment_type
        shipment_status_id
        shipment_status
        shipment_country
    );

    my $order_data = $self->create_new_order_data( { products => 1 } );
    my $order      = $order_data->{order_object};
    my $shipment   = $order_data->{shipment_object};

    my $shipment_id = $shipment->id;

    note "Remove all Order Flags for the Order, then test the 'get_search_results_by_shipment_id_rs' method";
    # remove any Order Flags
    $order->discard_changes->order_flags->delete;

    my $rec = $self->_test_get_search_results_by_shipment_id_rs_record( $shipment_id );
    my %rec_fields = $rec->get_columns();
    cmp_deeply( [ keys %rec_fields ], superbagof( @expect_fields ), "got Expected fields" );

    # without any Flags 'first_order_flag' should be 'undef'
    ok( !defined $rec_fields{first_order_flag}, "'first_order_flag' not Defined in the record" );


    note "Add First Order Flag";
    $order->add_flag( $FLAG__1ST );

    $rec = $self->_test_get_search_results_by_shipment_id_rs_record( $shipment_id );
    ok( $rec->get_column( 'first_order_flag' ), "'first_order_flag' is set" );


    note "Add another Order Flag";
    $order->add_flag( $FLAG__FINANCE_WATCH );

    $rec = $self->_test_get_search_results_by_shipment_id_rs_record( $shipment_id );
    ok( $rec->get_column( 'first_order_flag' ), "'first_order_flag' is still set" );


    note "Remove '1st Order' Flag but still have the other Flag";
    # easier to just remove all flags and then add back in the one we want
    $order->order_flags->delete;
    $order->add_flag( $FLAG__FINANCE_WATCH );

    $rec = $self->_test_get_search_results_by_shipment_id_rs_record( $shipment_id );
    ok( !defined $rec->get_column( 'first_order_flag' ), "'first_order_flag' not Defined in the record" );


    $self->schema->txn_rollback;
}

=head2 test_helper_methods_for_order_functions_based_on_payment_method

Tests the following Methods:

    payment_method_allows_editing_of_billing_address
    payment_method_insists_billing_and_shipping_address_always_the_same
    payment_method_requires_basket_updates
    payment_method_allows_full_refund_using_only_store_credit
    payment_method_allows_full_refund_using_only_the_payment
    payment_method_allow_editing_of_shipping_address_post_settlement
    payment_method_requires_payment_cancelled_if_forced_shipping_address_updated_used

=cut

sub test_helper_methods_for_order_functions_based_on_payment_method : Tests() {
    my $self = shift;

    # will Rollback all changes later
    $self->schema->txn_begin();

    # it shouldn't matter what Class the Payment Method
    # is, so will do tests using each Class available
    my @classes = $self->rs('Orders::PaymentMethodClass')->all;

    # create a Payment Method
    my $test_payment_method = $self->rs('Orders::PaymentMethod')->update_or_create( {
        payment_method          => 'MadeUpPSP',
        string_from_psp         => 'MADEUPPSP',
        # need to give it a class just to get it created
        payment_method_class_id => $ORDERS_PAYMENT_METHOD_CLASS__THIRD_PARTY_PSP,
        display_name            => 'MadeUpPSP',
    } );

    # create an Order to use in the tests
    my $order = $self->create_new_order;

    my %tests = (
        "Set the Payment Method so you CAN'T Edit the Billing Address" => {
            setup => {
                # list any methods available to 'Test::XTracker::Data'
                # that can be called being passed the Payment record
                use_methods => [ qw(
                    prevent_editing_of_billing_address_for_payment
                ) ]
            },
            expect => {
                # list method names to call against the 'Public::Orders'
                # object and what they are expected to return
                payment_method_insists_billing_and_shipping_address_always_the_same => 1,
                payment_method_allows_editing_of_billing_address                => 0,
            },
        },
        "Set the Payment Method so you CAN Edit the Billing Address" => {
            setup => {
                use_methods => [ qw(
                    allow_editing_of_billing_address_for_payment
                ) ]
            },
            expect => {
                payment_method_insists_billing_and_shipping_address_always_the_same => 0,
                payment_method_allows_editing_of_billing_address                => 1,
            },
        },
        "Set the Payment Method so that the PSP Requires updates for Basket Changes" => {
            setup => {
                use_methods => [ qw(
                    change_payment_to_require_psp_notification_of_basket_changes
                ) ]
            },
            expect => {
                payment_method_requires_basket_updates => 1,
            },
        },
        "Set the Payment Method so that the PSP DOESN'T Require updates for Basket Changes" => {
            setup => {
                use_methods => [ qw(
                    change_payment_to_not_require_psp_notification_of_basket_changes
                ) ]
            },
            expect => {
                payment_method_requires_basket_updates => 0,
            },
        },
        "Set the Payment Method so that the Store Credit ONLY Refunds ARE Allowed" => {
            setup => {
                use_methods => [ qw(
                    change_payment_to_allow_store_credit_only_refunds
                ) ]
            },
            expect => {
                payment_method_allows_full_refund_using_only_store_credit => 1,
            },
        },
        "Set the Payment Method so that the Store Credit ONLY Refunds are NOT Allowed" => {
            setup => {
                use_methods => [ qw(
                    prevent_payment_from_allowing_store_credit_only_refunds
                ) ]
            },
            expect => {
                payment_method_allows_full_refund_using_only_store_credit => 0,
            },
        },
        "Set the Payment Method so that the Payment ONLY Refunds ARE Allowed" => {
            setup => {
                use_methods => [ qw(
                    change_payment_to_allow_payment_only_refunds
                ) ]
            },
            expect => {
                payment_method_allows_full_refund_using_only_the_payment => 1,
            },
        },
        "Set the Payment Method so that the Payment ONLY Refunds are NOT Allowed" => {
            setup => {
                use_methods => [ qw(
                    prevent_payment_from_allowing_payment_only_refunds
                ) ]
            },
            expect => {
                payment_method_allows_full_refund_using_only_the_payment => 0,
            },
        },
        "When there is NO Payment Method used (In Other Words using Store Credit/Gift Vouchers)" => {
            setup => {
                no_payment_used => 1,
            },
            expect => {
                payment_method_insists_billing_and_shipping_address_always_the_same => 0,
                payment_method_allows_editing_of_billing_address                    => 1,
                payment_method_requires_basket_updates                              => 0,
                payment_method_allows_full_refund_using_only_store_credit           => 1,
                payment_method_allows_full_refund_using_only_the_payment            => 1,
                payment_method_requires_payment_cancelled_if_forced_shipping_address_updated_used => 0,
            },
        },
        "Set the Payment Method so that Billing Address can be change post Settlement" => {
            setup => {
                use_methods => [ qw(
                    change_payment_to_allow_change_of_shipping_address_post_settlement
                ) ]
            },
            expect => {
                payment_method_allow_editing_of_shipping_address_post_settlement => 1,
            },
        },
        "Set the Payment Method so that Billing Address can NOT be changed post Settlement" =>{
            setup => {
                use_methods => [ qw(
                    change_payment_to_not_allow_change_of_shipping_address_post_settlement
                ) ]
            },
            expect => {
                payment_method_allow_editing_of_shipping_address_post_settlement => 0,
            },
        },
        "Set the Payment Method so that it's required to Cancel the Payment after a Forced Shipping Address change" => {
            setup => {
                use_methods => [ qw(
                    change_payment_to_cancel_payment_after_force_address_update
                ) ]
            },
            expect => {
                payment_method_requires_payment_cancelled_if_forced_shipping_address_updated_used => 1,
            },
        },
        "Set the Payment Method so that it's NOT required to Cancel the Payment after a Forced Shipping Address change" => {
            setup => {
                use_methods => [ qw(
                    change_payment_to_not_cancel_payment_after_force_address_update
                ) ]
            },
            expect => {
                payment_method_requires_payment_cancelled_if_forced_shipping_address_updated_used => 0,
            },
        },
    );

    # need this to create an 'orders.payment' record
    my $payment_args = Test::XTracker::Data->get_new_psp_refs();

    # add the Payment Method to the Payment Args
    $payment_args->{payment_method} = $test_payment_method;

    foreach my $class ( @classes ) {
        my $class_name = $class->payment_method_class;

        # update the Payment Method's Class
        $test_payment_method->update( { payment_method_class_id => $class->id } );

        subtest "TESTING using Payment Method Class: '${class_name}'" => sub {
            foreach my $label ( keys %tests ) {
                note "Test: '${label}'";
                my $test   = $tests{ $label };
                my $setup  = $test->{setup};
                my $expect = $test->{expect};

                # remove any 'orders.payment' records for the Order
                my $payment = $order->discard_changes->payments->first;
                $payment->delete    if ( $payment );

                # now create the Payment wanted by the test (if wanted at all)
                $payment = Test::XTracker::Data->create_payment_for_order( $order, $payment_args )
                                    unless ( $setup->{no_payment_used} );

                # call any setup methods
                Test::XTracker::Data->$_( $payment )    foreach ( @{ $setup->{use_methods} // [] } );

                # call the methods against the 'Public::Orders' record
                while ( my ( $method, $expect_value ) = each %{ $expect } ) {
                    my $got = $order->$method;
                    fail( "Got 'undefined' back from '${method}'" )     if ( !defined $got );
                    cmp_ok( $got, '==', $expect_value, "'${method}' returned as Expected" );
                }
            }
        }
    }


    # Rollback everything
    $self->schema->txn_rollback();
}

#---------------------------------------------------------------------------------------------------

# helper that calls the 'get_search_results_by_shipment_id_rs'
# ResultSet Method and tests it got back a Record and for the#
# expected Shipmnt Id
sub _test_get_search_results_by_shipment_id_rs_record {
    my ( $self, $shipment_id ) = @_;

    my $order_rs = $self->rs('Public::Orders');

    my $rs  = $order_rs->get_search_results_by_shipment_id_rs( [ $shipment_id ] );
    cmp_ok( $rs->count, '==', 1, "only one Record found" );
    my $rec = $rs->reset->first;

    isa_ok( $rec, 'XTracker::Schema::Result::Public::Orders', "Found a Record" );
    cmp_ok( $rec->get_column('shipment_id'), '==', $shipment_id, "and for the Correct Shipment" );

    return $rec;
}

