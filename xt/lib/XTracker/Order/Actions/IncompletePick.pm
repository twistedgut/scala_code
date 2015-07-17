package XTracker::Order::Actions::IncompletePick;
use strict;
use warnings;

use XTracker::Handler;
use XTracker::Utilities qw( parse_url number_in_list );
use XTracker::Constants::FromDB qw(
    :shipment_status
);
use XTracker::Config::Local qw( config_var );
use XTracker::Error;

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    my $shipment_id = $handler->{param_of}{shipment_id};
    $shipment_id =~ s{\s+}{}g;
    my $redirect_url = '/Fulfilment/Picking';

    eval {
        if ( !$shipment_id ) {
            die "No shipment_id defined";
        }

        if ( ($handler->{param_of}{view}||'') eq 'HandHeld' ) {
            $redirect_url .= '?view=HandHeld';
        }

        if ($handler->iws_rollout_phase >= 1) {
            die "Shipment $shipment_id is handled by IWS\n";
        }

        my $shipment = $handler->schema->resultset('Public::Shipment')->find($shipment_id);
        if ( not $shipment->can_be_put_on_hold ) {
            die 'Shipment not correct status to place on Hold for incomplete pick';
        }

        $handler->msg_factory->transform_and_send(
            'XT::DC::Messaging::Producer::WMS::IncompletePick',
            {
                shipment_id => $shipment_id,
                operator_id => $handler->{data}{operator_id},
            }
        );
    };

    if ($@) {
        xt_warn("An error occurred trying to put the shipment on hold: $@");
    }

    return $handler->redirect_to($redirect_url);
}

1;
