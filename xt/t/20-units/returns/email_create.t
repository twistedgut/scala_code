#!/usr/bin/env perl

use NAP::policy "tt", 'test';

use FindBin::libs;

=head1 NAME

email_create.t - Emails when Creating Returns/Exchanges

=head1 DESCRIPTION

Tests the Emails that get generated when various kinds for Returns/Exchanges get
created. Also tests refunding to Credit Card, Store Credit and both.

    * Test No Exchange Charges using the Normal Returns Domain
    * Test No Exchange Charges using the ARMA Returns Domain
    * Test With Exchange Charges
    * Test With Auto Confirmation of Exchange Charges

#TAGS returns shouldbeunit checkruncondition loops

=cut

use Test::XTracker::Data;
use Test::XTracker::MessageQueue;
use Test::Most;

use Carp;
use Catalyst::Utils qw/merge_hashes/;

# CANDO - 1741
# Not switching it ON for DC3 as the email templates are not finalised yet.
# Also the emails are now migrated to CMS so it is not worth the effort to make this test
# pass for DC3 anyways.

use Test::XTracker::RunCondition
                        dc => [ qw( DC1 DC2 ) ],
                        export => [ qw( $distribution_centre ) ];
use Test::XTracker::Data::Email;
use Test::XTracker::MessageQueue;

use XT::Domain::Returns;
use XTracker::Config::Local     qw( :DEFAULT rma_cutoff_days_for_email_copy_only rma_expiry_days customercare_email );
use XTracker::Constants         qw( :application );
use XTracker::Constants::FromDB qw/
    :correspondence_templates
    :currency
    :customer_issue_type
    :refund_charge_type
    :renumeration_class
    :renumeration_status
    :renumeration_type
    :shipment_type
/;

use base 'Test::Class';

sub startup : Tests(startup => no_plan) {
    my $test = shift;

    my $schema = Test::XTracker::Data->get_schema;
    $test->{schema} = $schema;

    foreach my $business ( 'nap','out','mrp', 'jc' ) {
        my $channel = Test::XTracker::Data->channel_for_business(name => $business);
        my $pids = Test::XTracker::Data->find_or_create_products({
            how_many => 2,
            channel_id => $channel->id,
        });
        $test->{ $channel->id }{skus}   = [ map {$_->{sku}} sort { $a->{sku} cmp $b->{sku} } @$pids ];
        $test->{ $channel->id }{channel}= $channel;
    }

    # normal returns domain not called in ARMA context (i.e. not the AMQ one)
    $test->{domain} = XT::Domain::Returns->new(
        schema => $schema,
        msg_factory => Test::XTracker::MessageQueue->new({schema => $schema}),
    );

    # get the returns domain as called in ARMA context (when in AMQ)
    $test->{arma_domain} = XT::Domain::Returns->new(
        schema => $schema,
        msg_factory => Test::XTracker::MessageQueue->new({schema => $schema}),
        requested_from_arma => 1,
    );

    $test->{expiry_date} = DateTime->new(year => 2009, month => 10, day => 22);
    $test->{dc}          = $distribution_centre;
    $test->{dc_country}  = $schema->resultset('Public::Country')
                                    ->search( { country => config_var( 'DistributionCentre', 'country' ) } )
                                        ->first;
    $test->{currency}    = $schema->resultset('Public::Currency')
                                    ->search( { currency => config_var( 'Currency', 'local_currency_code' ) } )
                                        ->first;
    $test->{channel_brand_name} = {
                    nap => 'NET-A-PORTER',
                    out => 'THE OUTNET',
                    mrp => 'MR PORTER',
                    jc  => 'JIMMY CHOO',
                };
}

sub test_rma_expiry_date_is_correct : Tests {
    my $test = shift;
    note "Testing the RMA Expiry Date is correct per Sales Channel";

    foreach my $business ( 'nap', 'out', 'mrp', 'jc' ) {
        my $channel = Test::XTracker::Data->channel_for_business( name => $business );
        note "Sales Channel: ".$channel->name;

        # set-up dates for the test
        my $expiry_days         = rma_expiry_days( $channel );
        my $now                 = DateTime->now; # not specifying timezone as XT::Domain::Returns::Email doesn't
        my $expected_now_date   = $now->clone->add( days => $expiry_days );
        my $return_date         = $now->clone->set( day => 3, month => 4, year => 2011 );
        my $expected_exp_date   = $return_date->clone->add( days => $expiry_days );

        my $expiry_date = $test->{domain}->_default_return_expiry_date( $channel, $return_date );
        ok( $test->_datetimes_close_with_tolerance( $expiry_date, $expected_exp_date, 5 ),
                            "Passing in a Return Date (".$return_date.") - Expiry Date as expected $expiry_days days greater: ".$expiry_date, );
        $expiry_date    = $test->{domain}->_default_return_expiry_date( $channel );
        ok( $test->_datetimes_close_with_tolerance( $expiry_date, $expected_now_date, 5 ),
                            "NOT Passing in a Return Date - Expiry Date as expected $expiry_days days greater than now (".$now."): ".$expiry_date, );
    }
}

sub test_2_items_only_1_return : Tests {
    my $test = shift;
    for my $shipment_type_id (
        $SHIPMENT_TYPE__PREMIER,
        $SHIPMENT_TYPE__DOMESTIC,
        $SHIPMENT_TYPE__INTERNATIONAL,
    ) {
        for my $renumeration_type_id (
            0,
            $RENUMERATION_TYPE__STORE_CREDIT,
            $RENUMERATION_TYPE__CARD_REFUND,
        ) {
            #$test->_test_2_items_only_1_return( $shipment_type_id, $renumeration_type_id );
        }
    }
    my $shipment_type_id = $SHIPMENT_TYPE__DOMESTIC;
    my $renumeration_type_id = $RENUMERATION_TYPE__STORE_CREDIT;
    $test->_test_2_items_only_1_return( $shipment_type_id, $renumeration_type_id );
}

