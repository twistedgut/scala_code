#!/usr/bin/env perl

use NAP::policy "tt", 'test';

use Test::XTracker::Data;
use Test::XTracker::Data::PreOrder;
use Test::XTracker::MessageQueue;
use Test::Exception;
use XTracker::Config::Local qw/config_var/;

use Data::Dump qw/pp/;

use XTracker::Constants::FromDB qw( :pre_order_status
                                    :pre_order_note_type
                                    :pre_order_item_status );

my $amq = Test::XTracker::MessageQueue->new();
my $schema  = Test::XTracker::Data->get_schema;
my $factory = $amq->producer;

isa_ok( $amq, 'Test::XTracker::MessageQueue' );
isa_ok( $schema, 'XTracker::Schema' );
isa_ok( $factory, 'Net::Stomp::Producer' );

my $preorder_exportable = Test::XTracker::Data::PreOrder->create_pre_order_with_exportable_items();
my $preorder_part_exportable = Test::XTracker::Data::PreOrder->create_pre_order_with_exportable_items();
my $preorder_non_exportable = Test::XTracker::Data::PreOrder->create_complete_pre_order();
my $preorder_with_no_towncity = Test::XTracker::Data::PreOrder->create_pre_order_with_exportable_items();
my $channel = $preorder_exportable->channel;

my $channel_name = $channel->web_name;
my $queue    = config_var('Producer::PreOrder::TriggerWebsiteOrder','routes_map')->{$channel_name};
ok($queue,"the channel $channel_name is mapped to a destination");
my $msg_type = 'XT::DC::Messaging::Producer::PreOrder::TriggerWebsiteOrder';

note "Testing AMQ message type: $msg_type into queue: $queue";

my @exportable_items     = $preorder_exportable->exportable_items->order_by_id->all;
my @partial_export       = ($preorder_part_exportable->exportable_items->order_by_id->all)[0,1];
my @non_exportable_items = $preorder_non_exportable->pre_order_items->order_by_id->all;
my @exportable_no_towncity =  $preorder_with_no_towncity->exportable_items->order_by_id->all;

#-------------------------------------------------------
# Test: Wrong channel sends no message
# NOTE: this assumes theOutnet does not do pre-order!

$amq->clear_destination();

my $old_customer_id = $preorder_exportable->customer_id;

my $new_customer_id = Test::XTracker::Data->create_test_customer(
    channel_id => Test::XTracker::Data->channel_for_out->id,
);

$preorder_exportable->update({
    customer_id => $new_customer_id,
});

like($preorder_exportable->channel->web_name,qr{^OUTNET-},
     'we actually got a Outnet preorder');

my $export_bad_channel = {
    preorder => $preorder_exportable,
    items    => \@exportable_items,
};

lives_ok { $factory->transform_and_send( $msg_type,
                                         $export_bad_channel, ) }
  "Incorrect channel does not die";
$amq->assert_messages({
    assert_count => 0,
});

$preorder_exportable->update({
    customer_id => $old_customer_id,
});

#-------------------------------------------------------
# Test: All items exported ok

$amq->clear_destination($queue);

my $export_ok_data = {
    preorder => $preorder_exportable,
    items    => \@exportable_items,
};

$preorder_exportable->invoice_address->update( {
    county   => 'COUNTY',
    towncity => 'TOWN',
} );
$preorder_exportable->shipment_address->update( {
    county   => 'COUNTY',
    towncity => 'TOWN',
} );

lives_ok { $factory->transform_and_send( $msg_type,
                                         $export_ok_data, ) }
  "Can send valid new message";

$amq->assert_messages({
    destination => $queue,
    assert_header => superhashof({
        type => 'PreOrderTriggerWebsiteOrder',
    }),
    assert_body => superhashof(msg_body(
        $preorder_exportable, $channel, \@exportable_items
    )),
}, 'Message contains the correct pre-order order trigger data');


#-------------------------------------------------------
# Test: Some items exported ok

$amq->clear_destination($queue);

my $export_partial_data = {
    preorder => $preorder_part_exportable,
    items    => \@partial_export,
};

lives_ok { $factory->transform_and_send( $msg_type,
                                         $export_partial_data, )}
  "Can send valid new message with specific exportable skus only";

$amq->assert_messages({
    destination => $queue,
    assert_header => superhashof({
        type => 'PreOrderTriggerWebsiteOrder',
    }),
    assert_body => superhashof(msg_body(
        $preorder_part_exportable, $channel, \@partial_export
    )),
}, 'Message contains the correct pre-order order trigger data for specific exportable skus only');

#-------------------------------------------------------
# Test: When Shipping/Billing Address doesn't have a Town/City (County should be used)

