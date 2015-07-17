#!/opt/xt/xt-perl/bin/perl

use DateTime;
use XTracker::Metrics::Recorder;
use NAP::policy 'tt';
use XTracker::Logfile 'xt_logger';

=head1 NAME

Uptime - A simple, example metric collector

=cut


# step 1. collect your metric.
my $output = `uptime`; ## no critic(ProhibitBacktickOperators)
chomp($output);

# step 2. store your metric.
try {

    my $mr = XTracker::Metrics::Recorder->new;


    # store_metric (metric_name, template, any_data_you_want_for_your_metric)

    $mr->store_metric(
        'uptime',               # a unique name (identifier) for your metric.

        { output => $output },  # perl hash containing your metrics results.
                                # this can be any freeform structure
    );

} catch {
    xt_logger->error("Unable to save metric data: $_");
};
