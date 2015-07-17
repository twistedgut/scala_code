#!/usr/bin/env perl

use NAP::policy "tt",     'test';

=head2 Verify that telephone numbers on PreOrder make it into the Order

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::Order;
use Test::XTracker::Data::PreOrder;
use Test::XT::Data;

use XTracker::Constants::FromDB     qw(
                                        :pre_order_status
                                        :pre_order_item_status
                                    );


my $schema  = Test::XTracker::Data->get_schema;
isa_ok( $schema, "XTracker::Schema" );

$schema->txn_do( sub {

    my $data = Test::XT::Data->new_with_traits(
        traits => [
            'Test::XT::Data::Channel',      # should default to NaP
            'Test::XT::Data::Customer',
        ],
    );

    my $channel = $data->channel;
    my $customer= $data->customer;

    my ( $forget, $pids ) = Test::XTracker::Data->grab_products( {
        how_many            => 1,
        dont_ensure_stock   => 1,
        channel             => $channel,
    } );
    my $sku = $pids->[0]{sku};

    my $tel_day = '0203 123 9922';
    my $tel_eve = '01999 123533';

    my $pre_order;
    $pre_order  = Test::XTracker::Data::PreOrder->create_complete_pre_order( {
        customer                => $customer,
        variants                => [ $pids->[0]{variant} ],
        pre_order_status        => $PRE_ORDER_STATUS__EXPORTED,
        pre_order_item_status   => $PRE_ORDER_ITEM_STATUS__EXPORTED,
    } );

    $pre_order->update( {
        telephone_day => $tel_day,
        telephone_eve => $tel_eve,
    } );

    # Create and Parse an Order File
    my ( $data_order ) = Test::XTracker::Data::Order->create_order_xml_and_parse( [ {
        customer    => { id => $customer->is_customer_number },
        order       => {
            channel_prefix  => $channel->business->config_section,
            preorder_number => $pre_order->pre_order_number,
            items   => [ {
                sku         => $pids->[0]->{sku},
                description => $pids->[0]->{product}->product_attribute->name,
                unit_price  => 691.30,
                tax         => 48.39,
                duty        => 0.00
            } ],
        },
    } ] );

    $data_order->billing_telephone_numbers( [] );

    my $order;

    try {
        $order       = $data_order->digest( { skip => 1 } );
    } catch {
        die "Digest failed: $_";
    };

    my $shipment = $order->get_standard_class_shipment;

    cmp_ok( $shipment->telephone, 'eq', $tel_day, 'Telephone is correct' );
    cmp_ok( $shipment->mobile_telephone, 'eq', $tel_eve, 'Mobile is correct' );

    $schema->txn_commit;

} );

done_testing();
