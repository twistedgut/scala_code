package Test::XT::FraudRules::Engine::ApplyFlags;
use NAP::policy "tt", 'test';
use parent "NAP::Test::Class";

=head1 NAME

Test::XT::FraudRules::Engine::ApplyFlags

=head1 SYNOPSIS

Tests the Applying of the Finance Flags that are applied in the Fraud Rules Engine.

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::FraudRule;
use Test::XT::Data;
use Test::XTracker::Mock::PSP;

use XT::FraudRules::Engine;
use XTracker::Constants::FromDB             qw( :flag :orders_payment_method_class );


# to be done first before ALL the tests start
sub startup : Test( startup => 0 ) {
    my $self = shift;
    $self->SUPER::startup;

    $self->{schema} = Test::XTracker::Data->get_schema;
    Test::XTracker::Mock::PSP->use_all_mocked_methods();    # get the PSP Mock in a known state
}

# to be done BEFORE each test runs
sub setup : Test( setup => 2 ) {
    my $self = shift;
    $self->SUPER::setup;

    $self->{data}   = Test::XT::Data->new_with_traits(
        traits  => [
            'Test::XT::Data::Channel',
            'Test::XT::Data::Customer',
            'Test::XT::Data::Order',
        ],
    );
    $self->{channel}  = $self->data->channel;
    $self->{customer} = $self->data->customer;
    $self->{order}    = $self->data->new_order(
        channel  => $self->{channel},
        customer => $self->{customer},
        tenders  => [ { type => 'card_debit', value => 1100 } ],
    )->{order_object};
    $self->{shipment} = $self->{order}->get_standard_class_shipment;

    my $next_preauth = Test::XTracker::Data->get_next_preauth();
    Test::XTracker::Data->create_payment_for_order( $self->{order}, {
        psp_ref     => $next_preauth,
        preauth_ref => $next_preauth,
    } );

    # make the Shipping and Billing Addresses different
    my $inv_addr    = Test::XTracker::Data->create_order_address_in( 'current_dc', { country => 'United Kingdom' } );
    my $ship_addr   = Test::XTracker::Data->create_order_address_in( 'current_dc', { country => 'United States' } );
    $self->{order}->update( { invoice_address_id => $inv_addr->id } );
    $self->{shipment}->update( { shipment_address_id => $ship_addr->id } );

    # get a Unique Email Address so it won't match
    # any other Customers on any other Channels
    $self->{customer}->update( {
        email   => Test::XTracker::Data->create_unmatchable_customer_email( $self->dbh ),
    } );

    $self->schema->txn_begin;
}

# to be done AFTER every test runs
sub teardown : Test( teardown => 0 ) {
    my $self = shift;
    $self->SUPER::teardown;

    Test::XTracker::Mock::PSP->set_avs_response_to_default;
    Test::XTracker::Mock::PSP->set_card_history_to_default;

    # get rid of any instances
    # of the FraudRules::Engine
    delete $self->{engine};

    $self->schema->txn_rollback;
}

sub test_shutdown : Test( shutdown => no_plan ) {
    my $self = shift;
    $self->SUPER::shutdown;

    Test::XTracker::Mock::PSP->use_all_original_methods();
}


=head1 TESTS

=head2 test_apply_flags

With some Test Flag Rules this calls the method 'apply_finance_flags' and checks
that the correct Flags got applied.

=cut

