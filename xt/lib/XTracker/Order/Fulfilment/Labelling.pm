package XTracker::Order::Fulfilment::Labelling;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Config::Local qw( config_var );
use XTracker::Config::Local qw( get_shipping_printers get_premier_printers );
use XTracker::Database::Address;
use XTracker::Database::Shipment;
use XTracker::Error         qw( xt_warn );

sub handler {
    my $handler = XTracker::Handler->new(shift);

    $handler->{data}{content}       = 'ordertracker/fulfilment/labelling.tt';
    $handler->{data}{section}       = 'Fulfilment';
    $handler->{data}{subsection}    = 'Labelling';

    # This screen makes no sense other than from DC1
    if (!config_var('Fulfilment', 'labelling_subsection')) {
        my $dc_name = config_var('DistributionCentre', 'name');
        xt_warn(sprintf("The %s subsection in %s is only used in DC1 and not necessary in %s.",
                        $handler->{data}{subsection},
                        $handler->{data}{section},
                        $dc_name
                    ));
        return $handler->redirect_to( "/Home" );
    }

    $handler->{data}{shipping_printers} = get_shipping_printers( $handler->{schema} );
    $handler->{data}{premier_printers} = get_premier_printers( $handler->{schema} );

    $handler->{data}{shipment_id}       = $handler->{request}->param('shipment_id');
    $handler->{data}{label_printer}     = $handler->{request}->param('label_printer')    || $handler->{data}{shipping_printers}->{label}->[0]->{name}    || '';
    $handler->{data}{document_printer}  = $handler->{request}->param('document_printer') || $handler->{data}{shipping_printers}->{document}->[0]->{name} || '';
    $handler->{data}{card_printer}      = $handler->{request}->param('card_printer')    || $handler->{data}{premier_printers}->{address_card}->[0]->{name}    || '';
    $handler->{data}{premier_printer}   = $handler->{request}->param('premier_printer') || $handler->{data}{premier_printers}->{document}->[0]->{name} || '';

    # get shipment data if id set in URL
    if ( $handler->{data}{shipment_id} ){
        my $shipment = $handler->{schema}->resultset('Public::Shipment')->find( $handler->{data}{shipment_id} );

        $handler->{data}{shipment}      = get_shipment_info( $handler->{dbh}, $handler->{data}{shipment_id} );
        # HACK - borrow $shipment->list_class and stick it straight in the hash
        # until we convert this all to use DBIC properly :(
        $handler->{data}{shipment}{list_class} = $shipment->list_class if $shipment;
        $handler->{data}{shipment_item} = get_shipment_item_info( $handler->{dbh}, $handler->{data}{shipment_id} );
        $handler->{data}{boxes}         = get_shipment_boxes( $handler->{dbh}, $handler->{data}{shipment_id} );
        $handler->{data}{ship_address}  = get_address_info( $handler->{dbh}, $handler->{data}{shipment}{shipment_address_id} );
        $handler->{data}{display_no_return_awb} = $shipment->display_shipping_input_warning if $shipment;
    }

    return $handler->process_template( undef );
}

1;
