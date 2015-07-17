#!/opt/xt/xt-perl/bin/perl

use NAP::policy 'class';
use FindBin::libs 'base=lib_dynamic';
use XTracker::Script::AMQBrowser;
use Getopt::Long 'GetOptions';
use Pod::Usage 'pod2usage';

=head1 NAME

script/housekeeping/amq_checker

=head1 DESCRIPTION

Gather stats on AMQ Queues or purge them.

=head1 SYNOPSIS

  script/housekeeping/amq_checker.pl --search=<regex> [--purge] [--metric]

print a summary of stats for the DLQ:

  script/housekeeping/amq_checker.pl --search=".*dlq.*"

print a summary of stats for jimmy choo

  script/housekeeping/amq_checker.pl --search=".*/jc/.*"

delete all the messages on DLQ related queues

  script/housekeeping/amq_checker.pl --search=".*dlq.*" --purge

You must specify a --search option with --purge.

There is also a --metric option you can put in cron that
writes the output of amq_checker with no arguments into
the metrics data store.

=cut

my ($search_regex, $purge, $metric);

GetOptions(
    'search=s' => \$search_regex,
    'purge!' => \$purge,
    'metric!' => \$metric,
) || pod2usage(1);

pod2usage(2) if ($purge && !defined($search_regex));
pod2usage(3) if ($metric && (defined($search_regex) || $purge));

if ($purge) {
    XTracker::Script::AMQBrowser->new->purge_amq_queues($search_regex);
} elsif ($metric) {
    XTracker::Script::AMQBrowser->new->generate_metrics();
} else {
    XTracker::Script::AMQBrowser->new->print_amq_queue_stats($search_regex);
}

exit(0);
