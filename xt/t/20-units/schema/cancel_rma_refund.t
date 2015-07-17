#!/usr/bin/env perl
use NAP::policy "tt", 'test';


use Test::XTracker::Data;
use Test::XTracker::MessageQueue;

use Catalyst::Utils qw/merge_hashes/;

use XT::Domain::Returns;
use XTracker::Config::Local;
use XTracker::Constants::FromDB qw/
    :customer_issue_type
    :renumeration_type
    :renumeration_status
/;

use Test::XTracker::RunCondition dc => 'DC1'; # Too much hard-coded stuff in here

my $nap_channel_id = 1;
my $outnet_channel_id = 3;

my $schema = Test::XTracker::Data->get_schema;
my $amq = Test::XTracker::MessageQueue->new({schema=>$schema});

ok(
  my $domain = XT::Domain::Returns->new(
    schema => $schema,
    msg_factory => $amq,
  ),
  "Created Returns domain"
);

note "NET-A-PORTER";
test_cancel_RMA_refund();

note "OUTNET";
test_cancel_RMA_refund('outnet');

done_testing;


sub test_cancel_RMA_refund {
    my ($outnet) = @_;

    my $queue_name  = ($outnet ? '/queue/outnet-intl-orders' : '/queue/nap-intl-orders');

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
      {
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
    my $shipment        = $si->shipment;

    # get the relevant Renumeration Statuses
    my @renum_status    = $schema->resultset('Public::RenumerationStatus')->search(
                                                                    {
                                                                        id => { 'IN' => [
                                                                                        $RENUMERATION_STATUS__PENDING,
                                                                                        $RENUMERATION_STATUS__AWAITING_AUTHORISATION,
                                                                                        $RENUMERATION_STATUS__AWAITING_ACTION,
                                                                                    ],
                                                                              },
                                                                    },
                                                                    {
                                                                        order_by    => 'id',
                                                                    } )->all;


    # check different statuses of Renumeration
    # still result in a Cancelled Invoice
    my $stock_manager = $order->channel->stock_manager;
    foreach my $renum_status ( @renum_status ) {
        note "Testing with Renumeration Status: ".$renum_status->id." - ".$renum_status->status;
        $refund_invoice->update( { renumeration_status_id => $renum_status->id } );
        $schema->txn_do( sub {
            # just keep the AMQ Queue clear
            $amq->clear_destination( $queue_name );
            $domain->cancel({return_id => $return->id, operator_id => 1, stock_manager => $stock_manager});

            $order->discard_changes;
            $return->discard_changes;
            $refund_invoice->discard_changes;

            ok($return->is_cancelled, "Return is now cancelled");
            ok($refund_invoice->is_cancelled, "Refund is cancelled")
                    or diag( "Renumeration Status Id: ".$refund_invoice->renumeration_status_id);
            is($shipment->returns->not_cancelled->first,
                   undef,
                   "Order doesn't have RMA anymore"
            );

            $schema->txn_rollback;
        } );
    }

    $amq->clear_destination( $queue_name );
}


# Create an order, and return the Order object and a shipment item
sub make_order {
    my ($data) = @_;

    $data ||= {};

    my $pids = Test::XTracker::Data->grab_products({
        how_many => 2,
        channel_id => $data->{channel_id},
    });
    my @skus=map {$_->{sku}} @$pids;

    $data = Catalyst::Utils::merge_hashes(
      {
        items => {
          $skus[0] => { price => 100.00, duty => 10 },
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
