#!/usr/bin/env perl


use NAP::policy "tt",     'test';

=head1 Generic Tests for 'XTracker::Schema::Result::Public::Customer'

Tests various methods on the 'Public::Customer' Class.

Currently tests:
    * orders_with_undispatched_shipments
    * undispatched_orders_by_shipment_class


First done for CANDO-341.

=cut

use Test::XTracker::Data;

use XTracker::Constants             qw( :application );
use XTracker::Constants::FromDB     qw(
                                        :customer_class
                                        :shipment_class
                                        :shipment_status
                                        :shipment_item_status
                                    );

use XTracker::Config::Local qw( config_var );

use Test::XT::Domain::Payment::Mock;
my $mock_payment = Test::XT::Domain::Payment::Mock->new({ initialise_only => 1} );

# get a schema, sanity check
my $schema  = Test::XTracker::Data->get_schema();
isa_ok($schema, 'XTracker::Schema',"Schema Created");

#----------------------------------------------------------
_test_recent_order_funcs( $schema, 1 );
_test_undispatched_orders_lists( $schema, 1 );
_test_contact_language( $schema, 1 );
_test_customer_locale( $schema, 1 );
_test_misc_methods( $schema, 1 );
_test_get_saved_cards( $schema, 1 );
_test_save_card( $schema, 1 );
#----------------------------------------------------------

done_testing();


# this tests a few methods that use the last/recent Orders for a Customer
sub _test_recent_order_funcs {
    my ( $schea, $oktodo )      = @_;

    SKIP: {
        skip "_test_recent_order_funcs", 1          if ( !$oktodo );

        note "in '_test_recent_order_funcs'";

        $schema->txn_do( sub {
            my ( $channel, $pids )  = Test::XTracker::Data->grab_products( { channel => Test::XTracker::Data->channel_for_nap } );
            my $customer            = Test::XTracker::Data->create_dbic_customer( { channel_id => $channel->id } );

            note "Test Methods return 'undef' when there are a Customer has NO Orders";
            ok( !defined $customer->get_most_recent_order, "'get_most_recent_order' method returns 'undef'" );
            ok( !defined $customer->get_last_invoice_address, "'get_last_invoice_address' method returns 'undef'" );
            ok( !defined $customer->get_last_shipment_address, "'get_last_shipment_address' method returns 'undef'" );

            note "Test with 1 Order";
            my $shipment    = _create_order( $pids, { customer_id => $customer->id, channel_id => $channel->id } );
            my $order       = $shipment->order;

            cmp_ok( $customer->get_most_recent_order->id, '==', $order->id, "'get_most_recent_order' returned the Order" );
            cmp_ok( $customer->get_last_invoice_address()->id, '==', $order->invoice_address_id,
                                        "'get_last_invoice_address' returned the Order's Invoice Address" );
            cmp_ok( $customer->get_last_shipment_address()->id, '==', $shipment->shipment_address_id,
                                        "'get_last_shipment_address' returned the Shipment's Shipment Address" );

            note "Test with 3 Orders";
            _create_order( $pids, { customer_id => $customer->id, channel_id => $channel->id } );       # 2nd Order -- Ignore this
            $shipment   = _create_order( $pids, { customer_id => $customer->id, channel_id => $channel->id } );
            $order      = $shipment->order;

            cmp_ok( $customer->get_most_recent_order->id, '==', $order->id, "'get_most_recent_order' returned the 3rd Order" );
            cmp_ok( $customer->get_last_invoice_address()->id, '==', $order->invoice_address_id,
                                        "'get_last_invoice_address' returned the 3rd Order's Invoice Address" );
            cmp_ok( $customer->get_last_shipment_address()->id, '==', $shipment->shipment_address_id,
                                        "'get_last_shipment_address' returned the 3rd Shipment's Shipment Address" );


            # rollback changes
            $schema->txn_rollback();
        } );
    };

    return;
}