# Some basic tests on the content of the email when there are 2 items on the
# order, but only one is in the return
sub _test_2_items_only_1_return {
    my ($test, $shipment_type_id, $renumeration_type_id ) = @_;

    foreach my $invoice_address_type (qw( customer random )) {
        note "Setting invoice address type to $invoice_address_type";

        my $channel     = Test::XTracker::Data->channel_for_business(name => 'nap');
        my $customer = Test::XTracker::Data->create_dbic_customer({channel_id => $channel->id});

        my ($order, $shipment, undef, $si) = $test->make_order({shipment_type => $shipment_type_id,
                                                                invoice_address_type => $invoice_address_type,
                                                                customer_id => $customer->id,
                                                                channel_id => $channel->id,
                                                                });
        my $ret = $test->{domain}->render_email( {
            operator_id => 1,
            shipment_id => $shipment->id,
            pickup => 0,
            rma_number => 'U123-456',
            #renumerations => $renumeration,
            refund_type_id => $renumeration_type_id,
            return_items => {
                $si->id => {
                    type => 'Return',
                    reason_id => $CUSTOMER_ISSUE_TYPE__7__IT_DOESN_APOS_T_FIT_ME,
                }
            },
            charge_tax => 0,
            charge_duty => 0,
            return_expiry_date => $test->{expiry_date},
            email_type => $CORRESPONDENCE_TEMPLATES__RETURN_FSLASH_EXCHANGE,
        }, $CORRESPONDENCE_TEMPLATES__RETURN_FSLASH_EXCHANGE);

        #cando-1282
        ok(defined $ret->{email_subject}, "email subject is not-null");
        ok(defined $ret->{email_content_type}, "Content type is not-null");

        my $content = $ret->{email_body};
        $test->_common_email_tests($shipment, $content, $shipment_type_id, 'nap');

        # Look for the '- Brian Atwood Wagner patent peep-toes - size 38.5' lines
        my (@items) = $content =~ /^(- .* - size .*)$/mg;
        cmp_ok(@items, '==', 1, 'email lists 1 item') or diag "@items";

        my ( $refund_line ) = $content =~ m{^(.*? we will credit.*)$}m;
        ok( length $refund_line, 'found refund line' );
        like( $refund_line, qr{\b250\b}, 'refund amount correct' );
    }
}

sub test_store_credit_and_card_refund : Tests {
    my $test = shift;
    foreach my $business ( 'nap', 'out', 'mrp', 'jc' ) {
        foreach my $ship_type_id ( $SHIPMENT_TYPE__DOMESTIC, $SHIPMENT_TYPE__PREMIER ) {
            $test->_test_store_credit_and_card_refund( $business, $ship_type_id );
        }
    }
}

sub _test_store_credit_and_card_refund {
    my ( $test, $business, $ship_type_id )  = @_;

    foreach my $invoice_address_type (qw( customer random )) {
        note "Setting invoice address type to $invoice_address_type";

        my $channel = Test::XTracker::Data->channel_for_business(name => $business);
        note "Shipment Type Id: $ship_type_id, Sales Channel: ".$channel->name;

        my $card_refund_price = 40;
        my $shipment_type_id = $ship_type_id;

        my $customer = Test::XTracker::Data->create_dbic_customer({channel_id => $channel->id});

        my ( $order, $shipment, $si ) = $test->make_order({
            shipment_type => $shipment_type_id,
            invoice_address_type => $invoice_address_type,
            customer_id => $customer->id,
            (channel_id => $channel->id),
            tenders => [
                { type => 'card_debit', value => $card_refund_price },
                # The rest of the order value gets created as a store credit row for us.
            ]
        });
        # zero Shipping Charge to get round peculiar
        # The Outnet Shipping Charge refund rules
        # as that's not what is being tested for here
        $shipment->update( { shipping_charge => 0 } );

        my $store_credit_price = $si->unit_price - $card_refund_price;
        my $content = $test->{domain}->render_email({
            operator_id => 1,
            shipment_id => $shipment->id,
            pickup => 0,
            rma_number => 'U123-456',
            return_items => {
                $si->id => {
                    type => 'Return',
                    reason_id => $CUSTOMER_ISSUE_TYPE__7__IT_DOESN_APOS_T_FIT_ME,
                },
            },
            charge_tax => 0,
            charge_duty => 0,
            return_expiry_date => $test->{expiry_date},
            email_type => $CORRESPONDENCE_TEMPLATES__RETURN_FSLASH_EXCHANGE,
        }, $CORRESPONDENCE_TEMPLATES__RETURN_FSLASH_EXCHANGE )->{email_body};

        $test->_common_email_tests($shipment, $content, $shipment_type_id, $business );

        my $brand_name  = $test->{channel_brand_name}{ $business };
        my $currency    = $test->{currency}->currency;
        my $sc_price    = sprintf( "%0.2f", $store_credit_price );      # content is to 2 decimal places
        my $cc_price    = sprintf( "%0.2f", $card_refund_price );       # content is to 2 decimal places

        like( $content, qr{\r?\n\r?\nAs soon as we receive and process your return, we will refund:\r?\n},
                            "got heading message detailing how you will be refunded" );
        like( $content, qr{- $cc_price $currency to your card},
                            'card refund found' );
        like( $content, qr{- $sc_price $currency as store credit to your $brand_name account},
                            'store credit refund found' );
    }
}

sub test_outnet_2_items_only_1_return : Tests {
    my $test = shift;
    for my $renumeration_type_id (
        0,
        $RENUMERATION_TYPE__STORE_CREDIT,
        $RENUMERATION_TYPE__CARD_REFUND,
    ) {
        for my $email_type ('', 'faulty', 'late_credit_only') {
            $test->_test_outnet_2_items_only_1_return($SHIPMENT_TYPE__DOMESTIC, $renumeration_type_id, undef, $email_type);
            $test->_test_outnet_2_items_only_1_return($SHIPMENT_TYPE__DOMESTIC, $renumeration_type_id, '1234awb', $email_type);
            $test->_test_outnet_2_items_only_1_return($SHIPMENT_TYPE__INTERNATIONAL, $renumeration_type_id, undef, $email_type);
        }
    }
}

