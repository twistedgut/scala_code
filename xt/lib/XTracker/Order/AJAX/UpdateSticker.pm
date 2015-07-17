package XTracker::Order::AJAX::UpdateSticker;

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

    # get update action from the form
    my $action = $handler->{param_of}{action};

    # Get the order number and the new sticker text
    my $order_id        = $handler->{param_of}{order_id};
    my $sticker_text    = $handler->{param_of}{sticker_text};

    # action & order defined
    if ( $action && $order_id ) {
        # get schema
        my $schema = $handler->{schema};

        eval {
            # create attribute
            if ( $action eq "update" ) {

                my $order = $schema->resultset('Public::Orders')->find($order_id);
                if ($order) {
                    $order->update({sticker => $sticker_text});
                    $data->{status}     = 'OK';
                    $data->{message}    = 'Sticker data updated';
                }
                else {
                    $data->{message}    = 'Could not find order';
                }
            }
            else {
                $data->{message}    = "Unrecognised action - $action";
            }
        };

        if ($@) {
            $data->{message}    = $@;
        }
    }
    else {
        $data->{message}    = 'No action or no order provided';
    }

    my $json = encode_json( $data );
    $handler->{request}->content_type('text/json');
    $handler->{request}->print($json);
    return OK;
}

1;
