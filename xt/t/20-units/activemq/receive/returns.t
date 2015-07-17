#!/usr/bin/env perl

use NAP::policy "tt",     qw( class test );

BEGIN {
    extends "NAP::Test::Class";
    }

use Data::Dumper;
use Test::XTracker::Data;
use Test::XTracker::MessageQueue;
use Test::XT::ActiveMQ;
use XTracker::Config::Local         qw( config_var );
use XTracker::Constants::FromDB qw(
    :authorisation_level
    :shipment_status
    :shipment_type
    :order_status
    :customer_category
    :customer_issue_type
    :return_type
    :shipment_item_returnable_state
);

use Clone 'clone';

=head1 TEST PLAN

    This is test is only for JC channel.For other channels, there are various other
    tests which already test the channel specific logic.
   * Test JC return gets created succesfully.
   * duplicate payload returns errors
   * payload with return items get created succesfully
   * payload with one incorrect return item leads to creation failure.
   * payload with non-returnable item leads to creation failure.

=cut




sub startup : Test( startup => no_plan ) {
    my $self = shift;
    ($self->{amq}, $self->{app} ) = Test::XTracker::MessageQueue->new_with_app;
    $self->{schema} = XT::DC::Messaging->model('Schema');
    $self->{pws_request_date} = "2013-09-01 12:52:19 +0100";
}

sub setup : Tests( setup => no_plan ) {
    my $self = shift;

    my $channel = Test::XTracker::Data->channel_for_business(name=>'jc');
    my $pids = Test::XTracker::Data->grab_products({
        channel => $channel,
        how_many => 2,
        ensure_stock_all_variants => 1,
    });

    $self->{channel} = $channel;

    my ($order, $order_hash) = Test::XTracker::Data->create_db_order({
        pids => $pids,
        base => { channel_id => $channel->id} ,
        attrs => [
            { price => 250.00 },
            { price => 100.00 },
        ],
    });
    $self->{order} = $order;
    $self->{pids}= $pids;

    # populate 'pws_ol_id' (external Line Item Id)
    my $shipment_item_rs = $order->get_standard_class_shipment->shipment_items;
    $shipment_item_rs->update( {
        # make 'pws_ol_id' the same as Variant Id so
        # as to make life easier tying SKUs to Items
        pws_ol_id => \'variant_id',
    } );
    $order->discard_changes;

    my $pws_reason = $self->pws_reason($CUSTOMER_ISSUE_TYPE__7__QUALITY);
    my $variant = $pids->[0]{variant};
    $self->{variant} = $variant;

    ($self->{payload},$self->{header}) = Test::XT::ActiveMQ::rma_req_message($order, [{
        "returnReason" => $pws_reason,
        "itemReturnRequestDate" => $self->{pws_request_date},
        "faultDescription" => "The zip is broken",
        "sku" => 'TP' . $variant->sku,
        "externalLineItemId" => $variant->id,
    }]);

    $self->{third_party_rs} = $self->schema->resultset('Public::ThirdPartySku')

}

sub teardown : Test( teardown => no_plan ) {
    my $self    = shift;

    $self->SUPER::teardown;
    $self->{third_party_rs}->delete;
}


=head1 TESTS

=head2 test__create_rma_jc

Test creating a basic Return.

=cut

sub test__create_rma_jc : Tests {
    my $self = shift;

    # update the payload to have ExternalItemId
    my $third_party_sku_rs = $self->{third_party_rs};
    my $ship_items  = $self->{order}->shipments->first->shipment_items->order_by_sku;

    while ( my $item = $ship_items->next ) {
        $third_party_sku_rs->update_or_create({
            variant_id  => $item->variant_id,
            business_id => $self->{channel}->business->id,
            third_party_sku => 'TP' . $item->variant->sku,
        });
    }

    my $channel = $self->{channel};
    my $payload = $self->{payload};
    my $header  = $self->{header};
    my $order   = $self->{order};

    my $org_payload= clone($payload);

    my $return_queue_name   = $self->return_queue_name($channel);
    my $jc_queue_name       = $self->jc_queue_name();

    $self->{amq}->clear_destination( $return_queue_name );
    $self->{amq}->clear_destination( $jc_queue_name );

    my $res = $self->{amq}->request(
        $self->{app},
        $return_queue_name,
        $payload,
        $header,
    );
    ok( $res->is_success,
        "Result from sending to $return_queue_name queue, 'return_request' action" );

    # Test1 : return is created succesfully.
    my $return = $order->get_standard_class_shipment->returns->not_cancelled->first;
    ok ($return, "Return was created");

    $self->{amq}->assert_messages( {
        destination => $jc_queue_name,
        assert_header => superhashof({
            type => 'return_request_ack',
        }),
        assert_body => superhashof({ status => 'success'}),
    }, 'Suucess Message was sent');



    $self->{amq}->clear_destination( $return_queue_name );
    $self->{amq}->clear_destination( $jc_queue_name );

    #Duplicate RMA req
    $res = $self->{amq}->request(
        $self->{app},
        $return_queue_name,
        $org_payload,
        $header,
    );
    ok( $res->is_success,
        "Result from sending to $return_queue_name queue, 'return_request' action" );

    #Test2 : Duplicate return creation failure
    $self->{amq}->assert_messages( {
        destination => $jc_queue_name,
        assert_header => superhashof({
            type => 'return_request_ack',
        }),
        assert_body => superhashof({ status => 'failure'}),
    }, 'Duplicate Message Failure ');

}

