#!/opt/xt/xt-perl/bin/perl

use strict;
use warnings;
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );

=head1 NAME

script/housekeeping/shipment/checkSLA.pl

=head1 DESCRIPTION

CANDO-578 : This script automatically upgrades delayed breached SLA shipments from Ground to Express if the following conditions are statisfies

    * Shipment has breached SLA cutoff
    * Shipment status is Processed/ Hold
    * if on Hold then reason is Not one of these :
        * Customer on Holiday
        * Customer Request
        * Incomplete Address
        * Order placed on incorrect website
        * Prepaid Order
        * Unable to make contact to organise a delivery time
        * Acceptance of charges
    * Channel is not JC
    * Shipment is not Staff or Premier

this uses the 'CheckSLA' category in the 'conf/log4perl.conf' file as its logs


=cut

use XTracker::Script::Shipment::CheckSLA;

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

XTracker::Script::Shipment::CheckSLA->new->invoke(%opt);
