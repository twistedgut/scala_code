#!/opt/xt/xt-perl/bin/perl

use strict;
use warnings;
use lib qw( /opt/xt/deploy/xtracker/lib );
use FindBin::libs qw( base=lib_dynamic );
use XT::JQ::DC;
use Getopt::Long;

my $upload_id = undef;

GetOptions(
    'upload_id=i' => \$upload_id,
);

if (!$upload_id) {
    die "No upload id defined\n";
}

my $job = XT::JQ::DC->new({ funcname => 'Send::Upload::Completed' });

my %payload = (
    upload_id => $upload_id,
);

$job->set_payload( \%payload );

my $result;

eval{ $result = $job->send_job() };

if (!$@) {
        print "Result:\n";
        print "Job Id: ".$result->jobid."\n";
        foreach ( keys %$result ) {
                print "  ".$_." : ".$result->{$_}."\n";
        }
}
else {
        print "Couldn't create Job\n$@";
}