sub _test_outnet_2_items_only_1_return {
    my ($test, $shipment_type_id, $renumeration_type_id, $return_awb, $email_type) = @_;

    foreach my $invoice_address_type (qw( customer random )) {
        note "Setting invoice address type to $invoice_address_type";

        my $channel = Test::XTracker::Data->channel_for_business(name => 'out');

        my $customer = Test::XTracker::Data->create_dbic_customer({channel_id => $channel->id});

        my ($order, $shipment, $si) = $test->make_order({
            shipment_type => $shipment_type_id,
            customer_id => $customer->id,
            invoice_address_type => $invoice_address_type,
            channel_id => $channel->id,
            return_airway_bill => $return_awb,
            shipping_account_id => $shipment_type_id == $SHIPMENT_TYPE__DOMESTIC
                                ? 6 # 'International Road'
                                : 0
        });

        my $content = $test->{domain}->render_email({
            operator_id => 1,
            shipment_id => $shipment->id,
            pickup => 0,
            rma_number => 'U123-456',
            refund_type_id => $renumeration_type_id,
            return_items => {
                $si->id => {
                    type => 'Return',
                    reason_id => $CUSTOMER_ISSUE_TYPE__7__IT_DOESN_APOS_T_FIT_ME,
                }
            },
            charge_tax => 0,
            charge_duty => 0,
            return_expiry_date => $test->{expiry_date},
            email_type => $email_type,
        }, $CORRESPONDENCE_TEMPLATES__RETURN_FSLASH_EXCHANGE )->{email_body};

        $test->_common_email_tests(
            $shipment,
            $content,
            $shipment_type_id,
            'outnet',
            $return_awb);

        # Look for the '- Brian Atwood Wagner patent peep-toes - size 38.5' lines
        my (@items) = $content =~ /^(- .* - size .*)$/mg;
        cmp_ok(@items, '==', 1, 'email lists 1 item');
    }
}

sub test_2_items_both_returned : Tests {
    my $test = shift;
    for my $renumeration_type_id (
        0,
        $RENUMERATION_TYPE__STORE_CREDIT,
        $RENUMERATION_TYPE__CARD_REFUND,
    ) {
        for my $email_type ('', 'faulty', 'late_credit_only') {
            for my $business ( 'nap', 'out', 'mrp', 'jc' ) {
                $test->_test_2_items_both_returned($renumeration_type_id, $business, $email_type);
            }
        }
    }
}

sub _test_2_items_both_returned {
    my ($test, $renumeration_type_id, $business, $email_type) = @_;

    foreach my $invoice_address_type (qw( customer random )) {
        note "Setting invoice address type to $invoice_address_type";

        my $channel = Test::XTracker::Data->channel_for_business(name => $business);
        my $customer = Test::XTracker::Data->create_dbic_customer({channel_id => $channel->id});

        note "testing - Renumeration Type Id: $renumeration_type_id, Business: $business, Email Type: $email_type";

        my ($order, $shipment, $si1, $si2) = $test->make_order({
            items => { $test->{ $channel->id }{skus}[0] => { _no_return => 0} },
            shipment_type => $SHIPMENT_TYPE__INTERNATIONAL,
            customer_id => $customer->id,
            invoice_address_type => $invoice_address_type,
            (channel_id => $channel->id),
            tenders => [
                    { type => (
                                $email_type ne 'late_credit_only'
                                    && $renumeration_type_id == $RENUMERATION_TYPE__CARD_REFUND
                                ? 'card_debit'
                                : 'store_credit'
                                ) },
                ],
        });

        my $content = $test->{domain}->render_email( {
            operator_id => 1,
            shipment_id => $shipment->id,
            pickup => 0,
            rma_number => 'U123-456',
            refund_type_id => $renumeration_type_id,
            return_items => {
                $si1->id => {
                    type => 'Return',
                    reason_id => $CUSTOMER_ISSUE_TYPE__7__IT_DOESN_APOS_T_FIT_ME,
                },
                $si2->id => {
                    type => 'Return',
                    reason_id => $CUSTOMER_ISSUE_TYPE__7__IT_DOESN_APOS_T_FIT_ME,
                }
            },
            charge_tax => 0,
            charge_duty => 0,
            return_expiry_date => $test->{expiry_date},
            email_type => $email_type,
        }, $CORRESPONDENCE_TEMPLATES__RETURN_FSLASH_EXCHANGE )->{email_body};

        $test->_common_email_tests($shipment, $content, $SHIPMENT_TYPE__INTERNATIONAL, $business);

        # Look for the '- Brian Atwood Wagner patent peep-toes - size 38.5' lines
        my (@items) = $content =~ /^(- .* - size .*)$/mg;
        cmp_ok(@items, '==', 2, 'email lists 2 items')
            or diag "@items";

        $test->_single_refund_message_tests( $shipment, $content, $renumeration_type_id, $business, $email_type );

        if ( $email_type eq 'late_credit_only' ) {
            # see that the email states how days the customer should have requested the RMA in
            my $cutoff_days     = rma_cutoff_days_for_email_copy_only( $channel );
            like( $content, qr/of your wish to return within\s+${cutoff_days} days of receiving/s,
                                    "Late RMA states how many days the Customer Should have requested the RMA: $cutoff_days" );
        }

        if ( $business ne 'jc' ) {
            if ( $email_type eq 'faulty' ) {
                unlike( $content, qr/your returned items meet the conditions of our Returns Policy/,
                                    "'returned items meet the conditions' message NOT displayed" );
                like( $content, qr/\.\r?\n\r?\nWe/, "the text doesn't have any extra lines since the 'conditions' message isn't there" );
            }
            else {
                like( $content, qr/\.\r?\n\r?\n.*your returned items meet the conditions of our Returns Policy.*\r?\n\r?\nWe/,
                                    "'returned items meet the conditions' message displayed properly" );
            }
        }
    }
}

sub test_2_items_refund_and_exchange : Tests {
    my $test = shift;
    for my $renumeration_type_id (
        0,
        $RENUMERATION_TYPE__STORE_CREDIT,
        $RENUMERATION_TYPE__CARD_REFUND,
    ) {
        for my $email_type ('', 'faulty', 'late_credit_only') {
            for my $business ( 'nap', 'out', 'mrp' ) {
                $test->_test_2_items_refund_and_exchange($renumeration_type_id, $business, $email_type);
            }
        }
    }
}

