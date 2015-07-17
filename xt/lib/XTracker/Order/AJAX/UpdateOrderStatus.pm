package XTracker::Order::AJAX::UpdateOrderStatus;

use NAP::policy "tt", 'class';

use XTracker::Order::Actions::ChangeOrderStatus;

use XTracker::Constants::FromDB         qw( :order_status );
use XTracker::Constants::Ajax           qw( :ajax_messages );
use XTracker::Logfile                   qw( xt_logger );
use Plack::App::FakeApache1::Constants  qw( :common );
use JSON;

=head1 METHODS

=head2 handler

Provides an AJAX wrapper around the action

=cut

my $logger = xt_logger(__PACKAGE__);

sub handler {
    my $r       = shift;
    my $handler = XTracker::Handler->new($r);

    try {
        my $order_rs = $handler->schema->resultset('Public::Orders')->find($handler->{param_of}{order_id});

        unless ($order_rs->order_status_id == $handler->{param_of}{order_status_id}) {
            $logger->debug('New status. Callnig ChangeOrderStatus action');
            XTracker::Order::Actions::ChangeOrderStatus::handler($r);
        }

        $r->print(encode_json({
            ok => 1
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