# this tests the methods: 'orders_with_undispatched_shipments'
# and 'undispatched_orders_by_shipment_class'
sub _test_undispatched_orders_lists {
    my ( $schea, $oktodo )      = @_;

    SKIP: {
        skip "_test_undispatched_orders_lists", 1               if ( !$oktodo );

        note "in '_test_undispatched_orders_lists'";

        $schema->txn_do( sub {
            my ( $channel, $pids )  = Test::XTracker::Data->grab_products( { channel => Test::XTracker::Data->channel_for_nap } );
            my $customer            = Test::XTracker::Data->create_dbic_customer( { channel_id => $channel->id } );

            # create some Orders
            my @shipments;
            push @shipments, _create_order( $pids, { customer_id => $customer->id, channel_id => $channel->id,
                                        shipment_status => $SHIPMENT_STATUS__PROCESSING,
                                        shipment_item_status => $SHIPMENT_ITEM_STATUS__NEW,
                                } );
            push @shipments, _create_order( $pids, { customer_id => $customer->id, channel_id => $channel->id,
                                        shipment_class => $SHIPMENT_CLASS__EXCHANGE,
                                        shipment_status => $SHIPMENT_STATUS__PROCESSING,
                                        shipment_item_status => $SHIPMENT_ITEM_STATUS__NEW,
                                } );

            $customer->discard_changes;

            note "basic Counts of Orders";
            cmp_ok( $customer->orders_with_undispatched_shipments->count, '==', 2,
                                            "'orders_with_undispatched_shipments-' - Total Un-Dispatched Orders as Expected: 2" );
            cmp_ok( $customer->undispatched_orders_by_shipment_class->count, '==', 2,
                                            "'undispatched_orders_by_shipment_class' - Total Un-Dispatched Orders as Expected: 2" );
            isa_ok( $customer->undispatched_orders_by_shipment_class->first, "XTracker::Schema::Result::Public::Orders",
                                            "Class Returned by method is as Expected" );
            cmp_ok( $customer->undispatched_orders_by_shipment_class( $SHIPMENT_CLASS__EXCHANGE )->count, '==', 1,
                                            "Total 'Exchange' Class Orders as Expected: 1" );
            cmp_ok( $customer->undispatched_orders_by_shipment_class( $SHIPMENT_CLASS__REPLACEMENT )->count, '==', 0,
                                            "Total 'Replacement' Class Orders as Expected: 0" );

            note "now Dispatch a Shipment and Count again";
            # now set the 'Exchange' Shipment as being 'Dispatched'
            $shipments[1]->update_status( $SHIPMENT_STATUS__DISPATCHED, $APPLICATION_OPERATOR_ID );
            cmp_ok( $customer->orders_with_undispatched_shipments->count, '==', 1,
                                            "'orders_with_undispatched_shipments-' - Total Un-Dispatched Orders as Expected: 1" );
            cmp_ok( $customer->undispatched_orders_by_shipment_class( $SHIPMENT_CLASS__EXCHANGE )->count, '==', 0,
                                            "Total 'Exchange' Class Orders as Expected: 0" );

            note "now update the Dispatched Shipment to being 'Lost', should still not Count";
            $shipments[1]->update_status( $SHIPMENT_STATUS__LOST, $APPLICATION_OPERATOR_ID );
            cmp_ok( $customer->orders_with_undispatched_shipments->count, '==', 1,
                                            "'orders_with_undispatched_shipments-' - Total Un-Dispatched Orders as Expected: 1" );
            cmp_ok( $customer->undispatched_orders_by_shipment_class( $SHIPMENT_CLASS__EXCHANGE )->count, '==', 0,
                                            "Total 'Exchange' Class Orders as Expected: 0" );

            note "set back Dispatched Shipment to 'Processing' and assign all Shipments to the same Order, Count Should be only 1";

            $shipments[1]->shipment_status_logs->delete;
            $shipments[1]->update_status( $SHIPMENT_STATUS__PROCESSING, $APPLICATION_OPERATOR_ID );
            my $order   = $shipments[0]->order;
            $shipments[1]->link_orders__shipments->delete;
            $order->create_related( 'link_orders__shipments', { shipment_id => $shipments[1]->id } );
            $customer->discard_changes;

            cmp_ok( $customer->orders_with_undispatched_shipments->count, '==', 1,
                                            "'orders_with_undispatched_shipments-' - Total Unique Un-Dispatched Orders as Expected: 1" );
            cmp_ok( $customer->undispatched_orders_by_shipment_class( $SHIPMENT_CLASS__EXCHANGE )->count, '==', 1,
                                            "Total 'Exchange' Class Orders as Expected: 1" );


            # rollback changes
            $schema->txn_rollback();
        } );
    };

    return;
}

