#!/usr/bin/env perl

use NAP::policy "tt", 'test';

#
# Aggregated tests for all XT::Central::Schema subclasses.
##
use Test::Aggregate::Nested;
use FindBin::libs;
use Test::DBIx::Class::Schema;
use Test::XTracker::Data;    # preloading
use XTracker::Config::Local; # preloading

my $aggregate_test_dir = q{t_aggregate/schema};

# run the tests
my $tests = Test::Aggregate::Nested->new( {
    dirs => $aggregate_test_dir
});

$tests->run;
