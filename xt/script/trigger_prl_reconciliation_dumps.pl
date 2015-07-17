#!/opt/xt/xt-perl/bin/perl
use strict;
use warnings;

use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use Getopt::Long;
use XTracker::Script::Product::TriggerPRLReconciliationDumps;


my %opt;

my $result = GetOptions(
    \%opt,
    'verbose|v',
    'dryrun|d',
    'help|h|?',
);

pod2usage(1) if (!$result || $opt{help});

XTracker::Script::Product::TriggerPRLReconciliationDumps->new->invoke(%opt);
