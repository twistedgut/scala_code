#!/usr/bin/env perl
use NAP::policy "tt", 'test';


use Test::XTracker::Data;

use Catalyst::Utils qw/merge_hashes/;

use XT::Domain::Returns;
use XTracker::Config::Local;
use XTracker::Constants::FromDB qw/
    :customer_issue_type
    :renumeration_type
/;
use Test::XTracker::MessageQueue;
# Too much hard-coded DC1 stuff here
use Test::XTracker::RunCondition dc => 'DC1';

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

test_create_subsequent_returns('nap');
test_create_subsequent_returns('outnet');

done_testing;


sub test_create_subsequent_returns {
    my ($channel_name) = @_;

    # Hardcoded is bad. but its better than using 0
    my %channel_ship_accnt = (
      1 => 2,
      3 => 5,
      # TODO: DC2 ones
      2 => 0,
      4 => 0,
    );

    my $channel_id = ($channel_name eq 'outnet' ? $outnet_channel_id : $nap_channel_id);
    my($channel,$pids) = Test::XTracker::Data->grab_products({
        how_many => 4,
        channel => $channel_name,
    });

    # set-up items
    my $items   = {
            $pids->[0]{sku} => {
                price   => 100.00,
                duty    => 10,
            },
            $pids->[1]{sku} => {
                price   => 200.00,
                duty    => 20,
            },
            $pids->[2]{sku} => {
                price   => 100.00,
            },
            $pids->[3]{sku} => {
                price   => 250.00,
            },
        };

    # Create a return order
    my ($order, $si) = make_order(
      { items => $items,
        channel_id => $channel_id,
        shipping_account_id => $channel_ship_accnt{$channel_id},
      }
    );


    note "Create first Return";
    my $return1 = $domain->create({
      operator_id => 1,
      shipment_id => $si->[0]->shipment_id,
      pickup => 0,
      refund_type_id => $RENUMERATION_TYPE__CARD_REFUND,
      return_items => {
         $si->[0]->id => {
          type => 'Return',
          reason_id => $CUSTOMER_ISSUE_TYPE__7__TOO_SMALL,
        }
      }
    });
    isa_ok( $return1, 'XTracker::Schema::Result::Public::Return', "1st Return" );
    note "1st Return Id/RMA: ".$return1->id."/".$return1->rma_number;
    my $invoice1    = $return1->renumerations->first;
    isa_ok( $invoice1, 'XTracker::Schema::Result::Public::Renumeration', "1st Return has a Renumeration" );
    cmp_ok( $invoice1->renumeration_items->first->shipment_item_id, "==", $si->[0]->id, "Renumeration Item Shipment Item Id matches First Shipment Item Id" );
    cmp_ok( $invoice1->renumeration_tenders->count(), ">", 0, "1st Renumeration has at least one Renumeration Tender" );

    note "Create second Return";
    my $return2 = $domain->create({
      operator_id => 1,
      shipment_id => $si->[1]->shipment_id,
      pickup => 0,
      refund_type_id => $RENUMERATION_TYPE__CARD_REFUND,
      return_items => {
         $si->[1]->id => {
          type => 'Return',
          reason_id => $CUSTOMER_ISSUE_TYPE__7__TOO_SMALL,
        }
      }
    });
    isa_ok( $return2, 'XTracker::Schema::Result::Public::Return', "2nd Return" );
    cmp_ok( $return2->id, '!=', $return1->id, "2nd Return Id is not the same as 1st Return Id" );
    note "2nd Return Id/RMA: ".$return2->id."/".$return2->rma_number;
    my $invoice2    = $return2->renumerations->first;
    isa_ok( $invoice2, 'XTracker::Schema::Result::Public::Renumeration', "2nd Return has a Renumeration" );
    cmp_ok( $invoice2->id, '!=', $invoice1->id, "2nd Renumeration Id is not the same as 1st Renumeration Id" );
    cmp_ok( $invoice2->renumeration_items->first->shipment_item_id, "==", $si->[1]->id, "Renumeration Item Shipment Item Id matches Second Shipment Item Id" );
    cmp_ok( $invoice2->renumeration_tenders->count(), ">", 0, "2nd Renumeration has at least one Renumeration Tender" );

    # check first return still only has one renumeration
    $return1->discard_changes;
    cmp_ok( $return1->renumerations->count(), "==", 1, "1st Refund only has ONE Renumeration" );

    # check first renumeration still only has one renumeration item
    $invoice1->discard_changes;
    cmp_ok( $invoice1->renumeration_items->count(), "==", 1, "1st Renumeration only has ONE Renumeration Item" );
}


# Create an order, and return the Order object and a shipment item
sub make_order {
    my ($data) = @_;

    $data ||= {};

    my $order = Test::XTracker::Data->create_db_order( $data );

    my $shipment = $order->shipments->first;

    my @si = $shipment->shipment_items->all;

    note "Order Id/Nr: ".$order->id."/".$order->order_nr;
    note "Shipment Id: ".$shipment->id;

    return ($order, \@si);
}