sub test_apply_flags : Tests() {
    my $self    = shift;

    my $order   = $self->{order};
    my $shipment= $self->{shipment};

    # delete all flags first
    $order->order_flags->delete;

    $shipment->update({ signature_required => 'f'});

    # set-up the High Value limit so that the test Order triggers it
    my $threshold_rs    = $self->schema->resultset('Public::CreditHoldThreshold')->search( { channel_id => $self->{channel}->id } );
    $threshold_rs->search( { name => 'Single Order Value' } )->first->update( {
        value   => ( int( $order->get_total_value_in_local_currency - 10 ) ),
    } );
    $threshold_rs->search( { name => 'Daily Order Count' } )->first->update( { value => 1 } );
    $threshold_rs->search( { name => 'Weekly Order Count' } )->first->update( { value => 10 } );

    # Set of test flag rules that will
    # be used in the following tests
    my @test_flag_data  = (
        {   # Should get APPLIED
            flag => $FLAG__ADDRESS, conditions => [
                { class => 'Public::Orders', method => 'standard_shipment_address_matches_invoice_address', operator => 'boolean', value => 'false' },
                { class => 'Public::Orders', method => 'shipping_address_used_before_for_customer', operator => 'boolean', value => 'false' },
            ],
        },
        {   # Should NOT get Applied
            flag => $FLAG__MULTI_CHANNEL_CUSTOMER, conditions => [
                { class => 'Public::Customer', method => 'is_on_other_channels' },
            ],
        },
        {   # Should get APPLIED
            flag => $FLAG__1ST, conditions => [
                { class => 'Public::Orders', method => 'is_customers_nth_order', params => '[ 1 ]' },
            ],
        },
        {   # Should NOT get Applied
            flag => $FLAG__2ND, conditions => [
                { class => 'Public::Orders', method => 'is_customers_nth_order', params => '[ 2 ]' },
            ],
        },
        {   # Should NOT get Applied
            flag => $FLAG__3RD, conditions => [
                { class => 'Public::Orders', method => 'is_customers_nth_order', params => '[ 3 ]' },
            ],
        },
        {   # Should get APPLIED
            flag => $FLAG__HIGH_VALUE, conditions => [
                {
                    class   => 'Public::Orders',
                    method  => 'get_total_value_in_local_currency',
                    operator=> '>',
                    value   => 'P[LUT.Public::CreditHoldThreshold.value,name=Single Order Value:channel]',
                },
            ],
        },
        {   # Should NOT get Applied
            flag => $FLAG__WEEKLY_ORDER_COUNT_LIMIT, conditions => [
                {
                    class   => 'Public::Customer',
                    method  => 'number_of_orders_in_last_n_periods',
                    params  => '[ { "count":7, "period":"day", "on_all_channels":1 } ]',
                    operator=> '>=',
                    value   => 'P[LUT.Public::CreditHoldThreshold.value,name=Weekly Order Count:channel]',
                },
            ],
        },
        {   # Should get APPLIED
            flag => $FLAG__DAILY_ORDER_COUNT_LIMIT, conditions => [
                {
                    class   => 'Public::Customer',
                    method  => 'number_of_orders_in_last_n_periods',
                    params  => '[ { "count":24, "period":"hour", "on_all_channels":1 } ]',
                    operator=> '>=',
                    value   => 'P[LUT.Public::CreditHoldThreshold.value,name=Daily Order Count:channel]',
                },
            ],
        },
        # running this again but with the 'add_once' argument IS set
        # means that the Flag should NOT be applied twice
        {
            flag => $FLAG__1ST, add_once => 1, conditions => [
                { class => 'Public::Orders', method => 'is_customers_nth_order', params => '[ 1 ]' },
            ],
        },
        # call this again and because the 'add_once' argument is NOT set
        # then this Flag SHOULD get applied for a second time
        {   # Should get APPLIED
            flag => $FLAG__ADDRESS, conditions => [
                { class => 'Public::Orders', method => 'standard_shipment_address_matches_invoice_address', operator => 'boolean', value => 'false' },
                { class => 'Public::Orders', method => 'shipping_address_used_before_for_customer', operator => 'boolean', value => 'false' },
            ],
        },
        {   # Should get Applied
            flag => $FLAG__DELIVERY_SIGNATURE_OPT_OUT, conditions => [
                { class => 'Public::Orders', method => 'is_signature_not_required_for_standard_class_shipment' },
            ],
        },
    );

    # list of Flags expected to
    # be applied to the Order
    my @expected_flags  = (
        $FLAG__ADDRESS,
        $FLAG__1ST,
        $FLAG__HIGH_VALUE,
        $FLAG__DAILY_ORDER_COUNT_LIMIT,
        $FLAG__ADDRESS,
        $FLAG__DELIVERY_SIGNATURE_OPT_OUT,
    );

    # replace the flags in the object with those above
    $self->engine->meta->get_attribute('finance_flags_to_apply')            # it's a Read Only attribute
                        ->set_value( $self->engine, \@test_flag_data );     # so need to do it this way

    # Apply the Flags
    $self->engine->apply_finance_flags;

    my $order_flags_rs  = $order->discard_changes->order_flags;
    cmp_ok( $order_flags_rs->count, '==',  scalar( @expected_flags ),
                    "Expected Number of Flags have been Applied to the Order: " . scalar( @expected_flags ) );
    is_deeply(
        [ sort { $a <=> $b } $order_flags_rs->get_column('flag_id')->all ],
        [ sort { $a <=> $b } @expected_flags ],
        "and all the Flags are of the Expected Types"
    );

    # check the Outcome on the Fraud Rules Engine has the same Flags
    my $outcome = $self->engine->outcome;
    isa_ok( $outcome, 'XT::FraudRules::Engine::Outcome',
                    "an 'Outcome' object was found for the Engine" );
    isa_ok( $outcome->flags_assigned_rs, 'XTracker::Schema::ResultSet::Public::Flag',
                    "'flags_assigned_rs' on Outcome has a Result Set of Flag" );
    is_deeply(
        { map { $_->id => 1 } $outcome->flags_assigned_rs->all },
        { map { $_ => 1 } @expected_flags },
        "and the Flags are of the Expected Types"
    );
}

