#!perl
use NAP::policy "tt";
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Script::Packaging::Migrate;
use Getopt::Long
    qw(:config no_auto_abbrev no_getopt_compat no_gnu_compat require_order no_ignore_case);
use Pod::Usage;

my %opt = (
    verbose => 0,
);

# opts parsing
my $result = GetOptions(
    \%opt,
    "verbose|v",
    "dryrun|d",
);

pod2usage(1) if (!$result || $opt{help});

XTracker::Script::Packaging::Migrate->new->invoke(\%opt);

=head1 NAME

script/patches/PS-1429-migrate-packaging-skus.pl

=head1 DESCRIPTION

Migrates packaging SKUs from the website to the C<packaging_attribute> table.

=head1 SYNOPSIS

  perl script/patches/PS-1429-migrate-packaging-skus.pl -v # verbose
  perl script/patches/PS-1429-migrate-packaging-skus.pl -d # dry-run

=cut

