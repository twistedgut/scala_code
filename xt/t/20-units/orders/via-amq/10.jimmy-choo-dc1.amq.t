#!/usr/bin/env perl
use NAP::policy "tt", 'test';

BEGIN {
    plan skip_all => 'JC currently untestable in this manner';
}

use Test::XTracker::RunCondition
    iws_phase=> 'all',
    dc       => 'DC1',
    database => 'all';

use Test::XT::OrderImporter;

my $destination = Test::XTracker::Config->messaging_config
    ->{'Consumer::JimmyChooOrder'}{routes_map}{destination};

Test::XT::OrderImporter->json_amq_payload_tests({
    root_dir    => "$ENV{XTDC_BASE_DIR}/t/data/order/third_party/jimmy-choo/",
    file_filter => 'jchoo-intl-???.json',
    destination => $destination,
});

done_testing;

