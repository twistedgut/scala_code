package XTracker::Order::AJAX::BulkOrderActionLog;

use NAP::policy "tt";

use XTracker::Constants::Ajax           qw( :ajax_messages );
use XTracker::Logfile                   qw( xt_logger );

use JSON;
use Plack::App::FakeApache1::Constants  qw( :common );

use XTracker::Handler;

my $logger = xt_logger(__PACKAGE__);

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    try {
        my $bulklog_rs = $handler->schema->resultset('Public::BulkOrderActionLog')->create({
            action_id => $handler->{param_of}{action_id}
        });

        $r->print(encode_json({
            ok                       => 1,
            bulk_order_action_log_id => $bulklog_rs->id
        }));
    }
    catch {
        $logger->warn($_);
        $r->print(encode_json({
            ok     => 0,
            errmsg => $_
        }));
    };

    return OK;
}
