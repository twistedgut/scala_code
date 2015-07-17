package XTracker::Order::Actions::CreateNote;

use strict;
use warnings;
use XTracker::Handler;
use XTracker::Logfile qw( xt_logger );
use XTracker::Utilities qw( parse_url );
use XTracker::Database::Note qw( create_note );
use XTracker::Constants::Ajax qw( :ajax_messages );
use Plack::App::FakeApache1::Constants qw(:common HTTP_METHOD_NOT_ALLOWED);
use XTracker::Error;
use JSON;

my $logger = xt_logger(__PACKAGE__);

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    # get section info from url
    my ($section, $subsection, $short_url) = parse_url($r);

    # get data from query string
    my $note_category    = $handler->{request}->param('note_category');
    my $sub_id           = $handler->{request}->param('sub_id');
    my $parent_id        = $handler->{request}->param('parent_id');
    my $note_text        = $handler->{request}->param('note_text');
    my $type_id          = $handler->{request}->param('type_id');
    my $shipment_id      = $handler->{request}->param('shipment_id');
    my $process_group_id = $handler->{request}->param('process_group_id');
    my $search_string    = $handler->{request}->param('search_string');
    my $came_from        = $handler->{request}->param('came_from');

    if ( $note_category && $sub_id ) {
        my $schema = $handler->schema;
        my $guard = $schema->txn_scope_guard;
        create_note( $schema->storage->dbh, {
            'note_category' => $note_category,
            'category_id'   => $sub_id,
            'note'          => $note_text,
            'type_id'       => $type_id,
            'operator_id'   => $handler->{data}{operator_id}
        });

        $guard->commit;

        $logger->debug("$note_category note created");
    }

    # stop spewing 'Use of uninitialized value $came_from in string eq at
    # /opt/xt/deploy/xtracker/lib/XTracker/Order/Actions/CreateNote.pm line
    # 59.' (as seen in splunk)
    $came_from = '' if not defined $came_from;
    # where to redirect to
    my $redirect_url
        = $came_from && $came_from eq 'packing_exception'           ? "/Fulfilment/Packing/CheckShipmentException?shipment_id=$shipment_id"
        : $came_from && $came_from eq 'returns_faulty'              ? "/GoodsIn/ReturnsFaulty?process_group_id=$process_group_id"
        : $came_from && $came_from eq 'returns_in'                  ? "/GoodsIn/ReturnsIn?search_string=$search_string"
        : $came_from && $came_from eq 'returns_qc'                  ? "/GoodsIn/ReturnsQC?delivery_id=$search_string"
        : $note_category && $note_category eq "PreOrder"            ? "/StockControl/Reservation/PreOrder/Summary?pre_order_id=$parent_id"
        : $section =~ m{^(?:Goods In|Stock Control)$} ? $short_url
        : $note_category eq "Customer"                ? "$short_url/CustomerView?customer_id=$parent_id"
        :                                               "$short_url/OrderView?order_id=$parent_id";

    # Holy mother of god! What am I doing?
    if( $came_from && $came_from eq 'PreOrder/AJAX'){
        $handler->{r}->print( encode_json({ok => 1}) );
        xt_success("Pre Order Note Created");
        return OK;
    }
    else {
        return $handler->redirect_to( $redirect_url );
    }
}

1;
