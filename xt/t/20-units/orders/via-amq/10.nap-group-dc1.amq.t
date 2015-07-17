#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use Test::XTracker::RunCondition
    dc       => 'DC1';

use Test::XT::OrderImporter;

# the \d+\w names files are where I've modified an existing payload to have
# slightly different test data to cover a case I've not seen elsewhere and
# wanted to be sure I tested against (e.g. setting a state in the address
# - giving the same name, with a suffix means the files are more obviously
# - related

my $destination = Test::XTracker::Config->messaging_config
    ->{'Consumer::MrPorterOrder'}{routes_map}{destination};

Test::XT::OrderImporter->json_amq_payload_tests({
    root_dir    => "$ENV{XTDC_BASE_DIR}/t/data/order/napgroup",
    file_filter => 'mrp-intl-???.json',
    destination => $destination,
});

done_testing;
