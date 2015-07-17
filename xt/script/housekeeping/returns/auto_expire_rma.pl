#!/opt/xt/xt-perl/bin/perl

use strict;
use warnings;
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );

=head1 NAME

script/housekeeping/returns/auto_expire_rma.pl

=head1 DESCRIPTION

CANDO-109 : This Script Automatically removes RMA older than X days ( <config.auto_expire_returns_days>/<confi.auto_expire_exchange_days> ).

This uses the 'AutoExpieRMA' category in the 'conf/log4perl.conf' file as its Log.

=head1 SYNOPSIS

  perl script/housekeeping/returns/auto_expire_rma.pl

    --dryrun
        Will not Update any Records in the Database. Use in conjunction with turning on DEBUG mode in the Log4Perl config
        to get more detailed information on what would happen.

=cut

use XTracker::Script::Returns::AutoExpireRMA;

use Getopt::Long;
use Pod::Usage;
BEGIN {
    $ENV{NO_AMQ_WARNINGS} = 1;
}

my %opt = (
    verbose => 0,
);

my $result = GetOptions( \%opt,
    'dryrun|d',
    'help|h|?',
);

pod2usage(1) if (!$result || $opt{help});

XTracker::Script::Returns::AutoExpireRMA->new->invoke(%opt);

