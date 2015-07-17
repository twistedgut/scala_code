#!/opt/xt/xt-perl/bin/perl

use strict;
use warnings;

=head1 NAME

script/relocate_printdocs.pl

=head1 DESCRIPTION

Move all existing print documents to their correct locations under the new
print directory layout.

=head1 SYNOPSIS

  # move everything and display verbose output
  perl script/relocate_printdocs.pl -v

  # perform dry run - show what would be moved
  perl script/relocate_printdocs.pl -d -v

=cut

use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );

use Getopt::Long;
use Pod::Usage;
use XTracker::Script::PrintDocs::Relocate;

my %opt;
my $result = GetOptions( \%opt,
    'verbose|v',
    'dryrun|d',
    'help|h|?',
);

pod2usage(1) if (!$result || $opt{help});

XTracker::Script::PrintDocs::Relocate->new->invoke(%opt);
