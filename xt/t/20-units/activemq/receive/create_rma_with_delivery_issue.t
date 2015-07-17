#!/usr/bin/env perl
package ActiveMQ::Receive::CreateRMA;
use NAP::policy "tt", 'test';
use base 'Test::Class';

=head2 CANDO-182: BUG - Checking Tax & Duty is Correctly Refunded when PWS Return Reason is 'DELIVERY_ISSUE'

This tests that when an ARMA return is created using the PWS Reason for Return as 'DELIVERY_ISSUE' that
the Tax & Duty for a Shipment Item is refunded. The reason for this is that 'DELIVERY_ISSUE' is against 2
xTracker reasons: 'Delivery issue' & 'Dispatch/Return' and this meant sometimes the 'Dispatch/Return'
reason was being used which inside 'XT::Domain::Returns' would do slightly different things which
ended up in Tax & Duty not being refunded when it should have been for customers whose shipping addresses
are in a 'charge_free_state'.

=cut

use Readonly;

use Test::XTracker::Data;
use Test::XTracker::MessageQueue;
use Test::NAP::Messaging::Helpers 'napdate';
use Test::XT::ActiveMQ;

use XTracker::Database::Return  qw( calculate_returns_charge );
use XTracker::Config::Local     qw( config_var );
use XTracker::Constants::FromDB qw/
  :correspondence_templates
  :customer_issue_type
  :renumeration_type
  :refund_charge_type
/;

Readonly my $PWS_REQUEST_DATE => "2009-09-01 12:52:19 +0100";

sub startup : Test(startup) {
    $_[0]->{schema} = Test::XTracker::Data->get_schema;
    ($_[0]->{amq},$_[0]->{app}) = Test::XTracker::MessageQueue->new_with_app;
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

    my $pids = Test::XTracker::Data->find_or_create_products({
        channel_id        => $channel->id,
        how_many          => 2,
        dont_ensure_stock => 1,
    });
    # for each pid make sure there's stock
    foreach my $item (@{$pids}) {
        Test::XTracker::Data->ensure_variants_stock($item->{pid});
    }

    # get a country which will not refund Tax & Duty
    # and then change it so that it does
    my $country = Test::XTracker::Data->get_non_tax_duty_refund_state();
    $country->create_related( 'return_country_refund_charges', { refund_charge_type_id => $REFUND_CHARGE_TYPE__TAX, can_refund_for_return => 1 } );
    $country->create_related( 'return_country_refund_charges', { refund_charge_type_id => $REFUND_CHARGE_TYPE__DUTY, can_refund_for_return => 1 } );

    my ($order, $order_hash) = Test::XTracker::Data->create_db_order({
        pids => $pids,
        attrs => [
            { price => 100.00, tax => 5,  duty => 10, },
            { price => 250.00, tax => 15, duty => 25, },
        ],
        base => {
            channel_id => $channel->id,
            customer_id => Test::XTracker::Data->create_test_customer(channel_id => $channel->id),
            create_renumerations => 1,
            invoice_address_id => Test::XTracker::Data->order_address({
                address => 'create',
                country => $country->country,
            })->id,
        },
    });
    my $shipment     = $order->get_standard_class_shipment;
    my $renumeration = $shipment->renumerations->first;
    my @ship_items   = $shipment->shipment_items->order_by_sku;
    foreach my $si ( @ship_items ) {
        $si->create_related(
            'renumeration_items',
            {
                unit_price  => $si->unit_price,
                tax         => $si->tax,
                duty        => $si->duty,
                renumeration_id => $renumeration->id,
            },
        );
    }
    # update the tenders with the grand total for the renumeration
    $order->tenders->first->update( { type_id => $RENUMERATION_TYPE__CARD_DEBIT,  value => $renumeration->grand_total } );

    my $pws_reason = $self->pws_reason( $CUSTOMER_ISSUE_TYPE__7__DELIVERY_ISSUE );
    my $variant = $ship_items[0]->variant;
    my ($payload, $header) = Test::XT::ActiveMQ::rma_req_message($order, [{
        "returnReason"          => $pws_reason,
        "itemReturnRequestDate" => $PWS_REQUEST_DATE,
        "faultDescription"      => "The zip is broken",
        "sku"                   => $variant->sku,
    }]);

    my $return_queue_name = $self->return_queue_name( $channel );
    my $order_queue_name  = $self->order_queue_name( $channel );
    $self->{amq}->clear_destination( $return_queue_name );
    $self->{amq}->clear_destination( $order_queue_name );

    my $res = $self->{amq}->request(
        $self->{app},
        $return_queue_name,
        $payload,
        $header
    );
    ok( $res->is_success,
        "Result from sending to $return_queue_name queue, 'return_request' action" );

    my $return = $shipment->returns->not_cancelled->first;

    ok ($return, "Return was created") or die "Couldn't create return";
    note "Return Id/RMA: " . $return->id . "/" . $return->rma_number;

    # check the refund renumeration has tax
    my $expected_refundtotal = $self->get_shipping_refund( $shipment )
                                + $ship_items[0]->unit_price
                                + $ship_items[0]->tax
                                + $ship_items[0]->duty;
    my $refund_renum       = $return->renumerations->first;
    my $refund_renum_item  = $refund_renum->renumeration_items->first;
    cmp_ok( $refund_renum->grand_total, '==', $expected_refundtotal, "Refund Total as expected: $expected_refundtotal" );
    cmp_ok( $refund_renum_item->unit_price, '==', $ship_items[0]->unit_price, "Refund Item Unit Price same as Shipment Item" );
    cmp_ok( $refund_renum_item->tax, '==', $ship_items[0]->tax, "Refund Item Tax same as Shipment Item" );
    cmp_ok( $refund_renum_item->duty, '==', $ship_items[0]->duty, "Refund Item Duty same as Shipment Item" );

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
                sku                => $variant->sku,
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
        "Return creation email logged",
    );

    # remove the country charges
    $country->return_country_refund_charges->delete;
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

# get the expected shipping refund which depends
# on channel and DC so use the 'calculate_returns_charge'
# function to get the correct amount
sub get_shipping_refund {
    my ( $self, $shipment ) = @_;

    # set-up data to get the shipping refund amount
    my ( $refund, $charge ) = calculate_returns_charge({
        shipment_row             => $shipment,
        num_return_items         => 1,
        num_exchange_items       => 0,
        got_faulty_items         => 0,
        previous_shipping_refund => 0, # this needs to be zero because
                                       # it will clash with the refund
                                       # you have just created
    });

    # return the shipping refund amount
    return $refund;
}

Test::Class->runtests;

1;