=head2 test_applying_with_live_flag_rules

Just call 'apply_finance_flags' and use whatever Rules have been set-up to
Apply the Flags and then check to make sure at least some flags have been
applied.

=cut

sub test_applying_with_live_flag_rules : Tests() {
    my $self    = shift;

    Test::XTracker::Mock::PSP->set_card_history( [] );

    # specify some of the Flags
    # that should be assigned
    my @expect_flags    = (
        $FLAG__ADDRESS,
        $FLAG__1ST,
        # these 2 should be there because of
        # the Defaults used by Mock::PSP
        $FLAG__NEW_CARD,
        $FLAG__ALL_MATCH,
    );

    my $order   = $self->{order};

    # delete all flags first
    $order->order_flags->delete;

    $self->engine->apply_finance_flags;

    my $order_flags_rs  = $order->discard_changes->order_flags;
    cmp_ok( $order_flags_rs->count, '>', 1, "More than One Flag has been Applied" );

    # check the Outcome on the Fraud Rules Engine has the same Flags
    my $outcome = $self->engine->outcome;
    isa_ok( $outcome, 'XT::FraudRules::Engine::Outcome',
                    "an 'Outcome' object was found for the Engine" );
    isa_ok( $outcome->flags_assigned_rs, 'XTracker::Schema::ResultSet::Public::Flag',
                    "'flags_assigned_rs' on Outcome has a Result Set of Flag" );

    my %got_flags   = map { $_->id => 1 } $outcome->flags_assigned_rs->all;

    is_deeply(
        \%got_flags,
        { map { $_->flag_id => 1 } $order_flags_rs->all },
        "and the Flags on the Outcome object match those that have been assigned"
    );

    note "Checking for Specific Flags";
    cmp_deeply(
        [ keys %got_flags ],
        superbagof( @expect_flags ),
        "Expected Flags were Assigned"
    );

    my $cache   = $self->engine->_cache;
    #diag "----> " . p( $cache );
}

=head2 test_applying_new_card_flag

Just call 'apply_finance_flags' and check that the New Card flag is
applied for Credit Card Payment and NOT for non Credit Card Methods.

=cut

