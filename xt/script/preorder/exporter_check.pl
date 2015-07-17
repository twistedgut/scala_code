#!/opt/xt/xt-perl/bin/perl

use strict;
use warnings;

=head1 NAME

exporter_check.pl

=head1 SYNOPSIS

perl script/preorder/exporter_check.pl [OPTIONS]

=head1 DESCRIPTION

Check PreOrderItems for missing orders.

If a PreOrderItem has been exported and has no associated Order after 1 hour then assume something went wrong with the WebApp and change the status of the PreOrder and PreOrderItem back to Complete or Part Exported.

-v, --verbose
      print lots of information about what's happening

-d, --dryrun
      print information about the script operation without executing anything
      (implies --verbose)

-h, --help
      display this help and exit

=cut

use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );

use XTracker::Script::PreOrder::ExporterCheck;

use Getopt::Long;
use Pod::Usage;

my %opt = ();

my $result = GetOptions( \%opt,
    'verbose|v',
    'dryrun|d',
    'help|h|?',
);

pod2usage(-verbose => 2) if (!$result || $opt{help});

my $verbose = !!$opt{verbose};
my $dryrun  = !!$opt{dryrun};

if($dryrun){ $verbose = 1 };

my $runopts = { verbose => $verbose,
                dryrun  => $dryrun,
              };

XTracker::Script::PreOrder::ExporterCheck->new($runopts)->invoke();
