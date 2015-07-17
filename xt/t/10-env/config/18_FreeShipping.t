#!/usr/bin/env perl

use NAP::policy "tt", 'test';

use Test::XTracker::LoadTestConfig;

use XTracker::Config::Local;
use XTracker::Database qw( read_handle );
use XTracker::Database::Currency;

my $dbh = read_handle();

my $amt = config_var('FreeShipping', 'threshold');
my $ccy = config_var('FreeShipping', 'currency');

SKIP: {

    skip("FreeShipping section not present, no free shipping tests needed", 2)
        unless config_section_exists('FreeShipping');

    like($amt, qr/^[0-9]+$/, "[FreeShipping]/threshold is numeric");
    ok(_is_valid_currency($dbh, $ccy), "[FreeShipping]/currency is a valid currency");
}

sub _is_valid_currency {
    my ($dbh, $ccy) = @_;

    eval {
        get_currency_id($dbh, $ccy);
    };

    if ($@) {
        return 0;
    } else {
        return 1;
    }
}

done_testing;