sub _test_2_items_refund_and_exchange {
    my ( $test, $renumeration_type_id, $business, $email_type ) = @_;

    foreach my $invoice_address_type (qw( customer random )) {
        note "Setting invoice address type to $invoice_address_type";

        my $channel = Test::XTracker::Data->channel_for_business(name => $business);
        my $customer = Test::XTracker::Data->create_dbic_customer({channel_id => $channel->id});

        my ($order, $shipment, $si1, $si2) = $test->make_order({
            items => { $test->{ $channel->id }{skus}[0] => { _no_return => 0} },
            shipment_type => $SHIPMENT_TYPE__INTERNATIONAL,
            customer_id => $customer->id,
            invoice_address_type => $invoice_address_type,
            (channel_id => $channel->id),
        });

        my $var_id = Test::XTracker::Data->get_schema
                                        ->resultset('Public::Variant')
                                        ->find_by_sku($test->{ $channel->id }{skus}[1])
                                        ->id;

        my $content = $test->{domain}->render_email( {
            operator_id => 1,
            shipment_id => $shipment->id,
            pickup => 0,
            rma_number => 'U123-456',
            refund_type_id => $renumeration_type_id,
            return_items => {
            $si1->id => {
                type => 'Exchange',
                reason_id => $CUSTOMER_ISSUE_TYPE__7__IT_DOESN_APOS_T_FIT_ME,
                exchange_variant => $var_id,
            },
            $si2->id => {
                type => 'Return',
                reason_id => $CUSTOMER_ISSUE_TYPE__7__IT_DOESN_APOS_T_FIT_ME,
            }
            },
            charge_tax => 0,
            charge_duty => 0,
            return_expiry_date => $test->{expiry_date},
            email_type => $email_type,
        }, $CORRESPONDENCE_TEMPLATES__RETURN_FSLASH_EXCHANGE )->{email_body};

        $test->_common_email_tests($shipment, $content, $SHIPMENT_TYPE__INTERNATIONAL, $business);

        # Look for the '- Brian Atwood Wagner patent peep-toes - size 38.5' lines
        my (@items) = $content =~ /^(- .* - size .*)$/mg;
        # 2 items, plus 1 extra line for the exchange item
        cmp_ok(@items, '==', 3, 'email lists 3 items')
        or diag "@items";
    }
}

sub test_2_items_only_1_exchange : Tests {
    my $test = shift;
    for my $business ( 'nap', 'out', 'mrp' ) {
        note "TESTING Channel: $business";
        $test->_test_2_items_only_1_exchange( $business );
    }
}

sub _test_2_items_only_1_exchange {
    my ( $test, $business ) = @_;

    foreach my $invoice_address_type (qw( customer random )) {
        note "Setting invoice address type to $invoice_address_type";

        my $channel = Test::XTracker::Data->channel_for_business(name => $business);

        my $customer = Test::XTracker::Data->create_dbic_customer({channel_id => $channel->id});

        my ($order, $shipment, $si1, $si2) = $test->make_order({
            items => { $test->{ $channel->id }{skus}[0] => { _no_return => 0} },
            shipment_type => $SHIPMENT_TYPE__INTERNATIONAL,
            customer_id => $customer->id,
            invoice_address_type => $invoice_address_type,
            (channel_id => $channel->id),
        });

        my $var_id = Test::XTracker::Data->get_schema
                                        ->resultset('Public::Variant')
                                        ->find_by_sku($test->{ $channel->id }{skus}[0])
                                        ->id;

        # set-up general arguments to render the email
        my $render_args = {
                operator_id => 1,
                shipment_id => $shipment->id,
                pickup => 0,
                rma_number => 'U123-456',
                refund_type_id => $RENUMERATION_TYPE__CARD_REFUND,
                return_items => {
                    $si1->id => {
                        type => 'Exchange',
                        reason_id => $CUSTOMER_ISSUE_TYPE__7__IT_DOESN_APOS_T_FIT_ME,
                        exchange_variant => $var_id,
                    },
                },
                charge_tax => 0,
                charge_duty => 0,
                return_expiry_date => $test->{expiry_date},
                email_type => "",
            };

        #
        # Test No Exchange Charges using the Normal Returns Domain
        #

        # use the normal returns domain
        my $content = $test->{domain}->render_email( $render_args , $CORRESPONDENCE_TEMPLATES__RETURN_FSLASH_EXCHANGE )->{email_body};
        $test->_common_email_tests($shipment, $content, $SHIPMENT_TYPE__INTERNATIONAL, $business);
        $test->_common_email_exchange_tests( $content, $business, { test_type => 'without_charges', num_items => 2,
                                                                    currency => $order->currency->currency, } );

        #
        # Test No Exchange Charges using the ARMA Returns Domain
        #

        # use the ARMA returns domain
        $content    = $test->{arma_domain}->render_email( $render_args , $CORRESPONDENCE_TEMPLATES__RETURN_FSLASH_EXCHANGE )->{email_body};
        $test->_common_email_tests($shipment, $content, $SHIPMENT_TYPE__INTERNATIONAL, $business);
        $test->_common_email_exchange_tests( $content, $business, { test_type => 'without_charges', num_items => 2,
                                                                    currency => $order->currency->currency, } );

        #
        # Test With Exchange Charges
        #

        $render_args->{charge_tax}  = 5;
        $render_args->{charge_duty} = 10;
        my $total_charge = $render_args->{charge_tax} + $render_args->{charge_duty};

        # use the normal returns domain
        $content    = $test->{domain}->render_email( $render_args , $CORRESPONDENCE_TEMPLATES__RETURN_FSLASH_EXCHANGE )->{email_body};
        $test->_common_email_tests($shipment, $content, $SHIPMENT_TYPE__INTERNATIONAL, $business);
        $test->_common_email_exchange_tests( $content, $business, { test_type => 'with_charges', num_items => 2,
                                                                    total_charge => $total_charge, currency => $order->currency->currency, } );

        #
        # Test With Auto Confirmation of Exchange Charges
        #

        # use the ARMA returns domain
        $content    = $test->{arma_domain}->render_email( $render_args , $CORRESPONDENCE_TEMPLATES__RETURN_FSLASH_EXCHANGE )->{email_body};

        $test->_common_email_tests($shipment, $content, $SHIPMENT_TYPE__INTERNATIONAL, $business);
        $test->_common_email_exchange_tests( $content, $business, { test_type => 'auto_confirm_charges', num_items => 2,
                                                                    total_charge => $total_charge, currency => $order->currency->currency, } );
    }
}

sub test_refund_tax_and_duty_country : Tests {
    my $test = shift;
    note "TEST that the appropriate message is shown when a refund is for a Country that refunds BOTH Tax & Duty";

    my $schema  = $test->{schema};

    $schema->txn_do( sub {
        # get a foreign country to the DC and make sure
        # it will have Tax & Duty refunded
        my $country = $schema->resultset('Public::Country')
                                ->search( { id => { '!=' => $test->{dc_country}->id } } )
                                    ->first;
        $country->return_country_refund_charges->delete;        # remove any current records
        $country->create_related( 'return_country_refund_charges', { refund_charge_type_id => $REFUND_CHARGE_TYPE__TAX, can_refund_for_return => 1 } );
        $country->create_related( 'return_country_refund_charges', { refund_charge_type_id => $REFUND_CHARGE_TYPE__DUTY, can_refund_for_return => 1 } );

        foreach my $renum_type_id ( $RENUMERATION_TYPE__STORE_CREDIT, $RENUMERATION_TYPE__CARD_REFUND ) {
            foreach my $business ( 'nap', 'out', 'mrp', 'jc' ) {
                foreach my $with_duty ( 1, 0 ) {
                    $test->_test_refund_tax_and_duty_country( $country, $renum_type_id, $business, $with_duty );
                }
            }
        }

        # rollback changes made
        $schema->txn_rollback();
    } );
}

