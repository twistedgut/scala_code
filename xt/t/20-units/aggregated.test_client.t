#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

=head1 NAME

aggregated.test_client.t

=head1 DESCRIPTION

Runs the aggregated Test Client tests:

    t_aggregate/test_client

=cut

use Test::Aggregate::Nested;
use Test::XTracker::LoadTestConfig;     # preloading

my $aggregate_test_dir = 't_aggregate/test_client';

# run the tests
my $tests = Test::Aggregate::Nested->new( {
    dirs => $aggregate_test_dir
} );

$tests->run;
