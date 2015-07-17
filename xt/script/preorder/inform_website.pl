#!/opt/xt/xt-perl/bin/perl

use strict;
use warnings;

=head1 NAME

inform_website.pl

=head1 SYNOPSIS

perl script/preorder/inform_website.pl [OPTIONS]

=head1 DESCRIPTION

Inform the web site of pre-ordered items that are ready to be converted to
real orders

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

use XTracker::Script::PreOrder::InformWebsite;

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

XTracker::Script::PreOrder::InformWebsite->new($runopts)->invoke();
