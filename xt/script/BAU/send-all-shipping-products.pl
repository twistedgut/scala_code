#!perl
use NAP::policy "tt";
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Script::Shipping::SendAll;
use Getopt::Long
    qw(:config no_auto_abbrev no_getopt_compat no_gnu_compat require_order no_ignore_case);
use Pod::Usage;
use IO::Prompt;

my %opt = (
    verbose => 0,
);

# opts parsing
my $result = GetOptions(
    \%opt,
    "verbose|v",
    "dryrun|d",
    "live|l",
    "staging|s",
    "upload|u",
    "sku=s@",
);

pod2usage(1) if (!$result || $opt{help});
pod2usage(1) if (!$opt{sku} && $opt{upload});

if($opt{sku} && $opt{upload}) {
    my $continue = prompt("Have you checked that the translations are ready for these shipping products? Do you wish to continue the upload? Please respond with 'Y' or 'N': ",-yn);

    exit(1) unless $continue;
}

XTracker::Script::Shipping::SendAll->new->invoke(\%opt);

=head1 NAME

script/BAU/send-all-shipping-products.pl

=head1 DESCRIPTION

Broadcast all shipping products.

=head1 SYNOPSIS

  perl script/BAU/send-all-shipping-products.pl -v # verbose
  perl script/BAU/send-all-shipping-products.pl -d # dry-run
  perl script/BAU/send-all-shipping-products.pl -s # send to staging core only
  perl script/BAU/send-all-shipping-products.pl -l # send to live core only
  perl script/BAU/send-all-shipping-products.pl -s -l # send to live and staging

You can also specify specific SKUs to broacast

  perl script/BAU/send-all-shipping-products.pl --sku '1-1' --sku '1-2' # specifc SKU

Finally, you can "upload" a specific SKU if you want everything
to work w.r.t translations

Firstly, send the SKU to staging only

  perl script/BAU/send-all-shipping-products.pl --sku '1-1' --staging

... Wait for someone to let you know that the translation is ready and then uload

  perl script/BAU/send-all-shipping-products.pl --sku '1-1' --upload

Note that the upload option only works with one or more specified SKUs.

=cut