sub test_applying_new_card_flag : Tests() {
    my $self    = shift;

    Test::XTracker::Mock::PSP->set_card_history( [] );

    # specify some of the Flags
    # that should be assigned
    my @expect_flags    = (
        $FLAG__ADDRESS,
        $FLAG__1ST,
        # these 2 should be there because of
        # the Defaults used by Mock::PSP
        $FLAG__NEW_CARD,
        $FLAG__ALL_MATCH,
    );

    my $order   = $self->{order};
    my $payment = $order->payments->first;

    my $methods = Test::XTracker::Data->get_cc_and_third_party_payment_methods();

    note "Check for Flag when using a Credit Card payment";
    $payment->update( { payment_method_id => $methods->{credit_card}->id } );

    # delete all flags first
    $order->order_flags->delete;

    $self->engine->apply_finance_flags;

    my $new_card_flag = $order->discard_changes->order_flags
                                ->search( { flag_id => $FLAG__NEW_CARD } )
                                    ->first;
    isa_ok( $new_card_flag, 'XTracker::Schema::Result::Public::OrderFlag',
                                "Found 'New Card' flag" );

    note "Check for Flag when NOT using a Credit Card payment";
    $payment->update( { payment_method_id => $methods->{third_party}->id } );

    # delete all flags
    $order->discard_changes->order_flags->delete;

    $self->new_engine->apply_finance_flags;

    $new_card_flag = $order->discard_changes->order_flags
                                ->search( { flag_id => $FLAG__NEW_CARD } )
                                    ->first;
    ok( !defined $new_card_flag, "Did NOT Find 'New Card' flag" );
}

=head2 test_applying_with_no_credit_check_flag

Test how the 'No Credit Check' flag is being Applied as it has
been a cause for confusion. Also checks that the 2nd & 3rd Order
Flags are only set if the Customer has not actually been Credit
Checked the 1st Order Flag should always be set.

=cut

