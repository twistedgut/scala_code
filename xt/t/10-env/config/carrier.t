#!/usr/bin/env perl

use NAP::policy "tt",     'test';
use FindBin::libs;


use XTracker::Constants::FromDB   qw( :channel );
use Test::XTracker::Data;
use Test::XTracker::RunCondition dc => 'DC2';

use XTracker::Config::Local qw<config_section_exists config_var>;


my @sections = qw<
    UPS_API_Integration_NAP
    UPS_API_Integration_OUTNET
>;

foreach my $section (@sections) {
    ok(
        config_section_exists($section),
        "[$section] exists"
    );
}

done_testing;