sub _test_refund_tax_and_duty_country {
    my ( $test, $country, $renum_type_id, $business, $with_duty )   = @_;

    foreach my $invoice_address_type (qw( customer random )) {
        note "Setting invoice address type to $invoice_address_type";

        note "testing - Renumeration Type Id: $renum_type_id, Business: $business, With Duty: " . ( $with_duty ? 'Yes' : 'No' );

        my $channel = Test::XTracker::Data->channel_for_business(name => $business);

        my $customer = Test::XTracker::Data->create_dbic_customer({channel_id => $channel->id});

        my ($order, $shipment, $si1, $si2) = $test->make_order({
            items => {
                        $test->{ $channel->id }{skus}[0] => { price => 100, tax => 15, duty => 0 },
                        $test->{ $channel->id }{skus}[1] => { price => 250, tax => 30, duty => ( 57 * $with_duty ) },
                    },
            shipment_type => $SHIPMENT_TYPE__INTERNATIONAL,
            customer_id => $customer->id,
            invoice_address_type => $invoice_address_type,
            (channel_id => $channel->id),
            shipping_charge => 10,
            tenders => [
                    { type => (
                                $renum_type_id == $RENUMERATION_TYPE__CARD_REFUND
                                ? 'card_debit'
                                : 'store_credit'
                                ),
                        value => ( 405 + ( 57 * $with_duty ) ),
                    },
                ],
        });
        # update the Shipping Country, so Tax & Duty can be refunded
        $shipment->shipment_address->update( { country => $country->country } );

        note "test using the 'render_email' method";
        my $content = $test->{domain}->render_email( {
            operator_id => 1,
            shipment_id => $shipment->id,
            pickup => 0,
            rma_number => 'U123-456',
            refund_type_id => $renum_type_id,
            return_items => {
                $si1->id => {
                    type => 'Return',
                    reason_id => $CUSTOMER_ISSUE_TYPE__7__IT_DOESN_APOS_T_FIT_ME,
                },
                $si2->id => {
                    type => 'Return',
                    reason_id => $CUSTOMER_ISSUE_TYPE__7__IT_DOESN_APOS_T_FIT_ME,
                },
            },
            charge_tax => 0,
            charge_duty => 0,
            return_expiry_date => $test->{expiry_date},
            email_type => '',
        }, $CORRESPONDENCE_TEMPLATES__RETURN_FSLASH_EXCHANGE )->{email_body};

        $test->_common_email_tests($shipment, $content, $SHIPMENT_TYPE__INTERNATIONAL, $business);
        $test->_single_refund_message_tests( $shipment, $content, $renum_type_id, $business, '', $with_duty );

        note "test using the Return Domain to create an RMA normally";
        my $ret_args    = {
            send_default_email => 1,
            operator_id => $APPLICATION_OPERATOR_ID,
            shipment_id => $shipment->id,
            pickup => 0,
            refund_type_id => $renum_type_id,
            return_expiry_date => $test->{expiry_date},
            return_items => {
                $si1->id => {
                    type        => 'Return',
                    reason_id   => $CUSTOMER_ISSUE_TYPE__7__IT_DOESN_APOS_T_FIT_ME,
                },
                $si2->id => {
                    type        => 'Return',
                    reason_id   => $CUSTOMER_ISSUE_TYPE__7__IT_DOESN_APOS_T_FIT_ME,
                },
            },
        };
        my $return  = $test->{arma_domain}->create( $ret_args );
        $content    = $ret_args->{email_body};

        $test->_common_email_tests($shipment, $content, $SHIPMENT_TYPE__INTERNATIONAL, $business);
        $test->_single_refund_message_tests( $shipment, $content, $renum_type_id, $business, '', $with_duty );
    }
    return;
}

=head2 test_payment_method_used_is_accessible_to_emails

Tests that the Payment method used in the 'orders.payment' record is available to the emails
when the TT parses them so that decisions can be made based on whether a Credit Card or a
Third Party Payment Method (such as PayPal) was used to pay of the Order.

=cut

sub test_payment_method_used_is_accessible_to_emails : Tests {
    my $self = shift;

    $self->{schema}->txn_begin;

    my $channel = Test::XTracker::Data->any_channel;
    my ( $order, $shipment, $si ) = $self->make_order( {
            channel_id => $channel->id,
            tenders => [
                { type => 'card_debit' },
            ],
    } );
    my $psp_refs = Test::XTracker::Data->get_new_psp_refs;

    my $payment_methods        = Test::XTracker::Data->get_cc_and_third_party_payment_methods;
    my $credit_card_method_rec = $payment_methods->{credit_card};
    my $third_party_method_rec = $payment_methods->{third_party};

    # remove all whitespace and uppercase the payment method
    # description as this is how it should appear in the TT
    my $third_party_method_txt = uc( $third_party_method_rec->payment_method );
    $third_party_method_txt    =~ s/\s//g;

    # overwrite the template with our own variables so they can be tested easily
    my $email_template_id   = $CORRESPONDENCE_TEMPLATES__RETURN_FSLASH_EXCHANGE;
    $self->_overwrite_email_template( 'create_return', $channel, {
        content => {
            third_party_paid_with      => 'payment_info.third_party_paid_with',
            was_paid_using_third_party => 'payment_info.was_paid_using_third_party',
            was_paid_using_credit_card => 'payment_info.was_paid_using_credit_card',
        },
    } );

    my %tests = (
        "Paid using a Credit Card" => {
            setup => {
                payment_method => $credit_card_method_rec,
            },
            expect => {
                third_party_paid_with      => '',
                was_paid_using_third_party => '0',
                was_paid_using_credit_card => '1',
            },
        },
        "Paid using a Third Party" => {
            setup => {
                payment_method => $third_party_method_rec,
            },
            expect => {
                third_party_paid_with      => $third_party_method_txt,
                was_paid_using_third_party => '1',
                was_paid_using_credit_card => '0',
            },
        },
        "Paid using Store Credit with NO Payment" => {
            setup => {
                no_payment => 1,
            },
            expect => {
                third_party_paid_with      => '',
                was_paid_using_third_party => '0',
                was_paid_using_credit_card => '0',
            },
        },
    );

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test    = $tests{ $label };
        my $setup   = $test->{setup};
        my $expect  = $test->{expect};

        # setup the Payment for the Order if required for the test
        $order->discard_changes->payments->delete;
        Test::XTracker::Data->create_payment_for_order(
            $order,
            {
                %{ $psp_refs },
                payment_method => $setup->{payment_method},
            },
        ) unless ( $setup->{no_payment} );

        my $ret = $self->{domain}->render_email( {
            operator_id     => 1,
            shipment_id     => $shipment->id,
            pickup          => 0,
            rma_number      => 'U123-456',
            refund_type_id  => $RENUMERATION_TYPE__CARD_REFUND,
            return_items    => {
                $si->id => {
                    type        => 'Return',
                    reason_id   => $CUSTOMER_ISSUE_TYPE__7__IT_DOESN_APOS_T_FIT_ME,
                }
            },
            charge_tax  => 0,
            charge_duty => 0,
            email_type  => $email_template_id,
        }, $email_template_id );

        my $email_content = $ret->{email_body};

        while ( my ( $label, $value ) = each %{ $expect } ) {
            like( $email_content, qr/^${label}:${value}$/m,
                            "Value for '${label}' is as expected: '${value}'" );
        }
    }

    $self->{schema}->txn_rollback;
}