sub test_applying_with_no_credit_check_flag : Tests {
    my $self    = shift;

    my $email_addr = Test::XTracker::Data->create_unmatchable_customer_email( $self->dbh );

    # need to create a new Customer with no Orders
    my $data  = Test::XT::Data->new_with_traits(
        traits  => [
            'Test::XT::Data::Channel',
            'Test::XT::Data::Customer',
            'Test::XT::Data::Order',
        ],
    );
    $data->email( $email_addr );
    $data->channel( Test::XTracker::Data->channel_for_nap );

    my $channel  = $data->channel;
    my $customer = $data->customer;


    note "With a brand new Customer create a series of Orders and Check for the Flags";

    # create 1st Order
    $self->{order}  = $data->new_order( channel => $channel, customer => $customer )->{order_object};
    $customer->update( { credit_check => \'now()' } );
    $self->new_engine->apply_finance_flags;
    cmp_ok( $self->{order}->has_flag('1st'), '==', 1, "First Order Has '1st' Flag even though Customer has been Credit Checked" );
    cmp_ok( $self->{order}->has_flag('No Credit Check'), '==', 0, "and NOT 'No Credit Check' Flag" );

    # create 2nd Order
    $self->{order}  = $data->new_order( channel => $channel, customer => $customer )->{order_object};
    $customer->update( { credit_check => undef } );
    $self->new_engine->apply_finance_flags;
    cmp_ok( $self->{order}->has_flag('2nd'), '==', 1, "Second Order Has '2nd' Flag" );
    cmp_ok( $self->{order}->has_flag('No Credit Check'), '==', 0, "and NOT 'No Credit Check' Flag" );
    $self->{order}->order_flags->delete;
    $customer->update( { credit_check => \'now()' } );
    $self->new_engine->apply_finance_flags;
    cmp_ok( $self->{order}->has_flag('2nd'), '==', 0,
                        "Second Order does NOT have '2nd' Flag when Customer has been Credit Checked" );

    # create 3rd Order
    $self->{order}  = $data->new_order( channel => $channel, customer => $customer )->{order_object};
    $customer->update( { credit_check => undef } );
    $self->new_engine->apply_finance_flags;
    cmp_ok( $self->{order}->has_flag('3rd'), '==', 1, "Third Order Has '3rd' Flag" );
    cmp_ok( $self->{order}->has_flag('No Credit Check'), '==', 0, "and NOT 'No Credit Check' Flag" );
    $self->{order}->order_flags->delete;
    $customer->update( { credit_check => \'now()' } );
    $self->new_engine->apply_finance_flags;
    cmp_ok( $self->{order}->has_flag('3rd'), '==', 0,
                        "Third Order does NOT have '3rd' Flag when Customer has been Credit Checked" );

    # create 4th Order
    $self->{order}  = $data->new_order( channel => $channel, customer => $customer )->{order_object};
    $customer->update( { credit_check => undef } );
    $self->new_engine->apply_finance_flags;
    cmp_ok( $self->{order}->has_flag('No Credit Check'), '==', 1, "Fourth Order Has 'No Credit Check' Flag" );
    $self->{order}->order_flags->delete;
    $customer->update( { credit_check => \'now()' } );
    $self->new_engine->apply_finance_flags;
    cmp_ok( $self->{order}->has_flag('No Credit Check'), '==', 0,
                        "Fourth Order does NOT have 'No Credit Check' Flag when Customer has been Credit Checked" );

    # create 5th Order
    $self->{order}  = $data->new_order( channel => $channel, customer => $customer )->{order_object};
    $customer->update( { credit_check => undef } );
    $self->new_engine->apply_finance_flags;
    cmp_ok( $self->{order}->has_flag('No Credit Check'), '==', 1, "Fifth Order Has 'No Credit Check' Flag" );


    note "creating an Order on another Sales Channel for the Same 'Customer' should mean 'No Credit Check' Flag should be set";

    $data = Test::XT::Data->new_with_traits(
        traits  => [
            'Test::XT::Data::Channel',
            'Test::XT::Data::Customer',
            'Test::XT::Data::Order',
        ],
    );
    $data->email( $email_addr );
    $data->channel( Test::XTracker::Data->channel_for_mrp );

    $channel  = $data->channel;
    $customer = $data->customer;
    $customer->update( { credit_check => undef } );

    # create 1st Order but 6th Order for Customer
    $self->{order}  = $data->new_order( channel => $channel, customer => $customer )->{order_object};
    $self->new_engine->apply_finance_flags;
    cmp_ok( $self->{order}->has_flag('1st'), '==', 0,
                    "First Order for Channel does NOT have '1st' Flag as it's the 6th Order for the Customer" );
    cmp_ok( $self->{order}->has_flag('No Credit Check'), '==', 1, "and therefore has the 'No Credit Check' Flag" );
}

=head2 test_ccard_warning_flags

Tests whether the Credit Card particular Flags get set or not.

=cut

