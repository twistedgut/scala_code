#!/opt/xt/xt-perl/bin/perl -w

use strict;
use warnings;
use Net::FTP;

my $base = "/opt/xt/deploy/xtracker/script/affiliates";
my $output = "output";
my $logfile= "logfile.out";
my $config= "ftp_upload.conf";
my ($Second, $Minute, $Hour, $Day, $Month, $Year, $WeekDay, $DayOfYear, $IsDST) = localtime(time);

$Year = $Year + 1900;
$Month = $Month + 1;
if ($Month =~ m/^\d$/) { $Month = "0$Month"; }
if ($Day =~ m/^\d$/){ $Day = "0$Day"; }

## read site, username, password, file from somewhere

open (my $FTP_CONF, '<', "$base/$config") || die "cant open conf file: $!\n";
open (my $LOG, '>', "$base/$logfile") || die "cant open logfile: $!\n";

print $LOG "$Year-$Month-$Day $Hour:$Minute\n";

while (<$FTP_CONF>) {

    chomp;
    my ($active,$site,$user,$passwd,$file) = split(/\t/,$_);

    if ($active == 1){
        # force passive - if required
        # my $ftp = Net::FTP->new("$site", Passive => 1) || print $LOG "Cant Connect: $@\n";
        my $ftp = Net::FTP->new("$site") || print $LOG "Cant Connect: $@\n";
        $ftp->login($user, $passwd) || print $LOG "Cant log in: $!\n";

        print $LOG "\nchecking files on $site...\n";
        my @files = $ftp->dir;
        foreach (@files) { print $LOG "$_\n" };

        $ftp->put("$output/$file") || print $LOG "Cant upload file: $!\n";
        print $LOG "new files uploaded:\n";

        my @files1 = $ftp->dir;
        foreach (@files1) { print $LOG "$_\n" };
        $ftp->quit();
    }
}

print $LOG "\nFTP uploads complete\n";
close($LOG);