sub test_setup_common_email_stash_method : Tests {
    my $test = shift;
    note "TEST the '_setup_common_email_stash' method returns the values as expected";

    # expected keys in return Arguments and their types
    my %expected_keys   = (
                template_type   => '',
                order           => 'HASH',
                customer        => 'XTracker::Schema::Result::Public::Customer',
                branded_salutation => '',
                shipment        => 'XTracker::Schema::Result::Public::Shipment',
                shipment_items  => 'HASH',
                invoice_address => 'HASH',
                shipment_address=> 'HASH',
                distrib_centre  => '',
                channel         => 'HASH',
                return_expiry_date => '',
                renumerations   => 'ARRAY',
                payment_info    => 'HASH',
                requested_from_arma => '',
                can_set_debit_to_pending => '',
                return_cutoff_days => '',
                channel_branding => 'HASH',
                channel_email_address => 'HASH',
                channel_company_detail => 'HASH',
            );

    my $channel     = Test::XTracker::Data->channel_for_business(name => 'nap');
    my $othr_country= $test->{schema}->resultset('Public::Country')
                                        ->search( { id => { '!=' => $test->{dc_country}->id } } )
                                            ->first;

    # get two addresses for Invoice and Shipping Addresses
    my $inv_addr    = Test::XTracker::Data->order_address( {
                                                            address => 'create',
                                                            first_name => 'INV First',
                                                            last_name => 'INV Last',
                                                            country => $test->{dc_country}->country,
                                                        } );
    my $shp_addr    = Test::XTracker::Data->order_address( {
                                                            address => 'create',
                                                            first_name => 'SHP First',
                                                            last_name => 'SHP Last',
                                                            country => $othr_country->country,
                                                        } );

    my $customer = Test::XTracker::Data->create_dbic_customer({channel_id => $channel->id});

    my ($order, $shipment, $si1, $si2) = $test->make_order({
        shipment_type => $SHIPMENT_TYPE__INTERNATIONAL,
        customer_id => $customer->id,
        invoice_address_id => $inv_addr->id,
        (channel_id => $channel->id),
    });
    # update the Shipping Address to be different from Invoice
    $shipment->update( { shipment_address_id => $shp_addr->id } );
    $order->discard_changes;

    my $args    = $test->{domain}->_setup_common_email_stash( {
                                shipment => $shipment,
                                operator_id => $APPLICATION_OPERATOR_ID,
                                shipment_id => $shipment->id,
                                pickup => 0,
                                rma_number => 'U123-456',
                                refund_type_id => $RENUMERATION_TYPE__STORE_CREDIT,
                                return_items => {
                                    $si1->id => {
                                        type => 'Return',
                                        reason_id => $CUSTOMER_ISSUE_TYPE__7__IT_DOESN_APOS_T_FIT_ME,
                                    },
                                },
                                charge_tax => 0,
                                charge_duty => 0,
                                return_expiry_date => $test->{expiry_date},
                                email_type => '',
                        } );
    note "check what was returned";
    isa_ok( $args, 'HASH', "'_setup_common_email_stash' method return value" );
    is_deeply( [ sort keys %{ $args } ], [ sort keys %expected_keys ], "Return Args has all of the Expected Keys" );
    foreach my $key ( sort keys %expected_keys ) {
        ok( defined $args->{ $key }, "Key: '$key' is defined" );
        if ( $expected_keys{ $key } eq '' ) {
            is( ref( $args->{ $key } ), '', "Key: '$key' is of expected type" );
        }
        else {
            isa_ok( $args->{ $key }, $expected_keys{ $key }, "Key: '$key' is of expected type" );
        }
    }

    is_deeply( $args->{channel_branding}, $channel->branding, "'channel_branding' is as exepected" );
    is_deeply( $args->{channel_email_address}, config_section_slurp( 'Email_' . $channel->business->config_section ),
                                                            "'channel_email_address' is as expected" );
    is_deeply( $args->{channel_company_detail}, config_section_slurp( 'Company_' . $channel->business->config_section ),
                                                            "'channel_company_detail' is as expected" );

    note "check some Address specifics";
    is( $args->{invoice_address}{first_name}, $inv_addr->first_name, "Invoice Address First Name as expected: ".$inv_addr->first_name );
    is( $args->{invoice_address}{last_name}, $inv_addr->last_name, "Invoice Address Last Name as expected: ".$inv_addr->last_name );
    is( $args->{invoice_address}{country}, $inv_addr->country, "Invoice Address Country as expected: ".$inv_addr->country );
    is( $args->{shipment_address}{first_name}, $shp_addr->first_name, "Shipment Address First Name as expected: ".$shp_addr->first_name );
    is( $args->{shipment_address}{last_name}, $shp_addr->last_name, "Shipment Address Last Name as expected: ".$shp_addr->last_name );
    is( $args->{shipment_address}{country}, $shp_addr->country, "Shipment Address Country as expected: ".$shp_addr->country );
}

