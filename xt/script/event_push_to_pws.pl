#!/opt/xt/xt-perl/bin/perl
use strict;
use warnings;

#
# THIS IS JUST A MOCK-UP!
# IT HAS NOT BEEN RUN OR TESTED
#

use Data::Dump qw(pp);
use FindBin;

use lib qq{$FindBin::RealBin/../lib};
use FindBin::libs qw( base=lib_dynamic );
use XT::JQ::DC;
use XTracker::Constants::FromDB qw( :department );

my $event_id = $ARGV[0] || die "usage: $0 event_id\n";
if ($event_id !~ m{\A\d+\z}) {
    die "event_id must be an integer\n";
}

# TODO CONFIRM THESE VALUES
my $funcname = q{Send::Event::ToWebsite};
my $feedback_to = {
    department_id   => $DEPARTMENT__IT,
};
my $payload  = {
    event_id => $event_id,
};

my $job = XT::JQ::DC->new({ funcname => $funcname }); # TODO
$job->set_feedback_to( $feedback_to ); # TODO
$job->set_payload( $payload ); # TODO
$job->send_job();
