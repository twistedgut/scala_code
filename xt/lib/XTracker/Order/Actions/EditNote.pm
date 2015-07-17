package XTracker::Order::Actions::EditNote;

use strict;
use warnings;
use XTracker::Handler;
use XTracker::Utilities qw( parse_url );
use XTracker::Database::Note qw( update_note delete_note );

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r );

    # get section info from url
    my ($section, $subsection, $short_url) = parse_url($r);

    # get data from query string
    my $note_category   = $handler->{request}->param('note_category');
    my $action          = $handler->{request}->param('action');
    my $parent_id       = $handler->{request}->param('parent_id');
    my $note_id         = $handler->{request}->param('note_id');
    my $note_text       = $handler->{request}->param('note_text');
    my $type_id         = $handler->{request}->param('type_id');
    my $shipment_id     = $handler->{request}->param('shipment_id');
    my $came_from       = $handler->{request}->param('came_from');

    if ( $note_category && $note_id ) {
        my $schema = $handler->schema;
        my $dbh = $schema->storage->dbh;
        my $guard = $schema->txn_scope_guard;
        if ($action eq 'Update'){
            update_note(
                $dbh,
                {
                    'note_category' => $note_category,
                    'note_id'       => $note_id,
                    'note'          => $note_text,
                    'type_id'       => $type_id
                }
            );
        }
        elsif ($action eq 'Delete') {
            delete_note(
                $dbh,
                {
                    'note_category' => $note_category,
                    'note_id'       => $note_id
                }
            );
        }
        $guard->commit;
    }

    # where to redirect to
    if ( $came_from && $came_from eq 'packing_exception' ) {
        return $handler->redirect_to(
            "/Fulfilment/Packing/CheckShipmentException?shipment_id=" .
            $shipment_id
        );
    } elsif ($note_category eq "Customer"){
        return $handler->redirect_to( "$short_url/CustomerView?customer_id=$parent_id" );
    } elsif ($note_category eq "PreOrder"){
        return $handler->redirect_to( "$short_url/PreOrder/Summary?pre_order_id=$parent_id" );
    }
    else {
        return $handler->redirect_to( "$short_url/OrderView?order_id=$parent_id" );
    }
}

1;
