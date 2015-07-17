#!/usr/bin/env perl
package ActiveMQ::Receive::CreateRMA;

use NAP::policy "tt", 'test';
use base 'Test::Class';

use Readonly;

use Test::XTracker::RunCondition dc => [ qw( DC1 DC2 ) ], export => qw( $distribution_centre );
use Test::XTracker::Data;
use Test::XTracker::MessageQueue;
use Test::NAP::Messaging::Helpers 'napdate';
use Test::XT::ActiveMQ;
use XTracker::Config::Local     qw( config_var );

use XTracker::Constants::FromDB qw/
  :correspondence_templates
  :customer_issue_type
  :shipment_type
  :renumeration_type
  :renumeration_status
  :renumeration_class
/;

Readonly my $PWS_REQUEST_DATE => "2009-09-01 12:52:19 +0100";

sub startup : Test(startup) {
    ($_[0]->{amq},$_[0]->{app}) = Test::XTracker::MessageQueue->new_with_app;
    $_[0]->{schema} = Test::XTracker::Data->get_schema;
}

sub nap_arma : Tests {
    my ( $self ) = @_;
    my $channel = Test::XTracker::Data->channel_for_business(name=>'nap');
    $self->arma_tests( $channel );
}

sub outnet_arma : Tests {
    my ( $self ) = @_;
    my $channel = Test::XTracker::Data->channel_for_business(name=>'out');
    $self->arma_tests( $channel );
}

sub mrp_arma : Tests {
    my ( $self ) = @_;
    my $channel = Test::XTracker::Data->channel_for_business(name=>'mrp');
    $self->arma_tests( $channel );
}

