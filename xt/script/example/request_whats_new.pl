#!perl
use strict;
use warnings;

use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use XT::JQ::DC;
use XTracker::Constants::FromDB qw( :channel );

my $job_rq = XT::JQ::DC->new({ funcname => 'Receive::Upload::WhatsNew' });
my $payload= {
    operator_id => 5009, # IT GOD
    channel_id  => $CHANNEL__NAP_AM,
    upload_id   => $ARGV[0] || 2594,
    due_date    => '2011-03-10',
    environment => 'live',
};
$job_rq->set_payload( $payload );
my $result  = $job_rq->send_job();
