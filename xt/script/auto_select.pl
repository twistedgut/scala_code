#!/opt/xt/xt-perl/bin/perl

use strict;
use warnings;

=head1 NAME

script/auto_select.pl

=head1 DESCRIPTION

Automatically select the next batch of shipments eligible for selection.

If C<Fulfilment/auto_select_shipments> is not enabled in the XTracker config,
the script exits and does nothing.

This script changes its behaviour depending on whether we are in an application
with or without PRLs enabled.

=over

=item with PRLs

This is just a thin wrapper that makes calls to the pick scheduler.

=item without PRLs

The size of the batch is set by the C<Fulfilment/auto_select_count XTracker>
config item and defaults to 6 if not set.

The script is intended to be run under cron, probably every minute. There is
a basic lock to safeguard against running multiple instances of the script
simultaneously.

=back

=head1 SYNOPSIS

  # auto-select the next batch and display the counts available and selected.
  perl script/auto_select.pl [-v] [-d]

=over

=item --verbose, -v

Verbose mode (only applies to without PRL configurations)

=item --drydrun, -d

Rollback any changes (only applies to without PRL configurations)

=back

=cut

BEGIN { $ENV{XT_LOGCONF} = 'pick_scheduling.conf'; }

use lib 'lib';
use FindBin::libs qw( base=lib_dynamic );

use XTracker::Script::Shipment::AutoSelect;

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

XTracker::Script::Shipment::AutoSelect->new->invoke(%opt);