sub test_ccard_warning_flags : Tests() {
    my $self    = shift;

    my $order   = $self->{order};

    # data used to create an 'orders.payment' record
    my $psp_refs            = Test::XTracker::Data->get_new_psp_refs();
    my $create_payment_args = {
        psp_ref     => $psp_refs->{psp_ref},
        preauth_ref => $psp_refs->{preauth_ref},
    };

    my %tests   = (
        "No Card Payment"   => {
            setup   => {
                with_payment    => 0,
            },
            expect  => {
                'New Card'              => 0,
                'DATA NOT CHECKED'      => 0,
                'SECURITY CODE MATCH'   => 0,
                'ALL MATCH'             => 0,
            },
        },
        "With Card Payment, No Card History & AVS Response of 'DATA NOT CHECKED'" => {
            setup   => {
                with_payment        => 1,
                with_card_history   => 0,
                avs_response        => 'DATA NOT CHECKED',
            },
            expect => {
                'New Card'              => 1,
                'DATA NOT CHECKED'      => 1,
                'SECURITY CODE MATCH'   => 0,
                'ALL MATCH'             => 0,
            },
        },
        "With Card Payment, Card History & AVS Response of 'NONE'" => {
            setup   => {
                with_payment        => 1,
                with_card_history   => 1,
                avs_response        => 'NONE',
            },
            expect => {
                'New Card'              => 0,
                'DATA NOT CHECKED'      => 1,
                'SECURITY CODE MATCH'   => 0,
                'ALL MATCH'             => 0,
            },
        },
        "With Card Payment, Card History & AVS Response of 'SECURITY CODE MATCH ONLY'" => {
            setup   => {
                with_payment        => 1,
                with_card_history   => 1,
                avs_response        => 'SECURITY CODE MATCH ONLY',
            },
            expect => {
                'New Card'              => 0,
                'DATA NOT CHECKED'      => 0,
                'SECURITY CODE MATCH'   => 1,
                'ALL MATCH'             => 0,
            },
        },
        "With Card Payment, No Card History & AVS Response of 'ALL MATCH'" => {
            setup   => {
                with_payment        => 1,
                with_card_history   => 0,
                avs_response        => 'ALL MATCH',
            },
            expect => {
                'New Card'              => 1,
                'DATA NOT CHECKED'      => 0,
                'SECURITY CODE MATCH'   => 0,
                'ALL MATCH'             => 1,
            },
        },
        "With Card Payment, Card History & AVS Response of 'RUBBISH'" => {
            setup   => {
                with_payment        => 1,
                with_card_history   => 1,
                avs_response        => 'RUBBISH',
            },
            expect => {
                'New Card'              => 0,
                'DATA NOT CHECKED'      => 0,
                'SECURITY CODE MATCH'   => 0,
                'ALL MATCH'             => 0,
            },
        },
    );

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test    = $tests{ $label };
        my $setup   = $test->{setup};

        # remove all Flags
        $order->order_flags->delete;

        my $payment = $order->payments->first;
        $payment->delete        if ( $payment );

        if ( $setup->{with_payment} ) {
            Test::XTracker::Data->create_payment_for_order( $order, $create_payment_args );
            Test::XTracker::Mock::PSP->set_card_history( $setup->{with_card_history} ? [ { orderNumber => '99239289248' } ] : [] );
            Test::XTracker::Mock::PSP->set_avs_response( $setup->{avs_response} );
        }
        $order->discard_changes;

        # to clear out the cache get a new instance everytime
        delete $self->{engine};
        $self->engine->apply_finance_flags;

        # only check the Flags that are Expected, don't care about extra ones
        my %got = map { $_->flag->description => 1 } grep {
            exists( $test->{expect}{ $_->flag->description } )
        } $order->discard_changes->order_flags->all;

        cmp_deeply( \%got, subhashof( $test->{expect} ), "Expected Flags assigned to the Order" )
                    or diag "====> " . p( %got );
    }
}

=head2 test_for_paypal_flag

Test when using PayPal as a Payment method that the PayPal flag is applied.

=cut

sub test_for_paypal_flag : Tests {
    my $self = shift;

    my $order   = $self->{order};

    # data used to create an 'orders.payment' record
    my $psp_refs = Test::XTracker::Data->get_new_psp_refs();

    # get the PayPal Third Party Payment Method
    my $paypal_method = $self->rs('Orders::PaymentMethod')
                                ->find( { payment_method => 'PayPal' } );
    # make-up a non PayPal Third Party Payment Method
    my $third_party_method = $self->rs('Orders::PaymentMethod')->update_or_create( {
        payment_method          => 'Test Method',
        payment_method_class_id => $ORDERS_PAYMENT_METHOD_CLASS__THIRD_PARTY_PSP,
        string_from_psp         => 'TEST_METHOD',
        display_name            => 'Test Method',
    } );


    note "Test Using a non-PayPal Third Party Method";
    $order->discard_changes->order_flags->delete;
    $order->payments->delete;
    Test::XTracker::Data->create_payment_for_order( $order, {
        psp_ref        => $psp_refs->{psp_ref},
        preauth_ref    => $psp_refs->{preauth_ref},
        payment_method => $third_party_method,
    } );

    # get a new instance
    delete $self->{engine};
    $self->engine->apply_finance_flags;

    my $found_paypal = scalar grep {
        $_->flag_id == $FLAG__PAID_USING_PAYPAL
    } $order->discard_changes->order_flags->all;
    cmp_ok( $found_paypal, '==', 0, "PayPal flag NOT Found" );


    note "Test Using PayPal Method";
    $order->discard_changes->order_flags->delete;
    $order->payments->delete;
    Test::XTracker::Data->create_payment_for_order( $order, {
        psp_ref        => $psp_refs->{psp_ref},
        preauth_ref    => $psp_refs->{preauth_ref},
        payment_method => $paypal_method,
    } );

    # get a new instance
    delete $self->{engine};
    $self->engine->apply_finance_flags;

    $found_paypal = scalar grep {
        $_->flag_id == $FLAG__PAID_USING_PAYPAL
    } $order->discard_changes->order_flags->all;
    cmp_ok( $found_paypal, '==', 1, "PayPal flag FOUND" );
}

