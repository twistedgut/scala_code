#!/opt/xt/xt-perl/bin/perl -w

use strict;
use warnings;
use Net::FTP;

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
my $ftp = Net::FTP->new("uploads.google.com") || print "Cant Connect: $@\n";
$ftp->login("jbovard", "nap2005") || print "Cant log in: $!\n";
$ftp->put("/opt/xt/deploy/xtracker/script/data_transfer/affiliate_feeds/output/nap_test.txt") || print "Cant upload file: $!\n";
$ftp->put("/opt/xt/deploy/xtracker/script/data_transfer/affiliate_feeds/output/net_a_porter_gb.txt") || print "Cant upload file: $!\n";
$ftp->quit();

print "Froogle done...\n";
