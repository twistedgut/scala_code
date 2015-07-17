#!/usr/bin/env perl

use NAP::policy "tt", 'test';

use FindBin::libs;

eval "use Test::NoBreakpoints 0.10 "; ## no critic(ProhibitStringyEval)
plan skip_all => "Test::NoBreakpoints 0.10 required for testing" if $@;

my @files = Test::NoBreakpoints::all_perl_files(qw[lib t/lib script]);
all_files_no_breakpoints_ok( @files );

done_testing;
