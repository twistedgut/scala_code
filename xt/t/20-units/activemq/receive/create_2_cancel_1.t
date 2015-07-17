#!/usr/bin/env perl

=head1 TEST PLAN

REL-725

    * Request a Refund for an Order on both items
    * Check Renumerations get created correctly and split correctly
    * Cancel the largest value item
    * Check old Renumerations are now cancelled
    * Check new Renumeration created and for correct refund type

=cut

use NAP::policy "tt", 'test';
use Test::NAP::Messaging::Helpers 'napdate';

use Test::XTracker::Data;
use Test::XTracker::MessageQueue;
use Test::Config;
use Test::XT::ActiveMQ;

use XTracker::Constants::FromDB qw/
  :renumeration_type
  :renumeration_status
  :renumeration_class
/;
use XTracker::Config::Local;

my ($amq,$app) = Test::XTracker::MessageQueue->new_with_app;
my $tmp;

my $channel = Test::XTracker::Data->channel_for_business(name=>'nap');
my $pids = Test::XTracker::Data->find_or_create_products({
    how_many => 2,
    channel_id => $channel->id,
});

my ($order, $order_hash) = Test::XTracker::Data->create_db_order({
    pids => $pids,
    attrs => [
        { price => 100.00 },
        { price => 250.00 },
    ],
    base => {
        tenders => [
            { type => 'card_debit', value => 190 },
            { type => 'store_credit', value => 170 },
        ],
    },
});


# for each pid make sure there's stock
foreach my $item (@{$pids}) {
    Test::XTracker::Data->ensure_variants_stock($item->{pid});
}

#Test::XTracker::Data->ensure_stock(48498, 99);

my ($req_payload, $header) = Test::XT::ActiveMQ::rma_req_message($order,
    [
        {
            "returnReason" => "POOR_QUALITY",
            "itemReturnRequestDate" => "2009-09-01 12:52:19 +0100",
            "faultDescription" => "The zip is broken",
            "sku" => $pids->[0]->{sku},
        },
        {
            "returnReason" => "POOR_QUALITY",
            "itemReturnRequestDate" => "2009-09-01 12:52:19 +0100",
            "faultDescription" => "The zip is broken",
            "sku" => $pids->[1]->{sku},
        },
    ]
);

my $in_queue = Test::XTracker::Config->messaging_config->{'Consumer::NAPReturns'}{routes_map}{destination};

my $res = $amq->request(
    $app,
    $in_queue,
    $req_payload,
    $header,
);
ok( $res->is_success, "Result from sending to /dc?-nap-returns queue, 'return_request' action" );

my $shipment = $order->get_standard_class_shipment;
my $return = $shipment->returns->not_cancelled->first;

ok ($return, "Return was created") or die;
my $rma_number = $return->rma_number;
note 'order id   : '. $order->id;
note 'shipment id: '. $shipment->id;
note 'rma number : '. $return->rma_number;
note "return id  : ". $return->id;

# Check that the original return has 2 renumerations one for card refund
# and one for store credit and they are created correctly
cmp_ok( $return->renumerations->count, '==', 2, "Return has 2 renumerations" );
my @orig_renums = $return->renumerations->all;
cmp_ok( $orig_renums[0]->grand_total + $orig_renums[1]->grand_total, '==', 100 + 250,
            "Renumeration total for both equals total item value" );

foreach ( @orig_renums ) {
    note "Renumeration Id: ".$_->id;
    ok( $_->renumeration_type_id == $RENUMERATION_TYPE__CARD_REFUND
        || $_->renumeration_type_id == $RENUMERATION_TYPE__STORE_CREDIT, "Renumeration Type is either 'Card Refund' or 'Store Credit' (".$_->renumeration_type_id.")" );
    cmp_ok( $_->renumeration_status_id, '==', $RENUMERATION_STATUS__PENDING, "Renumeration Status is 'Pending'" );
    cmp_ok( $_->renumeration_class_id, '==', $RENUMERATION_CLASS__RETURN, "Renumeration Class is 'Refund'" );

    $tmp    = $_->renumeration_tenders->first;
    if ( $_->renumeration_type_id == $RENUMERATION_TYPE__CARD_REFUND ) {
        cmp_ok( $_->grand_total, '==', 190, "Renumeration: Card Refund value maximum (190)" );
        cmp_ok( $tmp->value, '==', 190, "Renumeration has a Renumeration Tender for same value" );
    }
    else {
        cmp_ok( $_->grand_total, '==', 160, "Renumeration: Store Credit value is for remaining (160)" );
        cmp_ok( $tmp->value, '==', 160, "Renumeration has a Renumeration Tender for same value" );
    }
}


# Cancel the largest value item (second SKU) which
# should mean the above 2 renumerations being cancelled
# and one new one for Card Refund being created
note "Cancel largest value item";
$res    = $amq->request(
    $app,
    $in_queue,
    Test::XT::ActiveMQ::rma_cancel_message($return,
                       [ { "sku" => $pids->[1]->{sku} } ]
                   )
);
ok( $res->is_success, "Result from sending to /dc?-nap-returns queue, 'cancel_return_items' action" );

note "Check new & old Renumerations after item Cancelled";
# check the new renumerations should only be 1
$return->discard_changes;
my @new_renum   = $return->renumerations->not_cancelled->all;
cmp_ok( @new_renum, '==', 1, "Only 1 Non Cancelled Renumeration created" );
note "Check New Renumeration, Id: " . $new_renum[0]->id;
cmp_ok( $new_renum[0]->renumeration_type_id, '==', $RENUMERATION_TYPE__CARD_REFUND,
            "New Renumeration is for 'Card Refund'" );
cmp_ok( $new_renum[0]->renumeration_status_id, '==', $RENUMERATION_STATUS__PENDING, "New Renumeration Status is 'Pending'" );
cmp_ok( $new_renum[0]->renumeration_class_id, '==', $RENUMERATION_CLASS__RETURN, "New Renumeration Class is 'Refund'" );
cmp_ok( $new_renum[0]->grand_total, '==', 100, "New Renumeration value is for 100" );
$tmp    = $new_renum[0]->renumeration_tenders->first;
cmp_ok( $tmp->value, '==', 100, "New Renumeration has a Renumeration Tender for same value" );

note "Check old Renumeration Statuses";
foreach ( @orig_renums ) {
    note "Old Renumeration Id: ".$_->id;
    $_->discard_changes;
    cmp_ok( $_->renumeration_status_id, '==', $RENUMERATION_STATUS__CANCELLED, "Old Renumeration status is 'Cancelled'" );
    $tmp    = $_->renumeration_status_logs->search( {}, { order_by => 'me.id DESC' } )->first;
    cmp_ok( $tmp->renumeration_status_id, '==', $RENUMERATION_STATUS__CANCELLED, "Old Renumeration Cancel status is Logged" );
    cmp_ok( $_->renumeration_tenders->count, '==', 0, "Old Renumeration has ZERO Renumeration Tenders" );
}


done_testing;

