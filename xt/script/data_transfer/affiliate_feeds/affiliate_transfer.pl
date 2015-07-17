#!/opt/xt/xt-perl/bin/perl -w

use strict;
use warnings;
use Net::FTP;
use MIME::Lite;

my $base = "/opt/xt/deploy/xtracker/script/data_transfer/affiliate_feeds";
my $output = "output";
my $logfile= "logfile.out";
my $config= "ftp_upload.conf";
my ($Second, $Minute, $Hour, $Day, $Month, $Year, $WeekDay, $DayOfYear, $IsDST) = localtime(time);

$Month++;
$Year = $Year+1900;
if ($Day < 10){ $Day = "0".$Day; }
if ($Month < 10){ $Month = "0".$Month; }

#### FROOGLE 
#my $ftp = Net::FTP->new("uploads.google.com") || print "Cant Connect: $@\n";
#$ftp->login("jbovard", "nap2005") || print "Cant log in: $!\n";
#$ftp->put("/opt/xt/deploy/xtracker/script/data_transfer/affiliate_feeds/output/nap_test.txt") || print "Cant upload file: $!\n";
#$ftp->put("/opt/xt/deploy/xtracker/script/data_transfer/affiliate_feeds/output/net_a_porter_gb.txt") || print "Cant upload file: $!\n";
#$ftp->put("/opt/xt/deploy/xtracker/script/data_transfer/affiliate_feeds/output/outnet_intl.txt") || print "Cant upload file: $!\n";
#$ftp->put("/opt/xt/deploy/xtracker/script/data_transfer/affiliate_feeds/output/outnet_am.txt") || print "Cant upload file: $!\n";
#$ftp->quit();

#_send_email();

print "Froogle done...\n";

## no critic(ProhibitBacktickOperators)
####  AFFILIATE WINDOW
`scp -P 8000 -i /usr/local/httpd/keys/napuser_xtracker /opt/xt/deploy/xtracker/script/data_transfer/affiliate_feeds/output/affiliate_feed.csv napuser\@web01-pr-dxi:/opt/www/NetAPorter/feeds`;
`scp -P 8000 -i /usr/local/httpd/keys/napuser_xtracker /opt/xt/deploy/xtracker/script/data_transfer/affiliate_feeds/output/affiliate_feed.csv napuser\@web02-pr-dxi:/opt/www/NetAPorter/feeds`;
`scp -P 8000 -i /usr/local/httpd/keys/napuser_xtracker /opt/xt/deploy/xtracker/script/data_transfer/affiliate_feeds/output/affiliate_feed.csv napuser\@web03-pr-dxi:/opt/www/NetAPorter/feeds`;
`scp -P 8000 -i /usr/local/httpd/keys/napuser_xtracker /opt/xt/deploy/xtracker/script/data_transfer/affiliate_feeds/output/affiliate_feed.csv napuser\@web04-pr-dxi:/opt/www/NetAPorter/feeds`;
print "Affiliate Window done.\n";


sub _send_email {

    my $msg = MIME::Lite->new(
            From        => 'xtracker@net-a-porter.com',
            To          => 'Sarah.Watson@net-a-porter.com',
            Subject     => 'Outnet Product Feeds',
            Type        => 'multipart/mixed',
    );

    ##attach files
    $msg->attach(
        Type        => 'text/html',
        Path        => '/opt/xt/deploy/xtracker/script/data_transfer/affiliate_feeds/output/outnet_intl.txt',
        Disposition => 'attachment',
    );

    $msg->attach(
        Type        => 'text/html',
        Path        => '/opt/xt/deploy/xtracker/script/data_transfer/affiliate_feeds/output/outnet_am.txt',
        Disposition => 'attachment',
    );

    $msg->send();

    return;
}
