#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

use XTracker::Config::Local qw( config_var );


use_ok( 'Analysis::Schema' );

my $schema = Analysis::Schema->connect('dbi:SQLite:'.config_var('SystemPaths','xtdc_base_dir').'/queries.db');
isa_ok($schema, 'Analysis::Schema');

done_testing;
