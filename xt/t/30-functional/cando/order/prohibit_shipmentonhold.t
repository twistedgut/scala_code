#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use Test::XTracker::Data;
use Test::XT::Flow;

use XTracker::Constants qw ( :application );
use XTracker::Constants::FromDB qw(
    :shipment_class
    :shipment_status
    :shipment_type
    :shipment_item_status
    :shipment_hold_reason
    :authorisation_level
);

=head2 CANDO -838

 This test validates the logic of putting shipment on hold link on order view page.

=over

=item * Test 1:
        Check shipment CAN be put on hold if packing_has_started flag
        is false.

=item * Test 2:
        Check shipment CANNOT be put on hold once packing has started.

=item * Test 3:
        Check if the shipment hold page was opened prior to packing cannot sumbmitted once
        shipment is packed.

=item * Test 4:
        Check Shipment which is already on hold and packing_has_started flag is true
        can be released

=item * Test 5:
        Check for multiple shipment, Hold Shipment page display correctly.
        i.e,  shipment which has_packing_started flag = TRUE. display note.

=item * Test 6:
       Check for multiple shipment, Shipment which is already on hold can be released.
       so that "hold shipment" link leads to a page with select shipment page and
       shipment can still be released.

=back

=cut


my $schema = Test::XTracker::Data->get_schema;
isa_ok( $schema, "XTracker::Schema" );

my $mech = Test::XTracker::Mechanize->new;

my $framework = Test::XT::Flow->new_with_traits(
    traits => ['Test::XT::Flow::CustomerCare',
                'Test::XT::Flow::Fulfilment',
                'Test::XT::Data::Customer',
                'Test::XT::Data::Channel',
              ],
    mech   => $mech,
);

#---- Test Functions ---------------------------------------

_test_shipment_on_hold ($schema ,1);
#-----------------------------------------------------------
done_testing();
#---------------- ------------------------------------------


