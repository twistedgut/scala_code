#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use Test::XT::Data;
use Test::More::Prefix qw/test_prefix/;
use Test::XTracker::Data;
use Test::XTracker::MessageQueue;
use XTracker::Config::Local 'config_var','iws_location_name';
#use Test::XTracker::Artifacts::RAVNI;
use XTracker::Constants::FromDB qw/
  :flow_status
  :stock_action
/;
use Test::XTracker::RunCondition
    iws_phase => 'iws', export => [qw/$iws_rollout_phase/];

my ($amq,$app) = Test::XTracker::MessageQueue->new_with_app;
my $messaging_config = Test::XTracker::Config->messaging_config;
my $schema = Test::XTracker::Data->get_schema;
my $framework   = Test::XT::Data->new_with_traits(
    traits => [
        'Test::XT::Data::Location',
    ]
);
my $q_rs = $schema->resultset('Public::Quantity');
my $s_rs = $schema->resultset('Flow::Status');
my $l_rs = $schema->resultset('Public::LogStock');

my $invar_location = $framework->data__location__get_invar_location;

my $prods = Test::XTracker::Data->find_or_create_products({
    how_many => 5,
    dont_ensure_stock => 1,
});
my $channel = $prods->[0]{product}->get_product_channel->channel;

$q_rs->search({ location_id => $invar_location->id })->delete;

for my $p (@$prods[0..2]) {
    $q_rs->create({
        location_id => $invar_location->id,
        variant_id => $p->{variant_id},
        quantity => 10,
        channel_id => $channel->id,
        status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
    });
}

$q_rs->create({
    location_id => $invar_location->id,
    variant_id => $prods->[3]->{variant_id},
    quantity => 10,
    channel_id => $channel->id,
    status_id => $FLOW_STATUS__SAMPLE__STOCK_STATUS,
});

for my $p (@$prods) {
    $p->{total_q}=$p->{variant}->current_stock_on_channel($channel->id);
}

# we now have 5 products, 3 of which have main stock, 1 sample stock,
# 1 no stock

sub send_adjustment {
    my ($sku,$quant,$status_id,$reason)=@_;

    $status_id ||= $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS;
    $reason ||= 'testing';

    my $payload = {
        '@type' => 'inventory_adjust',
        version => '1.0',
        sku => $sku,
        quantity_change => $quant,
        reason => $reason,
        stock_status => $s_rs->find($status_id)->iws_name(),
    };
    my $header = {
        type => 'inventory_adjust',
    };

    my $res=$amq->request(
        $app,
        $messaging_config->{'Consumer::XTWMS'}{routes_map}{destination}[0],
        $payload,$header,
    );
    return $res;
}

sub quant {
    my ($vid,$status_id) = @_;

    $status_id ||= $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS;

    return
        $q_rs->search({
            location_id => $invar_location->id,
            variant_id => $vid,
            status_id => $status_id,
        })->get_column('quantity')->sum() || 0;
}

sub check_log {
    my ($vid,$quant,$reason)=@_;

    $reason ||= 'testing';

    my $log_row = $l_rs->search({
        variant_id => $vid,
        stock_action_id => $STOCK_ACTION__MANUAL_ADJUSTMENT,
    },{
        order_by => { -desc => 'date' },
    })->slice(0,0)->single;

    return unless $log_row;
    return unless $log_row->quantity == $quant;
    return unless $log_row->notes eq $reason;
    return $log_row->balance;
}

{
my $last_log_id = $l_rs->search({})->get_column('id')->max;

ok(! send_adjustment('999999999-000',-1)->is_success,
   'fail for non-existant SKU');

my $new_log_id = $l_rs->search({})->get_column('id')->max;

is($new_log_id,$last_log_id,
   'non-existant SKU not logged');
}

ok(send_adjustment($prods->[0]{sku},+1)->is_success,
   'works with correct SKU');

is(quant($prods->[0]{variant_id}), 11,
   'quantity increment');

is( check_log($prods->[0]{variant_id},+1),
    $prods->[0]{total_q}+1,
    'logged' );

ok(send_adjustment($prods->[1]{sku},-1)->is_success,
   'send decrement');

is(quant($prods->[1]{variant_id}), 9,
   'quantity decrement');

is( check_log($prods->[1]{variant_id},-1),
    $prods->[1]{total_q}-1,
    'logged' );

ok(send_adjustment($prods->[3]{sku},-1)->is_success,
   'send decrement for main');

is(quant($prods->[3]{variant_id}), -1,
   'negative main quantity');

is( check_log($prods->[3]{variant_id},-1),
    $prods->[3]{total_q}-1,
    'logged (mixed status)' );

ok(send_adjustment($prods->[3]{sku},-1,$FLOW_STATUS__SAMPLE__STOCK_STATUS)->is_success,
   'send decrement for sample');

is(quant($prods->[3]{variant_id},$FLOW_STATUS__SAMPLE__STOCK_STATUS), 9,
   'decremented sample quantity');

is( check_log($prods->[3]{variant_id},-1),
    $prods->[3]{total_q}-1,
    'logged (mixed status, samples are not counted)' );

ok(send_adjustment($prods->[4]{sku},3)->is_success,
   'create main stock');

is(quant($prods->[4]{variant_id}), 3,
   'main stock created');

is( check_log($prods->[4]{variant_id},+3),
    $prods->[4]{total_q}+3,
    'logged' );

# Send an adjustment that zeros the stock
if ( $iws_rollout_phase ) {
    test_prefix("Checking removing all quantity");
    my $vid = $prods->[0]{variant_id};
    my $kill_quantity = quant( $vid );

    my $row = $q_rs->search({
        location_id => $invar_location->id,
        variant_id  => $vid,
        status_id   => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
    })->first;

    ok( $row, "Before setting stock to zero, we can find the row" );
    ok( send_adjustment($prods->[0]{sku}, -$kill_quantity)->is_success,
        'InvAdjust sent with quantity of -' . $kill_quantity );

    is( quant($vid), 0, "Quantity has been set to 0" );

}

done_testing();
