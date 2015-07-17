package XT::DC::Controller::Metrics;

use NAP::policy "tt", 'class';
use XTracker::Metrics::Recorder;
use Template;
use XTracker::Logfile 'xt_logger';

BEGIN { extends 'Catalyst::Controller' };

=head1 NAME

XT::DC::Controller::Metrics - Serve up XTracker metrics

=head1 DESCRIPTION

Adds the URLS

    /metrics  serving up metrics data in json format

=head1 METHODS

=head2 metrics

Serve up /metrics page with collected metrics in JSON format

=cut

sub metrics :Chained('/') {
    my ($self, $c) = @_;

    my $mr = XTracker::Metrics::Recorder->new();
    my $metrics = $mr->fetch_metrics();

    my $json = JSON::XS->new->utf8->pretty(1)->canonical(1);
    my $json_metrics = $json->encode($metrics);

    $c->res->content_type('application/json');
    $c->response->body($json_metrics);
}

