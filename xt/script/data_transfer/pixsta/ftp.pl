#!/usr/bin/perl

use strict;
use warnings;

use Net::FTP;

my $base     = '/var/data/xtracker/utilities/affiliates/pixsta';
my $filename = 'netaporter_am.tar.gz';

## ftp to pixsta
my $ftp = Net::FTP->new("ftp.pixsta.com", Debug => 0) or die "Cannot connect to ftp.pixsta.com: $@";

$ftp->login("nap.ftp",'gh!3KzL*') or die "Cannot login ", $ftp->message;
$ftp->binary or die "binary mode failed ", $ftp->message;;
$ftp->put("$base/$filename") or die "get failed ", $ftp->message;
$ftp->quit;

