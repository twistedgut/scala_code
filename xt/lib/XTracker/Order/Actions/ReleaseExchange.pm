package XTracker::Order::Actions::ReleaseExchange;

use strict;
use warnings;
use XTracker::Handler;
use XTracker::Database::Shipment;

use XTracker::Utilities qw( parse_url );
use XTracker::Constants::FromDB qw( :shipment_status );
use XTracker::Error;

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    # get current section info
    my ($section, $subsection, $short_url) = parse_url($r);

    my $shipment_id = $handler->{param_of}{shipment_id};
    my $redirect    = $short_url.'/OrderView?order_id='.$handler->{param_of}{order_id};

    return $handler->redirect_to( $redirect ) unless $shipment_id;

    my $schema = $handler->schema;
    my $shipment = $schema->resultset('Public::Shipment')->find($shipment_id);

    unless ( $shipment ) {
        xt_warn("Could not find shipment $shipment_id");
        return $handler->redirect_to( $redirect );
    }

    unless ( $shipment->is_awaiting_return ) {
        xt_warn(sprintf
            'The shipment cannot be released in its current status (%s)',
            $shipment->shipment_status->status
        );
        return $handler->redirect_to( $redirect );
    }

    eval {
        $shipment->update_status(
            $SHIPMENT_STATUS__PROCESSING, $handler->{data}{operator_id}
        );
    };
    if ($@) {
        xt_warn("An error occurred whilst releasing the shipment:<br />$@");
    }
    else {
        xt_success("Exchange shipment released for processing");
    }

    return $handler->redirect_to( $redirect );
}

1;
