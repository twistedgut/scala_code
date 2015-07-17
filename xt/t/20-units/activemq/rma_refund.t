#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use Test::XTracker::Data;
use Test::XTracker::MessageQueue;

use Catalyst::Utils qw/merge_hashes/;
use Test::NAP::Messaging::Helpers 'napdate';
use XT::Domain::Returns;
use XTracker::Config::Local;
use XTracker::Constants::FromDB qw/
    :customer_issue_type
    :renumeration_type
/;

# This probably could run in DC2 but enough crap's been hard-coded in to
# it that that's not a job for right now
use Test::XTracker::RunCondition dc => 'DC1';

my $nap_channel_id = 1;
my $outnet_channel_id = 3;

my $schema = Test::XTracker::Data->get_schema;
my $amq = Test::XTracker::MessageQueue->new;

my $pids = Test::XTracker::Data->find_or_create_products({
    how_many => 2,
});
my @skus=map {$_->{sku}} @$pids;

ok(
  my $domain = XT::Domain::Returns->new(
    schema => $schema,
    msg_factory => $amq->producer,
  ),
  "Created Returns domain"
);

test_refund_RMA();
test_refund_RMA('outnet');

done_testing;


sub test_refund_RMA {
    my ($outnet) = @_;

    $amq->clear_destination();

    # Hardcoded is bad. but its better than using 0
    my %channel_ship_accnt = (
      1 => 2,
      3 => 5,
      # TODO: DC2 ones
      2 => 0,
      4 => 0,
    );

    my $channel_id = ($outnet ? $outnet_channel_id : $nap_channel_id);

    # Create a return order
    my ($order, $si) = make_order(
      { items => {
          $skus[0] => {
              price => 100.00,
              duty => '10',
          },
        },
        channel_id => $channel_id,
        shipping_account_id => $channel_ship_accnt{$channel_id},
      }
    );


    my $return = $domain->create({
      operator_id => 1,
      shipment_id => $si->shipment_id,
      pickup => 0,
      refund_type_id => $RENUMERATION_TYPE__CARD_DEBIT,
      return_items => {
         $si->id => {
          type => 'Return',
          reason_id => $CUSTOMER_ISSUE_TYPE__7__TOO_SMALL,
        }
      }
    });
    $return->discard_changes;
    note "Return Id/RMA: ".$return->id."/".$return->rma_number;

    my $refund_invoice  = $return->renumerations->first;

    is(my $ex = $return->exchange_shipment, undef, "return has no exchange shipment");

    my $shipment = $si->shipment;
    my @items = $shipment->shipment_items->order_by_sku;


    $amq->assert_messages({
        destination => ($outnet ? '/queue/outnet-intl-orders' : '/queue/nap-intl-orders'),
        filter_header => superhashof({
            type => 'OrderMessage',
        }),
        filter_body => superhashof({
            orderNumber => $order->order_nr,
        }),
        assert_body => superhashof({
            orderItems => bag(
                all(
                    superhashof({
                        returnable => "Y",
                        sku => $skus[1],
                        status => "Dispatched",
                    }),
                    code(sub{! exists shift->{returnCreationDate}}),
                ),
                superhashof({
                  returnCreationDate => napdate($return->return_items->first->creation_date),
                  returnReason => "SIZE_TOO_SMALL",
                  returnable => "Y",
                  sku => $skus[0],
                  status => "Return Pending",
                  xtLineItemId => $si->id,
                }),
            ),
            orderNumber            => $order->order_nr,
            returnCancellationDate => napdate($return->cancellation_date),
            returnCreationDate     => napdate($return->creation_date),
            returnCutoffDate       => napdate($shipment->return_cutoff_date),
            rmaNumber              => $return->rma_number,
            status                 => "Dispatched",
        }),
    }, 'order status sent on AMQ');

    $amq->clear_destination();
    my $stock_manager = $order->channel->stock_manager;
    $domain->cancel({return_id => $return->id, operator_id => 1, stock_manager => $stock_manager});

    $return->discard_changes;
    $refund_invoice->discard_changes;
    ok($return->is_cancelled, "Return is now cancelled");

    ok($refund_invoice->is_cancelled, "Refund is cancelled")
      or diag($refund_invoice->renumeration_status_id);

    $order->discard_changes;
    is($shipment->returns->not_cancelled->first,
       undef,
       "Order doesn't have RMA anymore"
      );

    # Now cancel the return, and it should go from the message.
    $amq->assert_messages({
        destination => ($outnet ? '/queue/outnet-intl-orders' : '/queue/nap-intl-orders'),
        filter_header => superhashof({
            type => 'OrderMessage',
        }),
        filter_body => superhashof({
            orderNumber => $order->order_nr,
        }),
        assert_body => all(
            superhashof({
                orderItems => bag(
                    all(
                        superhashof({
                            status => "Dispatched",
                            sku => $skus[1],
                        }),
                        code(sub{! exists shift->{returnCreationDate}}),
                    ),
                    all(
                        superhashof({
                            status => "Dispatched",
                            sku => $skus[0],
                        }),
                        code(sub{! exists shift->{returnCreationDate}}),
                    ),
                ),
                orderNumber            => $order->order_nr,
                returnCutoffDate       => napdate($shipment->return_cutoff_date),
                status                 => "Dispatched",
            }),
            code(sub{   !exists $_[0]->{returnCancellationDate}
                     && !exists $_[0]->{rmaNumber} })
        ),
    }, 'order status message correct after cancel RMA');
}


# Create an order, and return the Order object and a shipment item
sub make_order {
    my ($data) = @_;

    $data ||= {};

    $data = Catalyst::Utils::merge_hashes(
      {
        items => {
          $skus[0] => { price => 100.00 },
          $skus[1] => { price => 250.00 },
        }
      },
      $data
    );

    my $order = Test::XTracker::Data->create_db_order( $data );

    my $shipment = $order->shipments->first;

    my $si = $shipment->shipment_items->find_by_sku($skus[0]);

    note "Order Id/Nr: ".$order->id."/".$order->order_nr;
    note "Shipment Id: ".$shipment->id;

    return ($order, $si);
}

