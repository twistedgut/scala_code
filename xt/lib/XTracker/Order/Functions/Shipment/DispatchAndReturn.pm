package XTracker::Order::Functions::Shipment::DispatchAndReturn;

use strict;
use warnings;
use XTracker::Handler;
use XTracker::Database::Shipment;
use XTracker::Database::Order;
use XTracker::Database::Address;
use XTracker::Utilities qw( parse_url );

### Subroutine : handler                        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# tt-template  :                                  #
# tt-variables :                                  #

sub handler {

    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    # get section and sub-section out of URL
    my ($section, $subsection, $short_url) = parse_url($r);

    $handler->{data}{section}       = $section;
    $handler->{data}{subsection}    = $subsection;
    $handler->{data}{subsubsection} = 'Dispatch & Return Shipment';
    $handler->{data}{content}       = 'ordertracker/shared/dispatchandreturn.tt';
    $handler->{data}{short_url}     = $short_url;

    # get url params
    $handler->{data}{order_id}      = $handler->{param_of}{order_id};
    $handler->{data}{shipment_id}   = $handler->{param_of}{shipment_id};

    # back to order link
    $handler->{data}{sidenav} = [{ 'None' => [{ 'title' => 'Back', 'url'   => $short_url.'/OrderView?order_id='.$handler->{data}{order_id} }]} ];


    $handler->{data}{order}             = get_order_info( $handler->{dbh}, $handler->{data}{order_id} );
    $handler->{data}{sales_channel}     = $handler->{data}{order}{sales_channel};
    $handler->{data}{invoice_address}   = get_address_info( $handler->{dbh}, $handler->{data}{order}{invoice_address_id} );

    if ( $handler->{data}{shipment_id} ) {
        $handler->{data}{shipment}          = get_shipment_info( $handler->{dbh}, $handler->{data}{shipment_id} );
        $handler->{data}{shipment_items}    = get_shipment_item_info( $handler->{dbh}, $handler->{data}{shipment_id} );
        $handler->{data}{packed}            = check_shipment_packed( $handler->{dbh}, $handler->{data}{shipment_id} );
    }
    else {
        $handler->{data}{shipments} = get_order_shipment_info( $handler->{dbh}, $handler->{data}{order_id} );
    }

    return $handler->process_template( undef );
}

1;
