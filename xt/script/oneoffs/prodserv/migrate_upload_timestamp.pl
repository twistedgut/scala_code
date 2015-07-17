#!/opt/xt/xt-perl/bin/perl
use NAP::policy "tt";
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Script::Product::Migrate;
use Getopt::Long
    qw(:config no_auto_abbrev no_getopt_compat no_gnu_compat require_order no_ignore_case);
use Pod::Usage;

my %opt = (
    verbose => 0,
);

my $result = GetOptions(
    \%opt,
    'verbose|v',
    'dryrun|d',
    'min-pid=i','max-pid=i',
    'pid=i@',
    'if-live|L!','if-staging|S!',
    'if-visible|V!',
    'throttle|t=s',
    'help|h|?',
);

pod2usage(1) if (!$result || $opt{help});

XTracker::Script::Product::Migrate->new->invoke(\%opt);

=head1 NAME

script/send_all_products_to_prodserv.pl

=head1 DESCRIPTION

Loop through all the products, and send a message to migrate the data to the new version.

=head1 SYNOPSIS

  perl script/migrate_upload_timestamp.pl -v # verbose
  perl script/migrate_upload_timestamp.pl -d # dry-run

Only send a few PIDs:

  perl script/migrate_upload_timestamp.pl --pid 1234 --pid 244335

  perl script/migrate_upload_timestamp.pl --min-pid 1000 --max-pid 1999

  perl script/migrate_upload_timestamp.pl \
     --pid 12345 --pid 244335 \
     --min-pid 1000 --max-pid 1999

The latter will send 1002 products (assuming all of them exists, of course).

You can also specify a throttling value, like:

  perl script/migrate_upload_timestamp.pl --throttle 10/1000

This will send 1000 products, then sleep for 10 seconds. You can use
fractional seconds.

If a product can't be sent, the exception will be printed to STDERR.

=cut


