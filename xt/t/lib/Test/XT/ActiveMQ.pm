package Test::XT::ActiveMQ;
# Just a place to put some functions that a few tests use, instead of copying
# them in each one. It's not a great place, and this isn't a great permanent
# solution, but it's a step forward.

# The tests that use this at the time of creation are the arma-related ones in
# t/20-units/activemq/receive/

use NAP::policy "tt";

sub rma_req_message {
    my ($order, $return_items) = @_;

    my $fulfill_only = $order->channel->business->fulfilment_only;

    my $rs = $order->get_standard_class_shipment->shipment_items;
    # Populate the xtLineItemId in the returnItems
    for my $ri (@$return_items) {
        # Fulfilment Only Channels (JC) will have an 'externalLineItemId' field
        # which should have already been populated before the call to this method
        $ri->{xtLineItemId} ||= $rs->find_by_sku($ri->{sku})->id        if ( !$fulfill_only );
    }

    return {
        "orderNumber" => $order->order_nr,
        "returnRequestDate" => "2009-09-01 12:52:19 +0100",
        "refundType" => "CARD",
        "returnItems" => $return_items,
    },{
        type => "com.netaporter.messaging.support.returns.ReturnRequestMessage",
    };
}

sub rma_cancel_message {
    my ($return, $return_items) = @_;

    my $shipment = $return->shipment;
    my $order = $shipment->order;
    my $rs = $shipment->shipment_items;
    # Populate the xtLineItemId in the returnItems
    for my $ri (@$return_items) {
        $ri->{xtLineItemId} ||= $rs->find_by_sku($ri->{sku})->id;
    }

    return {
        "orderNumber" => $order->order_nr,
        "returnCancelRequestDate" => "2009-09-01 12:52:19 +0100",
        "returnItems" => $return_items,
        "rmaNumber" => $return->rma_number,
    },{
        type => "com.netaporter.messaging.support.returns.CancelReturnItemsRequestMessage",
    };
}

sub rma_add_message {
    my ($return, $return_items, $pws_request_date) = @_;

    my $shipment = $return->shipment;
    my $order = $shipment->order;
    my $rs = $shipment->shipment_items;
    # Populate the xtLineItemId in the returnItems
    for my $ri (@$return_items) {
        $ri->{xtLineItemId} ||= $rs->find_by_sku($ri->{sku})->id;
    }

    return {
        "orderNumber" => $order->order_nr,
        "returnRequestDate" => $pws_request_date,
        "refundType" => "CREDIT",
        "returnItems" => $return_items,
        "rmaNumber" => $return->rma_number,
    },{
        type => 'com.netaporter.messaging.support.returns.ReturnRequestMessage',
    };
}

1;