=head2 test__multi_item_rma_jc

Test processing More than one Return Item, one of which is an Exchange.

=cut

sub test__multi_item_rma_jc : Tests {
    my  $self = shift;

    my $pws_reason = $self->pws_reason($CUSTOMER_ISSUE_TYPE__7__QUALITY);
    my ($payload ,$header) = Test::XT::ActiveMQ::rma_req_message($self->{order}, [{
            "returnReason" => $pws_reason,
            "itemReturnRequestDate" => $self->{pwd_request_date},
            "faultDescription" => "The zip is broken",
            "sku" => 'TP' . $self->{pids}->[0]{variant}->sku,
            "externalLineItemId" => $self->{pids}->[0]{variant}->id,
            "exchangeSku" => 'TP' . $self->{pids}->[0]{variant}->sku,
        },
        {
            "returnReason" => $pws_reason,
            "itemReturnRequestDate" => $self->{pwd_request_date},
            "faultDescription" => "The zip is broken",
            "sku" => 'TP' . $self->{pids}->[1]{variant}->sku,
            "externalLineItemId" => $self->{pids}->[1]{variant}->id,
        }

    ]);


    note "Test that if one Item fails then All fail";

    my $third_party_sku_rs = $self->{third_party_rs};
    my $ship_items  = $self->{order}->shipments->first->shipment_items->order_by_sku;

    # only create a 3rd Party SKU for one of the Items
    while ( my $item = $ship_items->next ) {
        $third_party_sku_rs->update_or_create({
            variant_id  => $item->variant_id,
            business_id => $self->{channel}->business->id,
            third_party_sku => 'TP' . $item->variant->sku,
        });
        last;
    }

    my $channel = $self->{channel};
    my $return_queue_name   = $self->return_queue_name($channel);
    my $jc_queue_name       = $self->jc_queue_name();

    $self->{amq}->clear_destination( $return_queue_name );
    $self->{amq}->clear_destination( $jc_queue_name);

    my $org_payload= clone($payload);
    my $res = $self->{amq}->request(
        $self->{app},
        $return_queue_name,
        $payload,
        $header,
    );
    # Test : Invalid SKu Failure
    $self->{amq}->assert_messages( {
        destination => $jc_queue_name,
        assert_header => superhashof({
            type => 'return_request_ack',
        }),
        assert_body => superhashof( {
            status => 'failure',
            error => superbagof( 'TP' . $self->{pids}->[1]{variant}->sku . " sku is not valid Third party sku" ),
        } ),
    }, 'Invalid External Sku failure');

    note "Test Return is not created if one of the item is marked as 'non-returnable'";

    while ( my $item = $ship_items->next ) {
        $item->update({returnable_state_id => $SHIPMENT_ITEM_RETURNABLE_STATE__NO } );
        $third_party_sku_rs->update_or_create({
            variant_id  => $item->variant_id,
            business_id => $self->{channel}->business->id,
            third_party_sku => 'TP' . $item->variant->sku,
        });
    }

    $self->{amq}->clear_destination( $return_queue_name );
    $self->{amq}->clear_destination( $jc_queue_name);

    $payload = $org_payload;
    $res = $self->{amq}->request(
        $self->{app},
        $return_queue_name,
        $payload,
        $header,
    );

    $self->{amq}->assert_messages( {
        destination => $jc_queue_name,
        assert_header => superhashof({
            type => 'return_request_ack',
        }),
        assert_body => superhashof( {
            status => 'failure',
            error => superbagof( "Non Returnable sku sent. Req: TP".$self->{pids}->[1]{variant}->sku. ". DB: ".  $self->{pids}->[1]{variant}->sku),
        } ),
    }, 'Non-Returnable SKU failure');

    note "Test all Items are ok then Return is created";

    foreach my $item ( $ship_items->all ) {
        $item->update({returnable_state_id => $SHIPMENT_ITEM_RETURNABLE_STATE__YES } );
        $item->discard_changes;
    }

    $self->{amq}->clear_destination( $return_queue_name );
    $self->{amq}->clear_destination( $jc_queue_name);

    $payload = $org_payload;
    $res = $self->{amq}->request(
        $self->{app},
        $return_queue_name,
        $payload,
        $header,
    );

    # Test return with valid items created.
    ok( $res->is_success,
        "Result from sending to $return_queue_name queue, 'return_request' action" );
    my $return = $self->{order}->get_standard_class_shipment->returns->not_cancelled->first;
    ok ($return, "Return was created");
    # check there are Return & Exchange Items created
    my $return_item   = $return->return_items->find( { return_type_id => $RETURN_TYPE__RETURN } );
    my $exchange_item = $return->return_items->find( { return_type_id => $RETURN_TYPE__EXCHANGE } );
    cmp_ok( $exchange_item->shipment_item->variant_id, '==', $self->{pids}->[0]{variant}->id,
                    "Exchange Item is for the Expected SKU" );
    cmp_ok( $return_item->shipment_item->variant_id, '==', $self->{pids}->[1]{variant}->id,
                    "Return Item is for the Expected SKU" );
}

