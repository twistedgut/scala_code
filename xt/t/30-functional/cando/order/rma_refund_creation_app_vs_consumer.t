#!/usr/bin/env perl
use NAP::policy "tt", 'test';
use Test::NAP::Messaging::Helpers 'atleast','napdate';

use Data::Dump qw/pp/;
use Test::Differences qw/eq_or_diff/;
use Test::XTracker::MessageQueue;
use Test::XTracker::Data;
use Test::XTracker::Mechanize;
use XTracker::Constants::FromDB qw/
    :stock_process_status
    :renumeration_type
    :customer_issue_type
/;
use XTracker::Config::Local;
use XT::Domain::Returns;

use Test::XTracker::RunCondition export => ['$distribution_centre'];

my ($channel,$pids) = Test::XTracker::Data->grab_products({
    how_many => 2,
});


my $attrs = [
    { price => 100.00, tax => '10.00', duty => '5.00' },
    { price => 100.00, tax => '10.00', duty => '5.00' },
];

my $mech = Test::XTracker::Mechanize->new;
my $queue = $mech->nap_order_update_queue_name();

my $app = app_produce_return($pids,$attrs);
my $csm = consumer_product_return($pids,$attrs);

eq_or_diff($csm,$app,'renumeration same');

done_testing;

sub build_renumeration {
    my($renum) = @_;

    my $items = $renum->renumeration_items;
    my $ret = { $renum->get_columns };

    # we don't care about these fields
    delete $ret->{alt_customer_nr};
    delete $ret->{invoice};
    delete $ret->{id};
    delete $ret->{shipment_id};
    delete $ret->{invoice_nr};
    delete $ret->{last_updated};

    while ( my $item = $items->next ) {
        my $rec = { $item->get_columns };

        # we don't care about these fields
        delete $rec->{id};
        delete $rec->{renumeration_id};
        delete $rec->{shipment_item_id};
        delete $rec->{last_updated};

        push @{$ret->{items}}, $rec;
    }

    return $ret;
}

sub app_produce_return {
    my($pids,$attrs) = @_;
#$order_hash) = @_;
    # Create a dispatched order.
    my($order,$order_hash) = Test::XTracker::Data->create_db_order({
        pids => $pids,
        attrs => $attrs,
    });

    my $order_nr = $order->order_nr;
    ok(my $shipment = $order->shipments->first, "Sanity check: the order has a shipment");

    note "Order Nr: $order_nr" if $ENV{HARNESS_VERBOSE} || $ENV{HARNESS_IS_VERBOSE};


    Test::XTracker::Data->grant_permissions('it.god', 'Customer Care', 'Order Search', 2);
    Test::XTracker::Data->grant_permissions('it.god', 'Goods In', 'Returns In', 1);
    Test::XTracker::Data->grant_permissions('it.god', 'Goods In', 'Returns QC', 1);
    Test::XTracker::Data->grant_permissions('it.god', 'Goods In', 'Putaway', 1);
    Test::XTracker::Data->set_department('it.god', 'Customer Care');

    $mech->do_login;

    my $return;

    $mech->order_nr($order_nr);

    $mech->test_create_rma($shipment);

    $return = $shipment->returns->first;

    note " return_id ". $return->id;
    return build_renumeration($return->renumerations->first);
}

sub consumer_product_return {
    my($pids,$attrs) = @_;
#$order_hash) = @_;
    my $schema = Test::XTracker::Data->get_schema;
    my $amq = Test::XTracker::MessageQueue->new({schema=>$schema});
    my $domain = XT::Domain::Returns->new(
        schema => $schema,
        msg_factory => $amq,
    );
    my ($order, $si) = make_order( $pids,$attrs );

    $amq->clear_destination($queue);

    my $return = $domain->create({
      operator_id => 1,
      shipment_id => $si->shipment_id,
      pickup => 0,
      refund_type_id => $RENUMERATION_TYPE__CARD_REFUND,
      return_items => {
         $si->id => {
          type => 'Return',
          reason_id => $CUSTOMER_ISSUE_TYPE__7__TOO_SMALL,
        }
      }
    });
    $return->discard_changes;

    is(my $ex = $return->exchange_shipment, undef, "return has no exchange shipment");

    my $shipment = $si->shipment;
    my @items = $shipment->shipment_items->order_by_sku;

    $amq->assert_messages({
        destination => $queue,
        filter_header => superhashof({
            type => 'OrderMessage',
        }),
        filter_body => superhashof({
            '@type' => 'order',
            orderNumber => $order->order_nr,
            orderItems => bag(
                all(superhashof({
                    returnable => "Y",
                    sku => $pids->[1]->{variant}->sku,
                    status => "Dispatched",
                }),code(sub{!exists $_->{returnCreationDate}})),
                superhashof({
                    returnCreationDate => napdate($return->return_items->first->creation_date),
                    returnReason => "SIZE_TOO_SMALL",
                    returnable => "Y",
                    sku => $pids->[0]->{variant}->sku,
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
        assert_count => atleast(1),
    }, 'order status sent on AMQ');

    $return->discard_changes;
    note " return_id ". $return->id;


    return build_renumeration($return->renumerations->first);
}

sub make_order {
    my ($pids,$attrs) = @_;
#$data) = @_;

#    $data ||= {};

#    $data = Catalyst::Utils::merge_hashes(
#      {
#        items => {
#          '48499-097' => { price => 100.00 },
#          '48498-098' => { price => 250.00 },
#        }
#      },
#      $data
#    );


    my($order,$order_hash) = Test::XTracker::Data->create_db_order({
        pids => $pids,
        attrs => $attrs,
    });
# $data );

    my $shipment = $order->shipments->first;

    my $si = $shipment->shipment_items->search({},{order_by=>'id'})->first;

    return ($order, $si);
}

