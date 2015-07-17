#!/usr/bin/env perl

use NAP::policy     qw( test );

=head1 NAME

old_fraud_rules_new_card.t - Tests New Card Flag Applied for Old Fraud Rules

=head1 DESCRIPTION

Checks that when using the Old Fraud Rules that the New Card Flag is Applied to
Orders with no Card History but is NOT Applied to Store Credit only Orders.


TODO: Remove this Test when the Old Fraud Rules are Removed.

=cut


use Test::XTracker::Data;
use Test::XTracker::Data::Order;
use XTracker::Config::Local         qw( config_var );
use XTracker::Constants             qw( :application );
use XTracker::Constants::FromDB     qw( :currency :flag );
use Test::XT::Data;

use Test::XTracker::Mock::PSP;


my $schema  = Test::XTracker::Data->get_schema;
isa_ok( $schema, "XTracker::Schema" );
my $dbh     = $schema->storage->dbh;
my @channels= $schema->resultset('Public::Channel')->fulfilment_only( 0 )->enabled;

$schema->txn_begin;

my %tests = (
    "Order Paid With Card Never Used Before" => {
        setup => {
            add_to_order_key => {
                tender_type   => 'Card',
                pre_auth_code => '2342342',
            },
            payment_history => [],
        },
        expect => {
            flag => 1,
        },
    },
    "Order Paid With Card Previously Used Once Before" => {
        setup => {
            add_to_order_key => {
                tender_type   => 'Card',
                pre_auth_code => '2342342',
            },
            payment_history => [ { orderNumber => 99999999 } ],
        },
        expect => {
            flag => 0,
        },
    },
    "Order Paid With Card Previously Used Twice Before" => {
        setup => {
            add_to_order_key => {
                tender_type   => 'Card',
                pre_auth_code => '2342342',
            },
            payment_history => [ { orderNumber => 99999999 }, { orderNumber => 88888888 } ],
        },
        expect => {
            flag => 0,
        },
    },
    "Order Paid With Card Used Many Times Before" => {
        setup => {
            add_to_order_key => {
                tender_type   => 'Card',
                pre_auth_code => '2342342',
            },
            payment_history => [
                { orderNumber => 99999999 },
                { orderNumber => 88888888 },
                { orderNumber => 77777777 },
            ],
        },
        expect => {
            flag => 0,
        },
    },
    "Order Paid With Store Credit Only" => {
        setup => {
            add_to_order_key => {
                tender_type   => 'Store Credit',
            },
            # explictly want an Empty Payment
            # History for Store Credit only Orders
            want_empty_payment_history => 1,
        },
        expect => {
            flag => 0,
        },
    },
    "Order Paid with Store Credit/Card Never Used Before" => {
        setup => {
            add_to_order_key => {
                tenders => [
                    { type => 'Card', pre_auth_code => '2342342', rank => 1, value => 100 },
                    { type => 'Store Credit', rank => 2, value => 21.50 },
                ],
            },
            payment_history => [],
        },
        expect => {
            flag => 1,
        },
    },
    "Order Paid with Store Credit/Card Previously Used Once Before" => {
        setup => {
            add_to_order_key => {
                tenders => [
                    { type => 'Card', pre_auth_code => '2342342', rank => 1, value => 100 },
                    { type => 'Store Credit', rank => 2, value => 21.50 },
                ],
            },
            payment_history => [ { orderNumber => 99999999 } ],
        },
        expect => {
            flag => 0,
        },
    },
    "Order Paid with Store Credit/Card Previously Used Many Times Before" => {
        setup => {
            add_to_order_key => {
                tenders => [
                    { type => 'Card', pre_auth_code => '2342342', rank => 1, value => 100 },
                    { type => 'Store Credit', rank => 2, value => 21.50 },
                ],
            },
            payment_history => [
                { orderNumber => 99999999 },
                { orderNumber => 88888888 },
                { orderNumber => 77777777 },
            ],
        },
        expect => {
            flag => 0,
        },
    },
);

# run through the tests once where the Current Order Number is NOT in the
# Payment History which is the case when using the PSP 'payment-information'
# Service and then run through them a second time WITH the Current Order Number
# in the Payment History which is the case when using the legacy PSP 'payment-info'
# Service.

foreach my $service ( qw( payment-information payment-info ) ) {
    note "RUNNING TESTS as if the '${service}' PSP Service was being Used";
    my $add_current_order_number_to_payment_history = $service eq 'payment-info';

    foreach my $label ( keys %tests ) {
        Test::XTracker::Data::Order->purge_order_directories();

        note "Testing: ${label}";
        my $test = $tests{ $label };

        my $setup  = $test->{setup};
        my $expect = $test->{expect};

        my $data = Test::XT::Data->new_with_traits(
            traits => [
                'Test::XT::Data::Channel',
                'Test::XT::Data::Customer',
            ],
        );

        my $channel = $channels[0];
        $data->channel( $channel );     # explicitly set the Sales Channel otherwise it will default to NaP
        my $customer = $data->customer;

        my ( $forget,$pids ) = Test::XTracker::Data->grab_products( {
            how_many => 1,
            channel  => $channel,
        } );
        my $product = $pids->[0];

        # Set-up options for the the Order XML file that will be created
        my $order_args = {
            customer => { id => $customer->is_customer_number },
            order => {
                channel_prefix => $channel->business->config_section,
                tender_amount => 110.00,
                shipping_price => 10,
                shipping_tax => 1.50,
                items => [
                    {
                        sku => $product->{sku},
                        description => $product->{product}
                                                ->product_attribute
                                                    ->name,
                        unit_price => 100,
                        tax => 10,
                        duty => 0,
                    },
                ],
                %{ $setup->{add_to_order_key} },
            },
        };

        my $data_order;

        # Create and Parse all Order Files
        subtest "Imported Order" => sub {
            ( $data_order ) = Test::XTracker::Data::Order->create_order_xml_and_parse( $order_args );
        };

        my @payment_history;
        unless ( $setup->{want_empty_payment_history} ) {
            @payment_history = @{ $setup->{payment_history} };
            if ( $add_current_order_number_to_payment_history ) {
                unshift @payment_history, { orderNumber => $data_order->order_number };
            }
        }
        Test::XTracker::Mock::PSP->set_card_history( \@payment_history );

        $data_order->_preprocess;
        my $order = $data_order->_save;
        $data_order->_apply_credit_rating( $order, $APPLICATION_OPERATOR_ID );

        $order->discard_changes;
        cmp_ok(
            $order->order_flags->search( { flag_id => $FLAG__NEW_CARD } )->count,
            '==',
            $expect->{flag},
            "Got Expected Number of New Card Flags assigned to the Order"
        );
    }
}

# just remove any remaining Order XML Files
Test::XTracker::Data::Order->purge_order_directories();

$schema->txn_rollback;

done_testing;
