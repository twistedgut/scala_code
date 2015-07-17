#!/opt/xt/xt-perl/bin/perl -w

use strict;
use warnings;
use lib "/opt/xt/deploy/xtracker/lib";
use FindBin::libs qw( base=lib_dynamic );

use XTracker::EmailFunctions;

my $to        = "Finance_VAT_Report\@net-a-porter.com";
my $from      = "xtracker\@net-a-porter.com";
my $subject   = "Monthly EU VAT Reports";
my $message   = "Latest reports available here: http://xtracker.net-a-porter.com/export/EU_VAT_REPORTS.zip";

send_email( $from, $from, $to, $subject, $message, "text");
