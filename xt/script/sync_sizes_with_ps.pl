#!/usr/bin/env perl
## no critic(ProhibitExcessMainComplexity,ProhibitUselessNoCritic)
use NAP::policy "tt";
use XTracker::Config::Local;
use XTracker::Database qw/schema_handle/;
use XTracker::Role::WithAMQMessageFactory;
require XTracker::WebContent::StockManagement::Broadcast;
use Getopt::Long
    qw(:config no_auto_abbrev no_getopt_compat no_gnu_compat require_order no_ignore_case);
use Time::HiRes 'sleep';
use Pod::Usage;

my %opt = (
    verbose => 1,
    'send-stock' => 1,
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
    'send-stock|s!',
    'help|h|?',
);

pod2usage(1) if (!$result || $opt{help});

my $schema = schema_handle();

my $factory = XTracker::Role::WithAMQMessageFactory->build_msg_factory;

my @lc;my @joins;
if ($opt{'if-live'} or $opt{'if-staging'} or $opt{'if-visible'}) {
    @joins = (join => 'product_channel');
    if ($opt{'if-live'}) {
        push @lc,('product_channel.live'=>1);
    }
    if ($opt{'if-staging'}) {
        push @lc,('product_channel.staging'=>1);
    }
    if ($opt{'if-visible'}) {
        push @lc,('product_channel.visible'=>1);
    }
}

my $prod_criteria = {@lc};my $vouch_criteria = {};

if ($opt{'min-pid'} && !$opt{'max-pid'}) {
    $prod_criteria->{'me.id'}=
        $vouch_criteria->{'me.id'}=
            { '>=', $opt{'min-pid'}};
}
elsif ($opt{'max-pid'} && !$opt{'min-pid'}) {
    $prod_criteria->{'me.id'}=
        $vouch_criteria->{'me.id'}=
            { '<=', $opt{'max-pid'}};
}
elsif ($opt{'min-pid'} && $opt{'max-pid'}) {
    $prod_criteria->{'me.id'}=
        $vouch_criteria->{'me.id'}=
            { '-between',
              [ $opt{'min-pid'},$opt{'max-pid'} ],
          };
}
if ($opt{pid}) {
    $prod_criteria=[$prod_criteria,{ 'me.id' => { '-in', $opt{pid}}}];
    $vouch_criteria=[$vouch_criteria,{ 'me.id' => { '-in', $opt{pid}}}];
}

my $prodset = $schema->resultset('Public::Product')
    ->search($prod_criteria, {
        order_by => { -asc => 'me.id' },
        distinct => 1,
        @joins,
    });

my ($sleep_length,$sleep_every) = split /\//,($opt{throttle}//'0/100000');
$sleep_length=0 unless $sleep_length=~m{^\d+(?:.\d+)?$};
$sleep_every=100000 unless $sleep_every=~m{^\d+$};
my $count=0;

my %broadcast_for_channel;

while (my $product = $prodset->next) {
    my @channels = $product->product_channel->get_column('channel_id')->all;
    my $pid = $product->id;
    for my $chid (@channels) {
        say "sending product $pid $chid" if $opt{verbose};

        next if $opt{dryrun};

        $factory->transform_and_send(
            'XT::DC::Messaging::Producer::ProductService::Sizing', {
                product => $product,
                channel_id => $chid,
            });

        next unless $opt{'send-stock'};

        my $broadcast =
            $broadcast_for_channel{$chid} //=
                XTracker::WebContent::StockManagement::Broadcast->new({
                    schema => $schema,
                    channel_id => $chid,
                });

        $broadcast->stock_update(
            quantity_change => 0,
            product => $product,
            full_details => 1,
        );
        $broadcast->commit();
    }
    ++$count;
    if ($count>=$sleep_every) {
        $count=0;
        sleep($sleep_length);
    }
}

if ($opt{'send-stock'}) {
    my $vouchset = $schema->resultset('Voucher::Product')
        ->search($vouch_criteria, {
            order_by => { -asc => 'me.id' },
            distinct => 1,
        });

    while (my $voucher = $vouchset->next) {
        my $pid = $voucher->id;
        my $chid = $voucher->channel_id;

        say "sending voucher $pid $chid" if $opt{verbose};

        my $broadcast =
            $broadcast_for_channel{$chid} //=
                XTracker::WebContent::StockManagement::Broadcast->new({
                    schema => $schema,
                    channel_id => $chid,
                });

        $broadcast->stock_update(
            quantity_change => 0,
            product => $voucher,
            full_details => 1,
        );
        $broadcast->commit();

        ++$count;
        if ($count>=$sleep_every) {
            $count=0;
            sleep($sleep_length);
        }
    }
}

__END__

=head1 NAME

script/sync_sizes_with_ps.pl

=head1 DESCRIPTION

Loop through all the products, sending a message about their sizes to
the product service.

=head1 SYNOPSIS

  perl script/sync_sizes_with_ps.pl -v # verbose
  perl script/sync_sizes_with_ps.pl -d # dry-run

Only send a few PIDs:

  perl script/sync_sizes_with_ps.pl --pid 1234 --pid 244335

  perl script/sync_sizes_with_ps.pl --min-pid 1000 --max-pid 1999

  perl script/sync_sizes_with_ps.pl \
     --pid 12345 --pid 244335 \
     --min-pid 1000 --max-pid 1999

The latter will send 1002 products (assuming all of them exists, of course).

Send only the live / visible ones:

  perl script/sync_sizes_with_ps.pl \
     --if-live --if-visible

You can also specify a throttling value, like:

  perl script/sync_sizes_with_ps.pl --throttle 10/1000

This will send 1000 products, then sleep for 10 seconds. You can use
fractional seconds.

=cut
