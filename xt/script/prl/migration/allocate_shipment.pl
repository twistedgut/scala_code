#!/opt/xt/xt-perl/bin/perl

use NAP::policy qw/tt/;

use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use Getopt::Long;
use Pod::Usage;

use XTracker::Script::PRL::AllocateShipment;

=head1 NAME

script/prl/migration/reallocate_shipment.pl

=head1 DESCRIPTION

Allocate shipments for provided shipment IDs.

If no IDs are passed - all shipments suitable for allocation are processed.

=head1 SYNOPSIS

In terminal run following command:

    script/prl/migration/reallocate_shipment.pl \
        [--shipment-ids <list of shipment IDs>] \
        [ --silent ] \
        [ --dry-run ]

All parameters in "[ ... ]" are optional, if they are not provided default
values are used.

=cut

# just to make sure user is constantly updated
local $| = 1;

my ($help, $silent, $dry_run, @shipment_ids);
my $result = GetOptions(
    "help"                => \$help,
    "silent"              => \$silent,
    "dry-run"             => \$dry_run,
    "shipment-ids=i{,}"   => \@shipment_ids,
);

pod2usage(-verbose => 2) if !$result || $help;

my $allocator;
try {
    $allocator = XTracker::Script::PRL::AllocateShipment->new({
        shipment_ids   => \@shipment_ids,
    });
} catch {
    pod2usage(
        -message => "Failed to start shipment allocation with errors: $_",
    );
};

$allocator->verbose(0) if $silent;
$allocator->dry_run(1) if $dry_run;

try {
    $allocator->invoke;
} catch {
    $allocator->inform("Got following error while trying to allocate: $_.");
};
