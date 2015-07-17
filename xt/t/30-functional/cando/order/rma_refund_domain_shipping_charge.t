#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use Data::Dump qw/pp/;
use Test::Differences qw/eq_or_diff/;

use Test::XTracker::Data;
use Test::XTracker::Mechanize;
use XTracker::Constants::FromDB qw/
    :stock_process_status
    :renumeration_type
    :customer_issue_type
/;
use XTracker::Config::Local;
use XT::Domain::Returns;

use Test::XTracker::MessageQueue;

my ($channel,$pids) = Test::XTracker::Data->grab_products({
    how_many => 2,
});
my @skus = map { $_->{sku} } @$pids;

my $order_orig = {
    shipping_charge => '19.57',
    items => {
        $skus[0] => { price => 100.00, tax => '10.00', duty => '5.00' },
        $skus[1] => { price => 250.00, tax => '20.00', duty => '2.00' },
    }
};

my $app = app_produce_return($order_orig);
my $csm = consumer_product_return($order_orig);
note pp($csm);
is($app->{shipping}, '0.000', 'app shipping is zero for nap');
is($csm->{shipping}, '0.000', 'csm shipping is zero for nap');

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
        $rec->{sku} = $item->shipment_item->variant->sku;

        push @{$ret->{items}}, $rec;
    }

    return $ret;
}

sub app_produce_return {
    my($order_hash) = @_;
    # Create a dispatched order.
    my $order = Test::XTracker::Data->create_db_order( $order_hash );

    my $order_nr = $order->order_nr;
    ok(my $shipment = $order->shipments->first, "Sanity check: the order has a shipment");

    note "Order Nr: $order_nr" if $ENV{HARNESS_VERBOSE} || $ENV{HARNESS_IS_VERBOSE};


    Test::XTracker::Data->grant_permissions('it.god', 'Customer Care', 'Order Search', 2);
    Test::XTracker::Data->grant_permissions('it.god', 'Goods In', 'Returns In', 1);
    Test::XTracker::Data->grant_permissions('it.god', 'Goods In', 'Returns QC', 1);
    Test::XTracker::Data->grant_permissions('it.god', 'Goods In', 'Putaway', 1);
    Test::XTracker::Data->set_department('it.god', 'Customer Care');

    my $mech = Test::XTracker::Mechanize->new;
    $mech->do_login;


    my $return;

    $mech->order_nr($order_nr);

    $mech->test_create_rma($shipment);

    $return = $shipment->returns->first;

    note " return_id ". $return->id;
    return build_renumeration($return->renumerations->first);
}

sub consumer_product_return {
    my($order_hash) = @_;
    my $schema = Test::XTracker::Data->get_schema;
    my $domain = XT::Domain::Returns->new(
        schema => $schema,
        msg_factory => Test::XTracker::MessageQueue->new({schema => $schema}),
    );
    my ($order, $si) = make_order( $order_hash );


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

    $return->discard_changes;
    note " return_id ". $return->id;


    return build_renumeration($return->renumerations->first);
}

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

    my $si = $shipment->shipment_items->order_by_sku->first;

    return ($order, $si);
}

