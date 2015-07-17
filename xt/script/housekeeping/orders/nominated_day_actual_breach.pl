#!perl

use strict;
use warnings;

=head1 NAME

nominated_day_breach.pl

=head1 DESCRIPTION

Find Nominated Day shipments that are breach of their SLA and gather them
for each business and email their appropriate Customer Care email.

=head1 SYNOPSIS

  perl script/housekeeping/orders/nominated_day_breach.pl -v

=cut

use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );

use XTracker::Script::Shipment::NominatedDayActualBreach;

use Getopt::Long;
use Pod::Usage;

my %opt = (
    verbose => 0,
);

my $result = GetOptions( \%opt,
    'verbose|v',
    'dryrun|d',
    'help|h|?',
);

pod2usage(1) if (!$result || $opt{help});

XTracker::Script::Shipment::NominatedDayActualBreach->new->invoke(%opt);