sub _test_shipment_on_hold {
    my $schema = shift;
    my $oktodo = shift;

    SKIP: {
        skip "_test_shipment_on_hold", 1 if (!$oktodo);

        note "Testing Shipment on hold logic ";
        # Test 1 :
        $framework->channel( Test::XTracker::Data->channel_for_nap );
        my $orddetails  = $framework->flow_db__fulfilment__create_order(
                                                channel => $framework->channel,
                                                products => 1,
                                            );

        # Create order with shipment with status = Processing
        my $order           = $orddetails->{order_object};
        #my $order           = create_an_order();
        my $shipment        = $order->shipments->first;
        my $customer        = $order->customer;

        $shipment->update({ shipment_status_id      => $SHIPMENT_STATUS__PROCESSING });

        #update has_packing_started flag to false
        $shipment->update({ has_packing_started => 'FALSE' });

        #go to order view page and click on shipment hold button

        note "************ Order id : ". $order->id ." and shipment id: ". $shipment->id."\n";

        Test::XTracker::Data->set_department( 'it.god', 'Customer Care' );
        $framework->login_with_permissions( {
            perms => {
                $AUTHORISATION_LEVEL__OPERATOR => [
                    'Customer Care/Customer Search',
                    'Customer Care/Order Search',
                ]
            }
        } );


        $framework->flow_mech__customercare__orderview($order->id)
                ->flow_mech__customercare__hold_shipment()
                ->flow_mech__customercare__hold_shipment_submit();

        # Test 1: Check shipment can be put on hold
        is( $framework->mech->as_data->{'meta_data'}->{'Shipment Details'}->{'Status'},
            'Hold', 'Shipment was placed on hold' );


        # Update shipment to be complete packing.
        $shipment->discard_changes();
        $shipment->update({ shipment_status_id  => $SHIPMENT_STATUS__PROCESSING });
        $shipment->update({ has_packing_started => 'TRUE' });

        $framework->flow_mech__customercare__orderview($order->id)
                ->flow_mech__customercare__hold_shipment();


        #Test 2: Check shipment cannot be put on hold as it has packing started flag set

        cmp_ok($framework->mech->as_data->{error_page}, 'eq',
            ' Sorry, it is too late to hold the shipment as packing has already started.' ,
            'Prohibit putting shipment on hold'
        );


        # TEST 3:
        # reset to old status
        $shipment->discard_changes();
        $shipment->update({ shipment_status_id  => $SHIPMENT_STATUS__PROCESSING });
        $shipment->update({ has_packing_started => 'FALSE' });

        $framework->flow_mech__customercare__orderview($order->id)
                ->flow_mech__customercare__hold_shipment();

        $shipment->discard_changes->update({ has_packing_started => 'TRUE' });

        $framework->errors_are_fatal(0);
        $framework->flow_mech__customercare__hold_shipment_submit();
        $framework->errors_are_fatal(1);
        like( $framework->mech->app_error_message,
            qr/Sorry, it is too late to hold the shipment as packing has already started./i,
            "Shipment Cannot be held has it has already been packed"
        );

        #Test 4: shipment on hold and started packing status
        $shipment->discard_changes();
        $shipment->update({ shipment_status_id  => $SHIPMENT_STATUS__HOLD });
        $shipment->update({ has_packing_started => 'TRUE' });


        note "Testing when shipment is already on hold and packing_has_started flag is true can be released";
        $framework->flow_mech__customercare__orderview($order->id)
                ->flow_mech__customercare__hold_shipment()
                ->flow_mech__customercare__hold_release_shipment();

        cmp_ok( $shipment->discard_changes->shipment_status_id, '==', $SHIPMENT_STATUS__PROCESSING, "Shipment Released from hold");

        #shipment and shipment item to be dispatched

        $shipment->update({ shipment_status_id => $SHIPMENT_STATUS__DISPATCHED });
        $shipment->shipment_items->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__DISPATCHED } );


        my $return;
        # create Exchange and test it created ok
        $mech->order_nr( $order->order_nr );
        $mech->test_create_rma( $shipment, 'exchange' )
             ->test_exchange_pending( $return = $shipment->returns->first );

        $return->discard_changes;
        $shipment->discard_changes;

        # Test 5:
        #update exchange to be have status processing
        $shipment->update({ shipment_status_id => $SHIPMENT_STATUS__PROCESSING });
        $shipment->update({ has_packing_started => 'TRUE' });


        $framework->flow_mech__customercare__orderview($order->id)
                 ->flow_mech__customercare__hold_shipment();

        my $page_data = $framework->mech->as_data->{'multi_shipment_table'};
        my $shipment_content;
        if($page_data->[0]->{'Type'} eq 'Exchange') {
            $shipment_content = $page_data->[1]->{'Shipment Number'};
        } else {
            $shipment_content = $page_data->[0]->{'Shipment Number'};
        }

        my $shipmentid = $shipment->id;
        like( $shipment_content, qr/$shipmentid Packing has already started/i, 'Shipment number is displayed with note' );


        # TEST 6:
        note "Testing when there are multiple shipments and one of them is already on hold and packing_has_started flag is true can be released";
        $shipment->discard_changes->update({ shipment_status_id  => $SHIPMENT_STATUS__HOLD });
        $shipment->create_related('shipment_holds',{
                    shipment_hold_reason_id => $SHIPMENT_HOLD_REASON__CUSTOMER_REQUEST,
                    operator_id => $APPLICATION_OPERATOR_ID,
                    hold_date   => \'now()',
                    comment => 'comment',
                });
        $framework->flow_mech__customercare__orderview($order->id)
                     ->flow_mech__customercare__hold_shipment()
                      ->flow_mech__customercare__hold_click_on_shipment_id($shipment->id)
                       ->flow_mech__customercare__hold_release_shipment();

        cmp_ok( $shipment->discard_changes->shipment_status_id, '==', $SHIPMENT_STATUS__PROCESSING, "Shipment Released from hold - Multiple shipment");

    }

}

#-------------------------------------------------------------------

