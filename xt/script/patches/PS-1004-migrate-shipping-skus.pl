#!perl
use NAP::policy "tt";
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Script::Shipping::Migrate;
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

XTracker::Script::Shipping::Migrate->new->invoke(\%opt);

=head1 NAME

script/patches/PS-1004-migrate-shipping-skus.pl

=head1 DESCRIPTION

Migrates shipping SKUs from the website to the C<shipping.description> table.

=head1 SYNOPSIS

  perl script/patches/PS-1004-migrate-shipping-skus.pl -v # verbose
  perl script/patches/PS-1004-migrate-shipping-skus.pl -d # dry-run

=cut
