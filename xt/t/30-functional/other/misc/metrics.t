#!/usr/bin/env perl

use NAP::policy 'test', 'tt';

=head1 NAME

metrics.t - Make sure /metrics serve stuff up

=head1 DESCRIPTION

The /metrics page help us identify the metrics
and integrity of an XTracker server. I hope this will become
a

#TAGS misc metric metrics important

=cut

use Test::WWW::Mechanize;
use Test::MockModule;
use Data::UUID;

# prepare mechanise style test
use Test::XT::Flow;
my $framework = Test::XT::Flow->new();
my $mech = $framework->mech;

use XTracker::Metrics::Recorder;
use JSON::XS 'decode_json';
use Sys::Hostname;


# inject testable metrics into system.
my $mr = XTracker::Metrics::Recorder->new();
my $test_id = Data::UUID->new->create_hex;

note "************************************";
note "This test's unique test_id: $test_id";
note "************************************";

$mr->store_metric(
    'mechanise',
    { 'output' => $test_id }
);

my $hostname = hostname();

# able to get /metrics (without logging in first)
$mech->get_ok('/metrics', 'XTrackers metrics url /metrics ok');

# parse json and ensure it's correct
my $json;
lives_ok { $json = decode_json($mech->content) } '/metrics returns valid json';

my $mech_data;
lives_ok { $mech_data = $json->{mechanise}->{$hostname}->{metric_data}->{output} } 'json payload in expected structure';

is($mech_data, $test_id, 'metric result data in json payload correct (test_id found)');

done_testing;
