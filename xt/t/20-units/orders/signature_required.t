#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

=head2 CANDO-216: Signature Required Opt Out

This tests the passing of the 'SIGNATURE_REQUIRED' flag into and Order XML file and checks that the Order Importer uses the flag correctly and that the resulting Shipment for the Order created has it's flag set correctly.

Also tests whether the Order Importer puts Order's on Hold if the Signature Required flag is FALSE in certain conditions.

=cut

use Test::XTracker::RunCondition
  dc       => [ qw( DC1 DC2 ) ],
  export   => [ qw( $distribution_centre ) ];


use Test::XTracker::Hacks::TxnGuardRollback;
use Test::XTracker::Data;
use Test::XTracker::Data::Order;

use XTracker::Config::Local;
use XTracker::Constants             qw( :application );
use XTracker::Constants::FromDB     qw(
                                        :customer_category
                                        :currency
                                        :flag
                                        :order_status
                                        :shipment_status
                                    );

use Data::Dump  qw( pp );

use Test::XT::Data;

my $schema  = Test::XTracker::Data->get_schema;
isa_ok( $schema, "XTracker::Schema" );
my $dbh     = $schema->storage->dbh;

$schema->txn_do( sub {

    my $data = Test::XT::Data->new_with_traits(
        traits => [
            'Test::XT::Data::Channel',      # should default to NaP
            'Test::XT::Data::Customer',
        ],
    );

    my $channel = $data->channel;
    my $customer= $data->customer;

    my ($forget,$pids)  = Test::XTracker::Data->grab_products({
        how_many => 1,
        dont_ensure_stock => 1,
        channel => $channel,
    });
    my $sku = $pids->[0]{sku};

    # set-up the conditions for the tests, by setting up how
    # the Order XML file will be created
    my $order_args  = [
            {
                customer    => { id => $customer->is_customer_number },
                freehand    => {
                    signature_required  => 'SIGNATURE_REQUIRED="true"',
                },
            },
            {
                customer    => { id => $customer->is_customer_number },
                freehand    => {
                    signature_required  => 'SIGNATURE_REQUIRED="false"',
                },
            },
            {
                customer    => { id => $customer->is_customer_number },
                freehand    => {},
            },
        ];
    # Create and Parse all Order Files
    my $data_orders = Test::XTracker::Data::Order->create_order_xml_and_parse(
        $order_args,
    );

    note "test with Signature Required set to TRUE in the XML File";
    cmp_ok( $data_orders->[0]->signature_required, '==', 1, "Signature Required Flag is TRUE in 'XT::Data::Orders' object" );
    my $order       = $data_orders->[0]->digest( { skip => 1 } );
    my $shipment    = $order->get_standard_class_shipment;
    cmp_ok( $shipment->signature_required, '==', 1, "Signature Required Flag is TRUE on 'shipment' record" );

    note "test with Signature Required set to FALSE in the XML File";
    cmp_ok( $data_orders->[1]->signature_required, '==', 0, "Signature Required Flag is FALSE in 'XT::Data::Orders' object" );
    $order          = $data_orders->[1]->digest( { skip => 1 } );
    $shipment       = $order->get_standard_class_shipment;
    cmp_ok( $shipment->signature_required, '==', 0, "Signature Required Flag is FALSE on 'shipment' record" );

    note "test with Signature Required NOT present at all in the XML File";
    cmp_ok( $data_orders->[2]->signature_required, '==', 1, "Signature Required Flag is TRUE in 'XT::Data::Orders' object" );
    $order          = $data_orders->[2]->digest( { skip => 1 } );
    $shipment       = $order->get_standard_class_shipment;
    cmp_ok( $shipment->signature_required, '==', 1, "Signature Required Flag is TRUE on 'shipment' record" );


    note "test the Order goes on Hold in certain conditions when the Signature Required flag is FALSE";

    # re-define some methods used in '_apply_credit_rating'
    # so that nothing else would put the order on hold
    no warnings "redefine";
    ## no critic(ProtectPrivateVars)
    *XT::Data::Order::_is_shipping_address_dodgy    = \&__is_shipping_address_dodgy;
    *XT::Data::Order::_do_hotlist_checks            = \&__do_hotlist_checks;
    *XT::Data::Order::_do_customer_order_card_checks= \&__do_customer_order_card_checks;
    use warnings "redefine";

    # change the config to make sure the DC can have Signature Opt Out
    my $config  = \%XTracker::Config::Local::config;
    $config->{DistributionCentre}{has_delivery_signature_optout}    = 'yes';

    my $currency_id = ( $distribution_centre eq "DC2" ? $CURRENCY__USD : $CURRENCY__GBP );
    my $currency    = $schema->resultset('Public::Currency')->find( $currency_id );
    my $threshold   = Test::XTracker::Data->set_delivery_signature_threshold( $channel, $currency, 2000 );

    # set-up some tests
    my %tests   = (
            'Over Threshold'        => {
                        customer_category   => $CUSTOMER_CATEGORY__NONE,
                        amount              => $threshold + 100,
                        sigflag             => 'false',
                        put_on_hold         => 1,
                    },
            'Over Threshold - EIP'  => {
                        customer_category   => $CUSTOMER_CATEGORY__EIP,
                        amount              => $threshold + 100,
                        sigflag             => 'false',
                        put_on_hold         => 0,
                    },
            'Under Threshold'       => {
                        customer_category   => $CUSTOMER_CATEGORY__NONE,
                        amount              => $threshold - 500,
                        sigflag             => 'false',
                        put_on_hold         => 0,
                    },
            'Over Threshold - Signature Opt In' => {
                        customer_category   => $CUSTOMER_CATEGORY__NONE,
                        amount              => $threshold + 100,
                        sigflag             => 'true',
                        put_on_hold         => 0,
                    },
        );

    foreach my $test_label ( sort keys %tests ) {
        note "test: $test_label";
        my $test    = $tests{ $test_label };

        $customer->update( { category_id => $test->{customer_category} } );
        my $amount  = $test->{amount};
        my $sigflag = $test->{sigflag};

        my $args    = {
                customer    => { id => $customer->is_customer_number },
                order       => {
                    # amount plus standard shipping costs which are in the XML Template
                    tender_amount => $amount + 10.00 + 1.50,
                    items   => [
                        {
                            sku         => $sku,
                            unit_price  => $amount - 300,
                            tax         => 100,
                            duty        => 200,
                        },
                    ],
                },
                freehand    => {
                    signature_required  => "SIGNATURE_REQUIRED='$sigflag'",
                },
            };

        # parse an order
        my $parsed = Test::XTracker::Data::Order->create_order_xml_and_parse(
            $args,
        );
        my $data_order  = $parsed->[0];

        # part digest the parsed order
        $data_order->_preprocess;
        my $order   = $data_order->_save;

        # now call the method that would apply the On Hold logic
        $data_order->_apply_credit_rating( $order, $APPLICATION_OPERATOR_ID );

        $order->discard_changes;
        $shipment   = $order->get_standard_class_shipment;

        # check what happened matched what the test should have done
        if ( $test->{put_on_hold} ) {
            cmp_ok( $order->order_status_id, '==', $ORDER_STATUS__CREDIT_HOLD, "Order Status is on 'Credit Hold'" );
            cmp_ok( $shipment->shipment_status_id, '==', $SHIPMENT_STATUS__FINANCE_HOLD, "Shipment Status is on 'Finance Hold'" );
            cmp_ok( $order->order_flags->count( { flag_id => $FLAG__DELIVERY_SIGNATURE_OPT_OUT } ), '==', 1,
                                        "'Delivery Signature Opt Out' Flag created for the Order" );
        }
        else {
            cmp_ok( $order->order_status_id, '==', $ORDER_STATUS__ACCEPTED, "Order Status is 'Accepted'" );
            cmp_ok( $shipment->shipment_status_id, '==', $SHIPMENT_STATUS__PROCESSING, "Shipment Status is 'Processing'" );
            cmp_ok( $order->order_flags->count( { flag_id => $FLAG__DELIVERY_SIGNATURE_OPT_OUT } ), '==', 0,
                                        "No 'Delivery Signature Opt Out' Flag created for the Order" );
        }
    }

    # rollback changes
    $schema->txn_rollback;
} );

# just remove any remaining Order XML Files
Test::XTracker::Data::Order->purge_order_directories();

done_testing;

#-----------------------------------------------------------------------------

# method that will redefine one in 'XT::Data::Orders' to help with the tests
sub __is_shipping_address_dodgy {
    return 0;
}

# method that will redefine one in 'XT::Data::Orders' to help with the tests
sub __do_hotlist_checks {
    return 100;
}

# method that will redefine one in 'XT::Data::Orders' to help with the tests
sub __do_customer_order_card_checks {
    my ( $self, $order )    = @_;

    # need to re-create this result set so other new code wont fall over
    my $cust_rs = $schema->resultset('Public::Customer')->search( {
            'me.id' => $order->customer_id,
        } );
    $self->_customer_rs( $cust_rs );

    return 100;
}

# method that will redefine one in 'XT::OrderImporter' to not put an Order on Credit Hold
sub __credit_check_order {
    $_[2]->{credit_rating}  = 2;        # to not put on Credit Hold
    return;
}