sub _common_email_exchange_tests {
    my ( $test, $content, $business, $args )    = @_;

    my $test_type   = $args->{test_type};
    my $num_items   = $args->{num_items};
    my $total_charge= $args->{total_charge} || 0;
    my $currency    = $args->{currency};

    note "testing '_common_email_exchange_tests' $test_type";

    # Look for the '- product item description - size XX.X' lines
    my (@items) = $content =~ /^(- .* - size .*)$/mg;
    # 1 items, plus 1 extra line for the exchange item
    cmp_ok(@items, '==', $num_items, 'email lists 2 items') or diag pp( \@items );

    # this has the various parts of the email content that should or shouldn't be present
    my %text_parts  = (
            nap => {
                'receive return ... will dispatch'  =>
                                qr/As soon as we receive and process your return, we'll dispatch the below item to you:/,
                'incur additional charges'  =>
                                qr/Your replacement item will incur additional customs duties imposed by your shipping destination/,
                'total_charge_amount' =>
                                qr/Your replacement item will incur additional.*The total amount will be $total_charge $currency/,
                'confirm debit' =>
                                qr/Please confirm .* (debit|deduct) this amount/,
                'dispatch ... debit' =>
                                qr/As soon as we receive and process your return, we will dispatch your replacement item.*below and debit $total_charge $currency/s,
            },
            out => {
                'receive return ... will dispatch'  =>
                                qr/As soon as we receive and process your return, we'll dispatch the below item to you:/,
                'incur additional charges'  =>
                                qr/Your replacement item will incur additional customs duties imposed by your shipping destination/,
                'confirm debit' =>
                                qr/Please confirm .* (debit|deduct) this amount/,
                'dispatch ... debit' =>
                                qr/As soon as we receive and process your return, we will dispatch your replacement item.*below and debit $total_charge $currency/s,
            },
            mrp => {
                'receive return ... will dispatch'  =>
                                qr/As soon as we receive and process your return, we will dispatch the below item to you:/,
                'incur additional charges'  =>
                                qr/Your replacement item will incur additional customs duties imposed by your shipping destination/,
                'total_charge_amount' =>
                                qr/Your replacement item will incur additional.*The total amount will be $total_charge $currency/,
                'confirm debit' =>
                                qr/Please confirm .* (debit|deduct) this amount/,
                'dispatch ... debit' =>
                                qr/As soon as we receive and process your return, we will dispatch your replacement item.*below and debit $total_charge $currency/s,
            },
        );

    # this says which of the above parts should or shouldn't
    # be present depending on which test you want to run
    my %tests   = (
            without_charges => {
                nap_out_mrp => {
                    'receive return ... will dispatch'  => 'like',
                    'incur additional charges'          => 'unlike',
                    'confirm debit'                     => 'unlike',
                }
            },
            with_charges    => {
                nap_mrp => {
                    'receive return ... will dispatch'  => 'like',
                    'total_charge_amount'               => 'like',
                    'confirm debit'                     => 'like',
                },
                out     => {
                    'receive return ... will dispatch'  => 'like',
                    'incur additional charges'          => 'unlike',
                    'confirm debit'                     => 'unlike',
                },
            },
            auto_confirm_charges    => {
                nap_mrp => {
                    'dispatch ... debit'                => 'like',
                    'receive return ... will dispatch'  => 'unlike',
                    'incur additional charges'          => 'unlike',
                    'confirm debit'                     => 'unlike',
                },
                out     => {
                    'dispatch ... debit'                => 'like',
                    'receive return ... will dispatch'  => 'unlike',
                    'incur additional charges'          => 'unlike',
                    'confirm debit'                     => 'unlike',
                },
            },
        );

    # get the appropriate texts and tests depending
    # on the channel and what tests you want to run
    my $text_part   = $text_parts{ $business };
    my $tests_to_run;
    foreach my $key ( keys %{ $tests{ $test_type } } ) {
        if ( $key =~ m/$business/ ) {
            $tests_to_run   = $tests{ $test_type }{ $key };
        }
    }

    # run the tests
    while ( my ( $text, $action ) = each %{ $tests_to_run } ) {
        like( $content, $text_part->{ $text }, "got '$text' text" )                 if ( $action eq "like" );
        unlike( $content, $text_part->{ $text }, "doesn't have '$text' text" )      if ( $action eq "unlike" );
    }
    return;
}