sub arma_tests {
    my ( $self, $channel ) = @_;

    note "TESTING: ".$channel->name;

    my $pids = Test::XTracker::Data->find_or_create_products({
        channel_id => $channel->id,
        how_many => 2,
        dont_ensure_stock => 1,
    });

    # for each pid make sure there's stock
    foreach my $item (@{$pids}) {
        Test::XTracker::Data->ensure_variants_stock($item->{pid});
    }

    my ($order, $order_hash) = Test::XTracker::Data->create_db_order({
        pids => $pids,
        attrs => [
            { price => 100.00, tax => 5, duty => 0, },      # zero duty as since CANDO-91 domestic exchanges would incurr
            { price => 250.00, tax => 5, duty => 0, },      # duty charges as in the real world they would be zero
        ],
        base => {
            channel_id => $channel->id,
            customer_id => Test::XTracker::Data->create_test_customer(channel_id => $channel->id),
        },
    });
    my $shipment = $order->get_standard_class_shipment;
    # update Shipment Address Country to be for the DC's own Country
    $shipment->shipment_address->update( { country => config_var( 'DistributionCentre', 'country' ) } );

    my $pws_reason = $self->pws_reason($CUSTOMER_ISSUE_TYPE__7__QUALITY);
    my $variant = $pids->[0]{variant};
    my ($payload,$header) = Test::XT::ActiveMQ::rma_req_message($order, [{
        "returnReason" => $pws_reason,
        "exchangeSku" => $variant->sku,
        "itemReturnRequestDate" => $PWS_REQUEST_DATE,
        "faultDescription" => "The zip is broken",
        "sku" => $variant->sku,
    }]);

    # get the latest PWS stock record to check once the
    # exchange has been made that a new one has been created
    my $pws_stock_log_rs    = $variant->log_pws_stocks->search( {}, { order_by => 'me.id DESC' } );
    my $org_pws_stock_log   = $pws_stock_log_rs->first;
    my $org_pws_stock_log_id= ( defined $org_pws_stock_log ? $org_pws_stock_log->id : 0 );  # get the latest Id for comparison later
    note "ORIGINAL VARIANT PWS STOCK LOG ID: ".$org_pws_stock_log_id;

    my $order_queue_name    = $self->order_queue_name( $channel );
    my $return_queue_name   = $self->return_queue_name($channel);

    $self->{amq}->clear_destination( $return_queue_name );
    $self->{amq}->clear_destination( $order_queue_name );

    my $res = $self->{amq}->request(
        $self->{app},
        $return_queue_name,
        $payload,
        $header,
    );
    ok( $res->is_success,
        "Result from sending to $return_queue_name queue, 'return_request' action" );

    my $return = $shipment->returns->not_cancelled->first;

    ok ($return, "Return was created") or die "Couldn't create return";
    ok ( !defined $return->renumerations->first,
            "No Renumeration Created as there is no Refund or Charges" );

    my @items = $shipment->shipment_items->order_by_sku;

    $self->{amq}->assert_messages({
        destination => $order_queue_name,
        assert_header => superhashof({
            type => 'OrderMessage',
        }),
        assert_body => superhashof({
            '@type' => 'order',
            orderNumber => $order->order_nr,
            rmaNumber              => $return->rma_number,
            returnExpiryDate       => napdate($return->expiry_date),
            returnCreationDate     => napdate($return->creation_date),
            returnCancellationDate => napdate($return->cancellation_date),

            orderItems => superbagof(superhashof({
                exchangeSku        => $variant->sku,
                status             => "Return Pending",
                returnReason       => $pws_reason,
                returnCreationDate => napdate($return->return_items->first->creation_date),
            })),
        }),
        assert_count => 2, # Is this correct?? XT::Domain::Returns
                           # already sends updates, and
                           # ::Consumer::Returns *also* sends them!
    }, 'order status sent on AMQ' )
    or note p $res->content;

    my $note = $return->return_notes->first;

    ok($note, "Got a returns note added to shipment");
    is(
        $note->note,
        "Created from Website request on $PWS_REQUEST_DATE\n"
      . $variant->sku
      . " - Fault Description: The zip is broken",
        "Have return notes"
    );

    cmp_ok(
        $self->{schema}->resultset('Public::ShipmentEmailLog')->search({
        shipment_id => $shipment->id,
        correspondence_templates_id => $CORRESPONDENCE_TEMPLATES__RETURN_FSLASH_EXCHANGE
    })->count,
    '==',
    1,
    "Return creation email logged");

    # check PWS Stock Log shows stock going down by 1
    my $new_pws_stock_log   = $pws_stock_log_rs->reset->first;
    ok( defined $new_pws_stock_log, "Got a PWS Stock Log for Exchange Variant: ".$variant->sku );
    note "NEW VARIANT PWS STOCK LOG ID: ".$new_pws_stock_log->id;
    cmp_ok( $new_pws_stock_log->id, '>', $org_pws_stock_log_id, "PWS Stock Log Id is greater than original log" );
    cmp_ok( $new_pws_stock_log->quantity, '==', -1, "PWS Stock Log Quantity is '-1'" );
    is( $new_pws_stock_log->notes, "Exchange on ".$shipment->id, "PWS Stock Log notes as expected: 'Exhange on ".$shipment->id."'" );


    note "Create an Exchange again but this time Expect Charges";
    ($order, $order_hash)   = Test::XTracker::Data->create_db_order({
        pids => $pids,
        attrs => [
            { price => 100.00, tax => 5, duty => 15, },
            { price => 250.00, tax => 5, duty => 15, },
        ],
        base => {
            shipping_charge => 10,
            channel_id => $channel->id,
            customer_id => Test::XTracker::Data->create_test_customer(channel_id => $channel->id),
            shipment_type => $SHIPMENT_TYPE__INTERNATIONAL,
            invoice_address_id => Test::XTracker::Data->order_address( {
                                                                address => 'create',
                                                                country => Test::XTracker::Data->get_non_charge_free_state()->country,
                                                            } )->id,
        },
    });

    $self->{amq}->clear_destination( $return_queue_name );
    $self->{amq}->clear_destination( $order_queue_name );

    ($payload,$header) = Test::XT::ActiveMQ::rma_req_message($order, [{
        "returnReason" => $pws_reason,
        "exchangeSku" => $variant->sku,
        "itemReturnRequestDate" => $PWS_REQUEST_DATE,
        "faultDescription" => "The zip is broken",
        "sku" => $variant->sku,
    }]);
    $res    = $self->{amq}->request(
        $self->{app},
        $return_queue_name,
        $payload,
        $header,
    );
    ok( $res->is_success,
        "Result from sending to $return_queue_name queue, 'return_request' action" );

    $shipment   = $order->discard_changes->get_standard_class_shipment;
    $return     = $shipment->returns->not_cancelled->first;
    my $renum   = $return->renumerations->first;

    ok( $return, "Return was created") or die "Couldn't create return";
    ok( $renum, "Renumeration Created as there are Charges" );

    cmp_ok( $renum->total_value, '==', ( 5 + 15 ), "Return Renumeration Total is Tax + Duty" );
    cmp_ok( $renum->renumeration_class_id, '==', $RENUMERATION_CLASS__RETURN, "Return Renumeration is of Class 'Return'" );
    cmp_ok( $renum->renumeration_type_id, '==', $RENUMERATION_TYPE__CARD_DEBIT, "Return Renumeration Type is 'Card Debit'" );
    cmp_ok( $renum->renumeration_status_id, '==', $RENUMERATION_STATUS__PENDING, "Return Renumeration Status is 'Pending'" );

    $self->{amq}->assert_messages({
        destination => $order_queue_name,
        assert_header => superhashof({
            type => 'OrderMessage',
        }),
        assert_body => superhashof({
            '@type' => 'order',
            orderNumber => $order->order_nr,
            rmaNumber              => $return->rma_number,
            returnExpiryDate       => napdate($return->expiry_date),
            returnCreationDate     => napdate($return->creation_date),
            returnCancellationDate => napdate($return->cancellation_date),

            orderItems => superbagof(superhashof({
                exchangeSku        => $variant->sku,
                status             => "Return Pending",
                returnReason       => $pws_reason,
                returnCreationDate => napdate($return->return_items->first->creation_date),
            })),
        }),
        assert_count => 2, # Is this correct?? XT::Domain::Returns
                           # already sends updates, and
                           # ::Consumer::Returns *also* sends them!
    }, 'order status sent on AMQ' )
    or note p $res->content;
}

sub return_queue_name {
    my ( $self, $channel ) = @_;
    my $dc = lc Test::XTracker::Data->whatami;
    my ( $ch_name ) = split /-/, lc($channel->web_name);
    return "/queue/${dc}-${ch_name}-returns";
}

sub order_queue_name {
    my ( $self, $channel ) = @_;
    my $queue_prefix = lc $channel->web_name;
    return "/queue/${queue_prefix}-orders";
}

sub pws_reason {
    my ( $self, $reason_id ) = @_;
    return $self->{schema}->resultset('Public::CustomerIssueType')
                          ->find($reason_id)
                          ->pws_reason;
}

Test::Class->runtests;