=head2 test__when_not_setup_to_fail_on_any_item

Test that when not set-up to fail the entire request if one Item fails
the request still works and creates a Return for what it can.

=cut

sub test__when_not_setup_to_fail_on_any_item : Tests() {
    my $self    = shift;

    my $channel = $self->{channel};

    # redefine the 'raise_failure_for_any_line_item' method to return FALSE
    my $orig_failure_method = \&XT::DC::Messaging::ConsumerBase::Returns::raise_failure_for_any_line_item;
    {
        no warnings 'redefine';
        *XT::DC::Messaging::ConsumerBase::Returns::raise_failure_for_any_line_item = sub {
            return 0;
        };
    }

    my $pws_reason = $self->pws_reason($CUSTOMER_ISSUE_TYPE__7__QUALITY);
    my ($org_payload ,$header) = Test::XT::ActiveMQ::rma_req_message($self->{order}, [{
            "returnReason" => $pws_reason,
            "itemReturnRequestDate" => $self->{pwd_request_date},
            "faultDescription" => "The zip is broken",
            "sku" => 'TP' . $self->{pids}->[0]{variant}->sku,
            "externalLineItemId" => $self->{pids}->[0]{variant}->id,
        },
        {
            "returnReason" => $pws_reason,
            "itemReturnRequestDate" => $self->{pwd_request_date},
            "faultDescription" => "The zip is broken",
            "sku" => 'TP' . $self->{pids}->[1]{variant}->sku,
            "externalLineItemId" => $self->{pids}->[1]{variant}->id,
        }
    ]);

    my $third_party_sku_rs = $self->{third_party_rs};
    my $ship_items         = $self->{order}->shipments->first->shipment_items->order_by_sku;

    while ( my $item = $ship_items->next ) {
        $third_party_sku_rs->update_or_create({
            variant_id  => $item->variant_id,
            business_id => $self->{channel}->business->id,
            third_party_sku => 'TP' . $item->variant->sku,
        });
    }

    my $return_queue_name   = $self->return_queue_name($channel);
    my $jc_queue_name       = $self->jc_queue_name();


    note "Test when All Items are Unidentifiable";

    my $payload = clone( $org_payload );
    delete $payload->{returnItems}[0]{externalLineItemId};
    delete $payload->{returnItems}[1]{externalLineItemId};

    $self->{amq}->clear_destination( $return_queue_name );
    $self->{amq}->clear_destination( $jc_queue_name);

    my $res = $self->{amq}->request(
        $self->{app},
        $return_queue_name,
        $payload,
        $header,
    );
    ok( $res->is_success, "Requesting with One Bad Line Item still ok" );
    my $return = $self->{order}->get_standard_class_shipment->returns->not_cancelled->first;
    ok( !defined $return, "No Return was Created" );
    my @messages_sent = $self->{amq}->messages( $jc_queue_name );
    cmp_ok( scalar( @messages_sent ), '==', 0, "No Failure Ack. Messages Sent" )
                            or diag "Messages Sent on Queue '${jc_queue_name}': " . p( @messages_sent );


    note "Test when one SKU is GARBAGE";

    $self->{amq}->clear_destination( $return_queue_name );
    $self->{amq}->clear_destination( $jc_queue_name);

    $payload = clone( $org_payload );
    $payload->{returnItems}[0]{sku} = 'GARBAGE';
    $res = $self->{amq}->request(
        $self->{app},
        $return_queue_name,
        $payload,
        $header,
    );
    ok( $res->is_success, "Requesting with One Bad Line Item still ok" );
    $return = $self->{order}->get_standard_class_shipment->returns->not_cancelled->first;
    isa_ok( $return, 'XTracker::Schema::Result::Public::Return', "and a Return was still created" );
    cmp_ok( $return->return_items->count, '==', 1, "and has only one Return Item" );

    # Restore the redefined failure Method
    {
        no warnings 'redefine';
        *XT::DC::Messaging::ConsumerBase::Returns::raise_failure_for_any_line_item = $orig_failure_method;
    }
}

sub pws_reason {
    my ( $self, $reason_id ) = @_;
    return $self->{schema}->resultset('Public::CustomerIssueType')
                          ->find($reason_id)
                          ->pws_reason;
}

sub return_queue_name {
    my ( $self, $channel ) = @_;
    my $dc = lc Test::XTracker::Data->whatami;
    my ( $ch_name ) = split /-/, lc($channel->web_name);
    return "/queue/${dc}-${ch_name}-returns";
}

sub jc_queue_name {

    my $self = shift;
    return "/queue/returns-ack-mercury";
}

Test::Class->runtests;
