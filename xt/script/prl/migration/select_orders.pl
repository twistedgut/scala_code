#!/opt/xt/xt-perl/bin/perl

use NAP::policy qw/tt/;

use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use Getopt::Long;
use Pod::Usage;

use XTracker::Script::PRL::SelectOrders;

=head1 NAME

script/prl/migration/select_orders.pl

=head1 DESCRIPTION

Perform 'selection' process over provided shipments or allocations or both.

Check that provided shipments are "selectable" and ignore ones that are not suitable for "selection".

When provided shipments have allocations in different PRLs it is
recommended to use --ps2 option so the business logic for prioritizing
of allocations is respected.

=head1 SYNOPSIS

In terminal run following command:

    script/prl/migration/select_orders.pl \
        --shipment-ids <list of shipment IDs>
            OR
        --allocation-ids <list of allocation IDs>
        [ --silent ]
        [ --dry-run ]
        [ --ps2 ]

All parameters in "[ ... ]" are optional, if they are not provided default
values are used. Please read script's output to see where results were placed.

When using --ps2 option for PickScheduler version 2 mode,
only shipment IDs are supported as script parameters.

=cut

# just to make sure user is constantly updated
local $| = 1;

my ($help, $silent, $dry_run, @shipment_ids, @allocation_ids);
my $use_pick_scheduler_v2;
my $result = GetOptions(
    "help"                => \$help,
    "silent"              => \$silent,
    "dry-run"             => \$dry_run,
    "shipment-ids=i{,}"   => \@shipment_ids,
    "allocation-ids=i{,}" => \@allocation_ids,
    "ps2"                 => \$use_pick_scheduler_v2,
);

pod2usage(-verbose => 2) if !$result || $help;

my $shipment_selector;
try {
    $shipment_selector = XTracker::Script::PRL::SelectOrders->new({
        shipment_ids          => \@shipment_ids,
        allocation_ids        => \@allocation_ids,
        use_pick_scheduler_v2 => $use_pick_scheduler_v2,
    });
} catch {
    pod2usage(
        -message => "Failed to start 'selection' with errors: $_",
    );
};

$shipment_selector->verbose(0) if $silent;
$shipment_selector->dry_run(1) if $dry_run;

try {
    $shipment_selector->invoke;
} catch {
    $shipment_selector->inform("Got following error while trying to perform selection: $_.");
};
