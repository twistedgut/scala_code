#!/opt/xt/xt-perl/bin/perl

use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );

use NAP::policy 'tt';

use XT::JQ::DC::Receive::Upload::DoUpload;
use XTracker::Database 'xtracker_schema';
use Getopt::Long;

GetOptions( 'channel_id=s' => \(my $channel_id) );
die "no channel given\n" unless $channel_id;

my $product_channel = xtracker_schema
    ->resultset('Public::ProductChannel')
    ->search({live => 0, upload_date => undef, channel_id => $channel_id})
    ->first or die "no non-uploaded products found\n";

my $product = $product_channel->product;
print "uploading ".$product->id."\n";

my $upload = XT::JQ::DC::Receive::Upload::DoUpload->new({
    payload => {
        operator_id     =>  5009,
        channel_id      =>  $channel_id,
        upload_id       =>  1,
        due_date        =>  '2010-10-25',
        pid_count       =>  1,
        pids            =>  [ { pid => $product->id } ],
        environment     =>  'live',
    }
});

eval{
    $upload->do_the_task();
};
say $@ if $@;
