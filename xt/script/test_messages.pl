#!/opt/xt/xt-perl/bin/perl

use strict;
use warnings;
use lib qw( /opt/xt/deploy/xtracker/lib );
use FindBin::libs qw( base=lib_dynamic );
use XT::JQ::DC;

my $job;
my $payload;
my $result;
my $messages;

$job = XT::JQ::DC->new({ funcname => 'Receive::Operator::Message' });

foreach ( 0..4 ) {
    my $count = ($_ + 1);

    $messages = [
        {
            recipient_id => 875,
            sender_id => 1,
        },
        {
            recipient_id => 1023,
            sender_id => 1,
        },
    ];

    $messages->[0]->{subject} = "Message $count";
    $messages->[0]->{body} = "body $count";
    $messages->[1]->{subject} = "Message $count";
    $messages->[1]->{body} = "body $count";

    push @{ $payload }, $messages->[0];
    push @{ $payload }, $messages->[1];
}

$job->set_payload( $payload );
$result = $job->send_job();
print "MSG Job Id: ".$result->jobid."\n";