sub _test_contact_language {
    my ( $schea, $oktodo )      = @_;

    SKIP: {
        skip "_test_contact_language", 1               if ( !$oktodo );

        note "in '_test_contact_language'";

        my $default_language_code  = config_var('Customer', 'default_language_preference');
        my $french_language_code   = 'fr';
        my $german_language_code   = 'de';
        my $invalid_language_code  = 'xx';

        $schema->txn_do( sub {

            my ( $channel, $pids )  = Test::XTracker::Data->grab_products( { channel => Test::XTracker::Data->channel_for_nap } );
            my $customer            = Test::XTracker::Data->create_dbic_customer( { channel_id => $channel->id } );

            # Test for default values

            my $lang = $customer->get_language_preference();

            isa_ok($lang->{language}, 'XTracker::Schema::Result::Public::Language');
            is($lang->{language}->code, $default_language_code, 'language is the default');
            ok($lang->{is_default}, 'language is default');


            # Test for preferrence (French)

            $customer->set_language_preference($french_language_code);
            $lang = $customer->get_language_preference();

            isa_ok($lang->{language}, 'XTracker::Schema::Result::Public::Language');
            is($lang->{language}->code, $french_language_code, 'language is french');
            ok(!$lang->{is_default}, 'language is not default');

            # Test for preferrence (invalid)

            $customer->set_language_preference($invalid_language_code);
            $lang = $customer->get_language_preference;

            isa_ok($lang->{language}, 'XTracker::Schema::Result::Public::Language');
            is($lang->{language}->code, $french_language_code, 'language is the default');
            ok(!$lang->{is_default}, 'language is not default');

            # Test for preferrence (German)

            $customer->set_language_preference($german_language_code);
            $lang = $customer->get_language_preference;

            isa_ok($lang->{language}, 'XTracker::Schema::Result::Public::Language');
            is($lang->{language}->code, $german_language_code, 'language is german');
            ok(!$lang->{is_default}, 'language is not default');

            # Test for preferrence (undef)

            $customer->set_language_preference();
            $lang = $customer->get_language_preference;

            isa_ok($lang->{language}, 'XTracker::Schema::Result::Public::Language');
            is($lang->{language}->code, $german_language_code, 'language is the default');
            ok(!$lang->{is_default}, 'language is not default');

            # rollback changes
            $schema->txn_rollback();
        } );
    };

    return;
}

# tests the Customer Locale, which at
# the moment gives back the language code
sub _test_customer_locale {
    my ( $schea, $oktodo )  = @_;

    SKIP: {
        skip "_test_customer_locale", 1         if ( !$oktodo );

        note "in '_test_customer_locale'";

        my $default_language_code   = config_var('Customer', 'default_language_preference');
        my $french_language_code    = 'fr';

        $schema->txn_do( sub {

            # FOR NOW $customer->locale will return just the Language code
            # that $customer->get_language_preference returns, then when
            # we figure out how to store a Customer's Locale we will get
            # it returning a properl locale e.g. 'en_GB' but for now it will
            # just be 'en'. These tests will need to be updated when Locale
            # is implemented properly.

            my $channel     = Test::XTracker::Data->channel_for_nap;
            my $customer    = Test::XTracker::Data->create_dbic_customer( { channel_id => $channel->id } );

            # Test for default values

            my $lang    = $customer->get_language_preference();
            my $locale  = $customer->locale;
            is( $locale, $default_language_code, "When no language is set, 'locale' is the Default Language Code" );
            is( $locale, $lang->{language}->code, "and is the same as 'get_language_preference'" );

            # Test for preferrence (French)

            $customer->set_language_preference( $french_language_code );
            $lang   = $customer->get_language_preference();
            $locale = $customer->locale;
            is( $locale, $french_language_code, "When language set as French, 'locale' is '${french_language_code}'" );
            is( $locale, $lang->{language}->code, "and is the same as 'get_language_preference'" );


            # rollback changes
            $schema->txn_rollback;
        } );
    };

    return;
}