$amq->clear_destination($queue);

my $export_no_towncity_data = {
    preorder => $preorder_with_no_towncity,
    items    => \@exportable_no_towncity,
};

$preorder_with_no_towncity->invoice_address->update( {
    county   => 'COUNTY',
    towncity => '',
} );
$preorder_with_no_towncity->shipment_address->update( {
    county   => 'COUNTY',
    towncity => '',
} );

lives_ok { $factory->transform_and_send( $msg_type,
                                         $export_no_towncity_data, ) }
  "Can send valid message with no town/city in addresses";

$amq->assert_messages({
    destination => $queue,
    assert_header => superhashof({
        type => 'PreOrderTriggerWebsiteOrder',
    }),
    assert_body => superhashof(msg_body(
        $preorder_with_no_towncity, $channel, \@exportable_no_towncity
    )),
}, 'Message contains the correct Shipping/Billing Address data');

#-------------------------------------------------------
# Test: Incorrect items abort entire message

$amq->clear_destination($queue);

my $export_bad_data = {
    preorder => $preorder_exportable,
    items    => \@non_exportable_items,
};

dies_ok { $factory->transform_and_send( $msg_type,
                                        $export_bad_data, ) }
  "Incorrect items aborts message send";

done_testing;

#-------------------------------------------------------

sub preorder_shipping_info {
    my $preorder = shift;

    my $si = {};
    my $sa = {};

    $sa->{first_name}      = $preorder->shipment_address->first_name;
    $sa->{last_name}       = $preorder->shipment_address->last_name;
    $sa->{line1}           = $preorder->shipment_address->address_line_1;
    $sa->{line2}           = $preorder->shipment_address->address_line_2;
    $sa->{line3}           = $preorder->shipment_address->address_line_3;
    $sa->{towncity}        = $preorder->shipment_address->towncity;
    $sa->{county}          = $preorder->shipment_address->county;
    #$sa->{country}         = $preorder->shipment_address->country;
    $sa->{country_iso}     = $preorder->shipment_address->country_ignore_case->code;
    $sa->{postcode}        = $preorder->shipment_address->postcode;
    $sa->{comparison_hash} = $preorder->shipment_address->address_hash . '==';

    # 'towncity' should be populated with 'county' if empty
    $sa->{towncity} ||= $sa->{county};

    $si->{shipping_address}        = $sa;

    # Shipping and packaging are always free
    foreach my $sku ($preorder->shipping_charge->sku,
                     $preorder->packaging_type->sku   ) {
        push @{$si->{shipping_items}}, { sku    => $sku,
                                         price  => 0,
                                         tax    => 0,
                                         duty   => 0,
                                       };
    }

    return $si;
}


sub preorder_item_info {

    my $export_items = shift;

    my @item_data = ();

    foreach my $i ( @$export_items ) {

        my $v = $i->variant;
        my $p = $v->product;

        push @item_data, {
            sku   => $v->sku,
            price => $i->unit_price,
            tax   => $i->tax,
            duty  => $i->duty,
        };
    }

    return \@item_data;
}

sub payment_info {

    my ($preorder) = @_;

    my $payment = {};

    $payment->{psp_reference}     = $preorder->get_payment->psp_ref;
    $payment->{preauth_reference} = $preorder->get_payment->preauth_ref;

    my $ba = {};

    $ba->{first_name}      = $preorder->invoice_address->first_name;
    $ba->{last_name}       = $preorder->invoice_address->last_name;
    $ba->{line1}           = $preorder->invoice_address->address_line_1;
    $ba->{line2}           = $preorder->invoice_address->address_line_2;
    $ba->{line3}           = $preorder->invoice_address->address_line_3;
    $ba->{towncity}        = $preorder->invoice_address->towncity;
    $ba->{county}          = $preorder->invoice_address->county;
    #$ba->{country}         = $preorder->invoice_address->country;
    $ba->{country_iso}     = $preorder->invoice_address->country_ignore_case->code;
    $ba->{postcode}        = $preorder->invoice_address->postcode;
    $ba->{comparison_hash} = $preorder->invoice_address->address_hash . '==';

    # 'towncity' should be populated with 'county' if empty
    $ba->{towncity} ||= $ba->{county};

    $payment->{billing_address} = $ba;

    return $payment;
}

sub msg_body {

    my ($preorder, $channel, $items) = @_;

    return {
        channel           => $channel->website_name,
        preorder_number   => $preorder->pre_order_number,
        customer_number   => $preorder->customer->is_customer_number,
        payment           => payment_info($preorder),
        shipping_info     => preorder_shipping_info($preorder),
        items             => preorder_item_info($items),
    }
}