=head2 test_for_klarna_flag

Test when using Klarna as a Payment method that the Klarna flag is applied.

=cut

sub test_for_klarna_flag : Tests {
    my $self = shift;

    my $order   = $self->{order};

    # data used to create an 'orders.payment' record
    my $psp_refs = Test::XTracker::Data->get_new_psp_refs();

    # get the Klarna Third Party Payment Method
    my $klarna_method = $self->rs('Orders::PaymentMethod')
                                ->find( { payment_method => 'Klarna' } );
    # make-up a non Klarna Third Party Payment Method
    my $third_party_method = $self->rs('Orders::PaymentMethod')->update_or_create( {
        payment_method          => 'Test Method',
        payment_method_class_id => $ORDERS_PAYMENT_METHOD_CLASS__THIRD_PARTY_PSP,
        string_from_psp         => 'TEST_METHOD',
        display_name            => 'Test Method',
    } );


    note "Test Using a non-Klarna Third Party Method";
    $order->discard_changes->order_flags->delete;
    $order->payments->delete;
    Test::XTracker::Data->create_payment_for_order( $order, {
        psp_ref        => $psp_refs->{psp_ref},
        preauth_ref    => $psp_refs->{preauth_ref},
        payment_method => $third_party_method,
    } );

    # get a new instance
    delete $self->{engine};
    $self->engine->apply_finance_flags;

    my $found_klarna = scalar grep {
        $_->flag_id == $FLAG__PAID_USING_KLARNA
    } $order->discard_changes->order_flags->all;
    cmp_ok( $found_klarna, '==', 0, "Klarna flag NOT Found" );


    note "Test Using Klarna Method";
    $order->discard_changes->order_flags->delete;
    $order->payments->delete;
    Test::XTracker::Data->create_payment_for_order( $order, {
        psp_ref        => $psp_refs->{psp_ref},
        preauth_ref    => $psp_refs->{preauth_ref},
        payment_method => $klarna_method,
    } );

    # get a new instance
    delete $self->{engine};
    $self->engine->apply_finance_flags;

    $found_klarna = scalar grep {
        $_->flag_id == $FLAG__PAID_USING_KLARNA
    } $order->discard_changes->order_flags->all;
    cmp_ok( $found_klarna, '==', 1, "Klarna flag FOUND" );
}

#-------------------------------------------------------------------------

sub data {
    my $self    = shift;
    return $self->{data};
}

# get a new instance of
# the FraudRules::Engine
sub _new_instance {
    my $self    = shift;

    return XT::FraudRules::Engine->new( {
        order   => $self->{order},
    } );
}

# get an instance of the
# FraudRules::Engine
sub engine {
    my $self    = shift;

    $self->{engine} //= $self->_new_instance;

    return $self->{engine};
}

# always get a new instance of FraudRules::Engine
sub new_engine {
    my $self = shift;

    $self->{engine} = undef;
    return $self->engine;
}