# tests various miscellaneous methods
sub _test_misc_methods {
    my ( $schema, $oktodo )     = @_;

    SKIP: {
        skip "_test_misc_methods", 1            if ( !$oktodo );

        note "in '_test_misc_methods'";

        $schema->txn_do( sub {
            my $channel = Test::XTracker::Data->channel_for_nap;
            my $customer= Test::XTracker::Data->create_dbic_customer( { channel_id => $channel->id } );

            my @eip_categories  = $schema->resultset('Public::CustomerCategory')
                                            ->search( { customer_class_id => $CUSTOMER_CLASS__EIP } )
                                                ->all;
            my @hot_categories  = $schema->resultset('Public::CustomerCategory')
                                            ->search( { customer_class_id => $CUSTOMER_CLASS__HOT_CONTACT } )
                                                ->all;


            note "TEST: 'is_an_eip' method";
            my $categories  = Test::XTracker::Data->get_allowed_notallowed_statuses( 'Public::CustomerCategory', {
                    allow   => [
                        map { $_->id }
                            @eip_categories
                    ],
                } );

            note "NON EIP Categories";
            foreach my $category ( @{ $categories->{not_allowed} } ) {
                $customer->update( { category_id => $category->id } );
                my $result  = $customer->is_an_eip;
                ok( defined $result && $result == 0, "Category: '" . $category->category . "', Returns FALSE" );
            }

            note "EIP Categories";
            foreach my $category ( @{ $categories->{allowed} } ) {
                $customer->update( { category_id => $category->id } );
                my $result  = $customer->is_an_eip;
                ok( defined $result && $result == 1, "Category: '" . $category->category . "', Returns TRUE" );
            }


            note "TEST: 'should_not_have_shipping_costs_recalculated' method";

            note "with No Customer Categories set to 'Not Re-Calc Shipping Costs' in System Config";
            Test::XTracker::Data->remove_config_group( 'Customer', $channel );
            Test::XTracker::Data->create_config_group( 'Customer', { channel => $channel, settings => [] } );

            my @all_categories = $schema->resultset('Public::CustomerCategory')->all;
            foreach my $category ( @all_categories ) {
                $customer->update( { category_id => $category->id } );
                my $got = $customer->should_not_have_shipping_costs_recalculated;
                ok( defined $got && $got == 0, "Category: '" . $category->category . "', Returns FALSE" );
            }

            note "with one Customer Category Class set in System Config: EIP";
            Test::XTracker::Data->remove_config_group( 'Customer', $channel );
            Test::XTracker::Data->create_config_group( 'Customer', {
                channel  => $channel,
                settings => [
                    { setting => 'no_shipping_cost_recalc_customer_category_class', value => 'EIP' },
                ],
            } );

            note "NON EIP Categories";
            foreach my $category ( @{ $categories->{not_allowed} } ) {
                $customer->update( { category_id => $category->id } );
                my $got  = $customer->should_not_have_shipping_costs_recalculated;
                ok( defined $got && $got == 0, "Category: '" . $category->category . "', Returns FALSE" );
            }

            note "EIP Categories";
            foreach my $category ( @{ $categories->{allowed} } ) {
                $customer->update( { category_id => $category->id } );
                my $got = $customer->should_not_have_shipping_costs_recalculated;
                ok( defined $got && $got == 1, "Category: '" . $category->category . "', Returns TRUE" );
            }

            note "with two Customer Category Classes set in System Config: EIP & Hot Contact";
            Test::XTracker::Data->remove_config_group( 'Customer', $channel );
            Test::XTracker::Data->create_config_group( 'Customer', {
                channel  => $channel,
                settings => [
                    # also check case doesn't matter and used mixed cased values
                    { setting => 'no_shipping_cost_recalc_customer_category_class', sequence => 1, value => 'EiP' },
                    { setting => 'no_shipping_cost_recalc_customer_category_class', sequence => 2, value => 'hoT conTact' },
                ],
            } );

            $categories = Test::XTracker::Data->get_allowed_notallowed_statuses( 'Public::CustomerCategory', {
                    allow   => [
                        map { $_->id }
                            @eip_categories,
                            @hot_categories,
                    ],
                } );

            note "NON EIP & Hot Contact Categories";
            foreach my $category ( @{ $categories->{not_allowed} } ) {
                $customer->update( { category_id => $category->id } );
                my $got  = $customer->should_not_have_shipping_costs_recalculated;
                ok( defined $got && $got == 0, "Category: '" . $category->category . "', Returns FALSE" );
            }

            note "EIP & Hot Contact Categories";
            foreach my $category ( @{ $categories->{allowed} } ) {
                $customer->update( { category_id => $category->id } );
                my $got = $customer->should_not_have_shipping_costs_recalculated;
                ok( defined $got && $got == 1, "Category: '" . $category->category . "', Returns TRUE" );
            }


            # rollback changes
            $schema->txn_rollback();
        } );
    };

    return;
}

