package XTracker::Order::Actions::ReverseReturnItem;
use NAP::policy 'tt';

use XTracker::Handler;
use XTracker::Utilities qw( parse_url );
use XTracker::Error;
use URI;

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    # get current section info
    my ($section, $subsection, $short_url) = parse_url($r);

    my $schema = $handler->schema;
    my $return_id = $handler->{param_of}{return_id};

    # I don't really get the insistence on having order and return ids... but I
    # don't want to remove them just yet
    my $return      = $schema->resultset('Public::Return')->find($return_id);
    my $shipment_id = $return->shipment_id;
    my $order_id = $return->shipment->link_orders__shipments->first->orders_id;

    my $redirect;
    try {

        # Note that 'returnitemid' could be either an array ref or a scalar,
        # But since DBIc will cope with either appropriately we don't need
        # to worry about it :)
        my @return_items = $return->return_items()->search({
            id => $handler->{param_of}->{returnitemid},
        });

        if (@return_items < 1) {
            # No return items have been selected
            die "At least one return item must be selected\n";
        }

        $return->reverse_return({
            return_items    => \@return_items,
            operator_id     => $handler->{data}{operator_id},
        });
        xt_success('Booked in items successfully reversed.');

        $redirect = URI->new("$short_url/Returns/View");
        $redirect->query_form({
            order_id    => $order_id,
            shipment_id => $shipment_id,
            return_id   => $return_id,
        });
    } catch {
        xt_warn("An error occurred whilst reversing booked in items:<br />$_");
        $redirect = URI->new("$short_url/Returns/ReverseItem");
        $redirect->query_form({
            order_id    => $order_id,
            shipment_id => $shipment_id,
            return_id   => $return_id,
        });

    };
    return $handler->redirect_to( $redirect->as_string() );
}
