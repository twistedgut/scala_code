#!/usr/bin/env perl

use NAP::policy     qw( test );

=head1 NAME

order_still_imports_when_errors_thrown.t

=head1 DESCRIPTION

This tests the Insertion of Orders into orders table even when there are failures
along the way whilst importing.

Current failures tested for:
    * Applying SLAs Fail

=cut

use Test::XTracker::Data;

BEGIN {
    # TODO: make sure this is localised when
    #       converting into a Test::Class test
    no warnings 'redefine';
    use XTracker::Schema::Result::Public::Shipment  qw();
    *XTracker::Schema::Result::Public::Shipment::apply_SLAs = sub {
        note "============================== IN RE-DEFINED method 'apply_SLAs' ==============================";
        die "TEST TOLD ME TO DIE";
    };
};

use Test::XTracker::Data::Order;
use Test::XTracker::Data::FraudRule;

use XTracker::Config::Local         qw( config_var );
use XTracker::Constants::FromDB     qw( :order_status
                                        :note_type
                                        :shipment_hold_reason
                                        :shipment_status
                                    );
use XTracker::Constants             qw( :application );

use Test::XT::Data;


my $schema  = Test::XTracker::Data->get_schema;
isa_ok( $schema, "XTracker::Schema" );

# get all Enabled Channels
my @channels = $schema->resultset('Public::Channel')->fulfilment_only( 0 )->enabled;

# clean-up other tests mess
Test::XTracker::Data::Order->purge_order_directories();

# loop round twice, once when Orders should be put on Credit
# Hold and then again when all Orders should be Accepted

# by deleting all Fraud Rules this will mean the
# default Order Status 'Credit Hold' will be used
Test::XTracker::Data::FraudRule->delete_fraud_rules;

foreach my $order_status_id ( $ORDER_STATUS__CREDIT_HOLD, $ORDER_STATUS__ACCEPTED ) {

    note "TESTING when Orders " . (
            $order_status_id == $ORDER_STATUS__CREDIT_HOLD
            ? "will be put on Credit Hold"
            : "will be Accepted"
        );

    foreach my $channel ( @channels ) {

        note "TEST for Sales Channel: ".$channel->name;

        my $data = Test::XT::Data->new_with_traits(
            traits => [
                'Test::XT::Data::Channel',
                'Test::XT::Data::Customer',
            ],
        );

        # explicitly set the Sales Channel otherwise it will default to NAP
        $data->channel( $channel );
        my $customer = $data->customer;

        my ( $forget, $pids ) = Test::XTracker::Data->grab_products( {
            how_many => 1,
            channel  => $channel,
        } );

        my $product = $pids->[0];

        # Set-up options for the the Order XML file that will be created
        my $order_args  = [];
        push @{ $order_args }, {
            customer => { id => $customer->is_customer_number },
            order => {
                channel_prefix => $channel->business->config_section,
                tender_amount => 291.50,
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
            },
        };

        # Create and Parse all Order Files
        my @data_orders = Test::XTracker::Data::Order->create_order_xml_and_parse($order_args);

        foreach my $data_order ( @data_orders ) {

            # process the order
            my $order   = $data_order->digest();
            $order->allocate( $APPLICATION_OPERATOR_ID );

            isa_ok( $order, "XTracker::Schema::Result::Public::Orders", "Order Digested" );
            cmp_ok( $order->channel_id, '==', $channel->id, "sanity check: Order is for correct Sales Channel: ".$channel->id." - ".$channel->name );

            # check the Order Status
            cmp_ok( $order->order_status_id, '==', $order_status_id, "Order Status as Expected" );

            # check the Shipment Status to see if it's on Hold
            # depending on what was expected for the Order Status
            my $shipment = $order->get_standard_class_shipment;
            if ( $order_status_id == $ORDER_STATUS__ACCEPTED ) {
                my $on_hold_for_sla = $shipment->search_related( 'shipment_holds', {
                    shipment_hold_reason_id => $SHIPMENT_HOLD_REASON__OTHER,
                    comment                 => { ILIKE => '%Error NO SLA%' },
                } )->count;
                cmp_ok( $on_hold_for_sla, '==', 1, "Found Shipment Hold for SLA Error" );
                cmp_ok( $shipment->shipment_status_id, '==', $SHIPMENT_STATUS__HOLD,
                                    "and Shipment record is on 'Hold'" );
            }
            else {
                # Order is going on Credit Hold, so check Shipment Status is correct
                cmp_ok( $shipment->shipment_status_id, '==', $SHIPMENT_STATUS__FINANCE_HOLD,
                                    "and Shipment record is on 'Finance Hold'" );
            }

            my @ship_items  = $shipment->shipment_items->search( {}, { order_by => 'variant_id,voucher_variant_id' } )->all;
            cmp_ok( @ship_items, '==', 1, "One Shipment Item is Created" );

            note "Check to see if pre_auth_value column is populated with value";
            # check total_value == pre_auth_value
            cmp_ok( $order->total_value, '==', $order->pre_auth_total_value, "pre_auth_total_value is set" );

            note "Check if get_total_value returns correct total";
            # check total order value calculates is correct
            cmp_ok( $order->total_value,'==',$order->get_total_value(), "get_total_value calculates correct total" );

            note "Check an Order Note was created";
            my $note_found = $order->order_notes->search( {
                note_type_id => $NOTE_TYPE__SHIPPING,
                note         => { ILIKE => '%problem%SLA%' },
            } )->count;
            cmp_ok( $note_found, '==', 1, "Found Order Note about SLAs failure" );
        }
    }

    # set all Fraud Rules to be Accepted for the next iteration
    Test::XTracker::Data::FraudRule->create_live_rule_to_always_accept
                    if ( $order_status_id == $ORDER_STATUS__CREDIT_HOLD );
}

# just remove any remaining Order XML Files
Test::XTracker::Data::Order->purge_order_directories();

# Clear all Fraud Rules for other Tests
Test::XTracker::Data::FraudRule->delete_fraud_rules;

done_testing;
