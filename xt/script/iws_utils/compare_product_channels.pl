#!perl

=pod

Find the channel that xt thinks all transferred products are now on

=cut

use strict;
use warnings;
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use Text::CSV_XS;
use XTracker::Config::Local qw( config_var config_section_slurp );
use XTracker::Constants::FromDB qw(
    :channel_transfer_status
);
use XTracker::Database qw(:common);

my $input = shift;
die "please give me a csv file to read" unless ($input);

my ( $schema, $dbh ) = get_schema_and_ro_dbh('xtracker_schema');

my $csv = Text::CSV_XS->new();

my $ok = 0;

my $iws_product_channels;

my @bad;

my $channel_sth = $dbh->prepare("select id from channel where upper(name) = ?");
my $product_channel_sth = $dbh->prepare("select get_product_channel_id(?)");

open( my $iws_fh, '<', $input ) or die "couldn't open $input";
while (my $line = <$iws_fh>) {
    if ($csv->parse($line)) {
        my ($pid, $channel_name) = $csv->fields();
        unless ($channel_name =~ /\w+/) {
            warn "skipping $pid, $channel_name";
            next;
        }
        next if ($channel_name eq 'Channel');   # looks like header
        $channel_sth->execute($channel_name);
        my ($channel_id) = $channel_sth->fetchrow_array();
        die "couldn't find channel id for $channel_name" unless ($channel_id);
        $iws_product_channels->{$pid}->{$channel_id} = 1;
    }
}
close $iws_fh;

my @transfers = $schema->resultset('Public::ChannelTransfer')->search({
    'status_id' => $CHANNEL_TRANSFER_STATUS__COMPLETE,
},
{
    order => 'me.id',
})->all;
foreach my $transfer (@transfers) {
    my $product = $transfer->product;
    my $get_product_channel_id;
    eval {
        $get_product_channel_id = $product->get_product_channel->channel_id;
    };
    unless ($get_product_channel_id) {
        warn "don't know current channel in xt for ".$product->id;
        next;
    }
    if ($iws_product_channels->{$product->id}->{$get_product_channel_id}) {
        $ok++;
    } else {
        print "ERROR: xtracker thinks ".$product->id." is on channel $get_product_channel_id, IWS has no record of it on that channel\n";
        push @bad, $product->id;
    }
}
print "finished comparing - $ok matched\n";
print @bad." bad: ".join(', ',@bad)."\n";


1;
