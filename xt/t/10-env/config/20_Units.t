#!/usr/bin/env perl
use NAP::policy "tt", 'test';
use FindBin::libs;

use XTracker::Config::Local;


ok(defined(config_var('Units', 'weight')), '[Units]/weight is defined');

done_testing;
