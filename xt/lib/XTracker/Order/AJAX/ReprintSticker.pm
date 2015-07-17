package XTracker::Order::AJAX::ReprintSticker;

use strict;
use warnings;

use Plack::App::FakeApache1::Constants qw(:common);
use JSON;

use XTracker::Database qw( :common );
use XTracker::Handler;

# Handler for AJAX updates of the order sticker information
#
sub handler {
    my $r       = shift;
    my $handler = XTracker::Handler->new($r);

    my $data;
    $data->{status}     = 'FAILURE';        # Count on failure
    $data->{message}    = '';

    # Get the order number
    my $order_id        = $handler->{param_of}{order_id};

    # action & order defined
    if ( $order_id ) {
        # get schema
        my $schema = $handler->{schema};

        eval {
                my $order = $schema->resultset('Public::Orders')->find($order_id);
                my $shipment = $order->shipments->first;

                # STICKERS!
                if(
                    $shipment->stickers_enabled &&
                    $handler->{param_of}{packing_printer}
                ){
                    my $prefs = $handler->{schema}->resultset('Public::OperatorPreference')->update_or_create({
                        operator_id                => $handler->operator_id(),
                        packing_printer            => $handler->{param_of}{packing_printer},
                    });
                    $shipment->print_sticker($prefs->packing_printer());
                }
        };

        if ($@) {
            $data->{message}    = $@;
        }else{
            $data->{status}     = 'SUCCESS';
            $data->{message}    = "Reprint submitted to printer";
        }
    }
    else {
        $data->{message}    = 'No order_id provided';
    }

    my $json = encode_json( $data );
    $handler->{request}->content_type('text/json');
    $handler->{request}->print($json);
    return OK;
}

1;