sub _test_get_saved_cards {
    my ($schema, $oktodo) = @_;

    SKIP: {
        skip "_test_get_saved_cards", 1            if ( !$oktodo );
        note "in '_test_get_saved_cards'";

        my $channel  = Test::XTracker::Data->channel_for_nap;
        my $customer = Test::XTracker::Data->create_dbic_customer( { channel_id => $channel->id } );
        my $token_id = 'xxx123';
        my $payment  = XT::Domain::Payment->new();

        my $random_operator = $schema->resultset('Public::Operator')->find($APPLICATION_OPERATOR_ID);

        $customer->update({
            account_urn => 'mock123'
        })->discard_changes;

        my $saved_cards_req = {
            site        => lc($customer->channel->website_name),
            userID      => $random_operator->id,
            customerID  => $customer->pws_customer_id,
            cardToken   => $token_id
        };

        # Grab the default cards
        my @default_cards = @{ $mock_payment->psp_saved_cards };

        # Call 'getcustomer_saved_cards' again so we can later mock the 'getinfo_saved_card' method in the production code
        $mock_payment->getcustomer_saved_cards($saved_cards_req);

        # Test method without token
        cmp_ok(scalar @{$customer->get_saved_cards({
            operator  => $random_operator
        })}, '==', 0, 'Empty array returned for undef token');

        # Test method without operator
        cmp_ok(scalar @{$customer->get_saved_cards({
            cardToken => $token_id,
        })}, '==', 0, 'Empty array returned for undef operator');

        # Test method with token
        my @savedcards = @{$customer->get_saved_cards({
            cardToken => $token_id,
            operator  => $random_operator
        })};

        is_deeply([@default_cards], [@savedcards], 'Cards returned as expected');
    }
}

sub _test_save_card {
    my ($schema, $oktodo) = @_;

    SKIP: {
        skip "_test_get_saved_cards", 1            if ( !$oktodo );
        note "in '_test_save_card'";

        my $channel  = Test::XTracker::Data->channel_for_nap;
        my $customer = Test::XTracker::Data->create_dbic_customer( { channel_id => $channel->id } );
        my $payment  = XT::Domain::Payment->new();

        $customer->update({
            account_urn => 'mock123'
        })->discard_changes;

        my $mock_args = {
            operator        => $schema->resultset('Public::Operator')->find($APPLICATION_OPERATOR_ID),
            cardToken       => 'erertertwegwhwtg',
            cardExpiryDate  => '0316',
            cardLast4Digits => '3242',
            cardNumber      => '923479237459237',
            cardHoldersName => 'drghergt',
        };

        $mock_payment->save_card({
            site       => lc($customer->channel->website_name),
            userID     => $mock_args->{operator}->id,
            customerID => $customer->pws_customer_id,
            cardToken  =>  $mock_args->{cardToken},
            creditCardReadOnly => {
                cardToken       => $mock_args->{cardToken},
                customerId      => $customer->pws_customer_id,
                expiryDate      => $mock_args->{cardExpiryDate},
                cardType        => $mock_args->{cardType},
                last4Digits     => $mock_args->{cardLast4Digits},
                cardNumber      => $mock_args->{cardNumber},
                cardHoldersName => $mock_args->{cardHoldersName},
            }
        });

        ok($customer->save_card({
            cardToken       => $mock_args->{cardToken},
            cardExpiryDate  => $mock_args->{cardExpiryDate},
            cardType        => $mock_args->{cardType},
            cardLast4Digits => $mock_args->{cardLast4Digits},
            cardNumber      => $mock_args->{cardnumber},
            cardHoldersName => $mock_args->{cardHoldersName},
            operator        => $mock_args->{operator}
        }), 'saved cards was succesfull');
    }
}

#-------------------------------------------------------------------------------------

# helper to create an Order
sub _create_order {
    my ( $pids, $args )     = @_;

    my $shipment_class      = delete( $args->{shipment_class} );

    my $invoice_addr        = Test::XTracker::Data->create_order_address_in('current_dc', { address_line_2 => 'Invoice' } );
    my $shipment_addr       = Test::XTracker::Data->create_order_address_in('current_dc', { address_line_2 => 'Shipment' } );

    my ( $order, undef )    = Test::XTracker::Data->create_db_order( { pids => $pids, base => $args } );

    my $shipment    = $order->shipments->first;
    $shipment->update( { shipment_class_id => $shipment_class } )       if ( $shipment_class );

    # update Addresses
    $order->update( { invoice_address_id => $invoice_addr->id } );
    $shipment->update( { shipment_address_id => $shipment_addr->id } );

    return $shipment->discard_changes;
}
