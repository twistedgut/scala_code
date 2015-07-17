#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use FindBin::libs;


use Test::XT::Flow;
use Test::XTracker::Data;
use Test::XTracker::Mechanize;

use Test::XTracker::RunCondition
    prl_phase => 0, # Returns putaway prep covered in other tests
    export => qw( $iws_rollout_phase );

use XTracker::Config::Local qw( config_var );

Test::XTracker::Data->grant_permissions('it.god', 'Customer Care', 'Order Search', 2);
Test::XTracker::Data->grant_permissions('it.god', 'Goods In', 'Returns In', 1);
Test::XTracker::Data->grant_permissions('it.god', 'Goods In', 'Returns QC', 1);
Test::XTracker::Data->grant_permissions('it.god', 'Goods In', 'Putaway', 1);
Test::XTracker::Data->set_department('it.god', 'Customer Care');

my $flow = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Data::Location',
    ],
);

my($channel,$pids) = Test::XTracker::Data->grab_products({
    avoid_one_size => 1,
    how_many_variants => 2,
});

my $mech = $flow->mech;
$mech->do_login;

# create an order and RMA
my $rma = Test::XTracker::Data->create_rma({
    items => {
        map {
            $_->sku => {}
        } ($pids->[0]{product}->get_stock_variants->all)[0..1]
    },
});

$mech->force_datalite(1);
$mech->test_bookin_rma($rma);

$mech->test_returns_qc_pass($rma);

if ($iws_rollout_phase == 0) {
    # Test behaviour when we ignore the suggested putaway location
    $mech->test_returns_putaway_phase_0($rma, {
        ignore_suggestion => 1,
        test_sku => 1,
    });

    # Book in a second return to test behaviour when we follow suggest putaway
    # location first time
    $rma = Test::XTracker::Data->create_rma({
        items => { map { $_->{sku} => {} } @$pids },
    }, $pids);

    $mech->test_bookin_rma($rma);

    $mech->test_returns_qc_pass($rma);

    $mech->test_returns_putaway_phase_0($rma);
} else {
    $mech->test_returns_putaway($rma);
}

done_testing;