sub _common_email_tests {
    my ($test, $shipment, $content, $type, $business, $return_awb) = @_;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    note "testing '_common_email_tests'";

    my $customer= $shipment->order->customer;
    my $channel = $shipment->order->channel;

    note "Customer name: ".($customer->title || '')." ".($customer->first_name || '')." ".($customer->last_name || '');
    note "Shipment invoice address name: ".($shipment->invoice_address->first_name || '')." ".($shipment->invoice_address->last_name || '')."; salutation: ".$shipment->order->branded_salutation;
    note "Shipment shipping address name: ".($shipment->shipment_address->first_name || '')." ".($shipment->shipment_address->last_name || '')."; salutation: ".$shipment->branded_salutation;;

    # check RMA number is shown properly
    like( $content, qr{\r?\n\r?\n?Your returns number \(RMA\) is \w+-\w+\.\r?\n}s, "RMA number shown properly" );

    if ($type == $SHIPMENT_TYPE__PREMIER && $business ne 'out') {
        if ( $test->{dc} eq 'DC1' ) {
            like($content, qr/.* Premier/, "Premier sig");
        }
        elsif ( $test->{dc} eq 'DC2' ) {
            like($content, qr/.* Premier/, "Premier sig");
        }
        else {
            fail( "No Premier Signature test for DC: " . $test->{dc} );
        }
    }
    else {
        if ($business eq 'out') {
            like($content, qr/\Qwww.theoutnet.com\E/, "Outnet sig");
            if ( $shipment->shipping_account->carrier->name =~ /DHL/ ) {
                like($content, qr/Book your collection with DHL before your RMA number expires on October 22nd 2009/, "Expiry date found");
            }
            if ( $shipment->shipping_account->carrier->name =~ /UPS/ ) {
                like($content, qr/Book your collection with UPS before your RMA number expires on October 22nd 2009/, "Expiry date found");
            }
        } elsif ($business eq 'nap') {
            unlike($content, qr/.* Premier/, "No Premier sig");
            like($content, qr/October 22nd 2009/, "Expiry date found");
        } elsif ($business eq 'mrp') {
            unlike($content, qr/.* Premier/, "No Premier sig");
            like($content, qr/October 22nd 2009/, "Expiry date found");
        }

        my $salutation = $shipment->order->branded_salutation;
        like($content, qr/Dear $salutation,/, "Branded Salutation '$salutation' found");

        if ($type == $SHIPMENT_TYPE__INTERNATIONAL) {
            if ( $test->{dc} eq 'DC1' ) {
                if ($shipment->shipment_address->is_eu_member_states) {
                    like($content, qr/^\d\. Sign a copy\b/m, 'International instructions');
                } else {
                    like($content, qr/^\d\. Sign four copies\b/m, 'International instructions');
                }
            }
            elsif ( $test->{dc} eq 'DC2' ) {
                if ( $business eq 'mrp' ) {
                    like($content, qr/^\d\. Complete and sign four copies\b/m, 'International instructions');
                }
                else {
                    like($content, qr/^\d\. Sign four copies\b/m, 'International instructions');
                }
            }
            else {
                fail( "No Shipment International Instructions have been Set-up for this DC: ".$test->{dc} );
            }
        }
        elsif ($type == $SHIPMENT_TYPE__DOMESTIC) {
            if ( $test->{dc} eq 'DC1' ) {
                if ($shipment->shipment_address->is_eu_member_states) {
                    like($content, qr/^\d\. Sign a copy\b/m, 'Domestic instructions');
                } else {
                    like($content, qr/^\d\. Sign four copies\b/m, 'Domestic instructions');
                }
            }
            elsif ( $test->{dc} eq 'DC2' ) {
                like($content, qr/^\d\. Complete and sign a copy\b/m, 'Domestic instructions');
            }
            else {
                fail( "No Shipment Domestic Instructions have been Set-up for this DC: ".$test->{dc} );
            }
            note "\r?\nShipment Type  - " . $shipment->shipment_type->type;
            #note "\r?\nAddress - " . join (':',$shipment->shipment_address->get_columns);
        }
    }

    Test::XTracker::Data::Email->rma_common_email_footer_tail_tests( {
                                                    content => $content,
                                                    premier => ( $type == $SHIPMENT_TYPE__PREMIER ? 1 : 0 ),
                                                    business => $business,
                                                    shipment => $shipment,
                                                } );
    return;
}

sub _single_refund_message_tests {
    my ( $test, $shipment, $content, $renumeration_type_id, $business, $email_type, $with_tax_duty_msg )    = @_;

    my $currency            = $test->{currency}->currency;
    my %refund_type_suffix  = (
            $RENUMERATION_TYPE__CARD_REFUND => 'to your card',
            $RENUMERATION_TYPE__STORE_CREDIT => 'as store credit to your '.$test->{channel_brand_name}{ $business }.' account',
        );

    if ( $renumeration_type_id ) {
        my $ref_type_suffix = (
                                $email_type eq 'late_credit_only'       # 'late' RMAs can only be refunded with Store Credit
                                ? $refund_type_suffix{ $RENUMERATION_TYPE__STORE_CREDIT }
                                : $refund_type_suffix{ $renumeration_type_id }
                                );
        like( $content, qr{\r?\n\r?\nAs soon as we receive and process your return, we will credit [\d\.]+ $currency ${ref_type_suffix}\.},
                    "Correct Refund Message found" )    if ( $email_type ne 'faulty' );

        # if Tax & Duties were refunded then a message should be displayed
        if ( $with_tax_duty_msg ) {
            like( $content, qr{${ref_type_suffix}\. This amount will include the taxes and duties paid when the order was placed.},
                    "Got 'Tax & Duty included in amount' message" );
        }
        else {
            unlike( $content, qr{This amount will include the taxes and duties paid when the order was placed.},
                    "Did not find 'Tax & Duty included in amount' message" );
        }
    }
    else {
        unlike( $content, qr{As soon as we receive and process your return we will refund}, "With No Refund Type then no refund message" );
    }
    return;
}

sub _datetimes_close_with_tolerance {
    my ($test, $dt1, $dt2, $tolerance) = @_;
    return ( abs( $dt2->subtract_datetime_absolute($dt1)->seconds ) < $tolerance );
}

sub make_order {
    my ($test, $data) = @_;

    $data ||= {};
    $data->{channel_id} ||= Test::XTracker::Data->channel_for_business(name => 'nap')->id;
    $data->{currency_id}  = $test->{currency}->id;

    # if 'tenders' exist then assume only one and populate the 'value' if there isn't one ther already
    if ( exists( $data->{tenders} ) ) {
        $data->{tenders}[0]{value}  = 360.00        if ( !exists( $data->{tenders}[0]{value} ) );
    }

    $data = Catalyst::Utils::merge_hashes(
    {
        items => {
            $test->{ $data->{channel_id} }{skus}[0] => { price => 100.00 },
            $test->{ $data->{channel_id} }{skus}[1] => { price => 250.00 },
        }
    },
    $data
    );

    my $invoice_address_type = delete $data->{invoice_address_type} || 'random';

    my $order = Test::XTracker::Data->create_db_order( $data );

    my $shipment = $order->shipments->first;
    $shipment->shipment_address->update( { country => $test->{dc_country}->country } );

    if ($invoice_address_type eq 'customer') {
        $shipment->invoice_address->update( { first_name => $order->customer->first_name,
                                                last_name => $order->customer->last_name } );
    }

    note 'Order Id/Nr: ' . $order->id . '/' . $order->order_nr . ', Shipment Id: ' . $shipment->id;

    my @sis = map {
        $shipment->shipment_items->find_by_sku($_)
    } @{$test->{ $data->{channel_id} }{skus}};
    return ($order, $shipment, @sis);
}

# helper to overwrite Email Templates with our own content so we
# can find specific data passed into the stash that the TT uses
sub _overwrite_email_template {
    my ( $self, $tt_name, $channel, $args ) = @_;

    # make up the Template Name to use in the 'correspondence_templates' table,
    # this method of getting the name is used in the 'render_email' method
    my $config_section = $channel->business->config_section;
    my $template_name  = 'RMA - ' .
                         join( ' ', map {
                            ucfirst( lc( $_ ) )
                         } split (/_/, $tt_name ) ) .
                         ' - ' . $config_section;

    Test::XTracker::Data::Email->overwrite_correspondence_template_content( {
        template_name   => $template_name,
        placeholders    => $args->{content},
    } );

    return;
}


Test::Class->runtests;
