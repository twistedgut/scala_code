package XTracker::Order::Functions::Order::AddressMap;

use strict;
use warnings;

use Plack::App::FakeApache1::Constants qw(:common);
use Data::Dump qw( pp );
use XTracker::Handler;

### Subroutine : handler                        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# tt-template  :                                  #
# tt-variables :                                  #

sub handler {

    my $r       = shift;
    my $handler = XTracker::Handler->new($r);

    $handler->{data}{subsubsection} = 'Interactive Address Map';
    $handler->{data}{template_type} = 'none';
    $handler->{data}{content}       = 'shared/address_map.tt';
    $handler->{data}{addr_type}     = '';

    my $schema  = $handler->schema;

    my $invoice_addr;
    my $shipping_addr;

    CASE: {
        if ( exists $handler->{param_of}{order_id} && $handler->{param_of}{order_id} =~ m/^\d+$/ ) {

            my $order   = $schema->resultset('Public::Orders')->find( $handler->{param_of}{order_id} );
            if ( $order ) {

                $handler->{data}{addr_type} = 'invoice_address';

                $invoice_addr   = $order->invoice_address;
                my $shipment    = $order->get_standard_class_shipment;
                $shipping_addr  = $shipment->shipment_address       if ( defined $shipment );

                last CASE;
            }
        }

        if ( exists $handler->{param_of}{shipment_id} && $handler->{param_of}{shipment_id} =~ /^\d+$/ ) {

            my $shipment    = $schema->resultset('Public::Shipment')->find( $handler->{param_of}{shipment_id} );
            if ( $shipment ) {

                $handler->{data}{addr_type} = 'shipping_address';

                $shipping_addr  = $shipment->shipment_address;
                my $order       = $shipment->order;
                $invoice_addr   = $order->invoice_address           if ( defined $order );

                last CASE;
            }
        }
    };

    if ( defined $invoice_addr ) {
        $handler->{data}{invoice_address}   = $invoice_addr->comma_seperated_str;
    }
    if ( defined $shipping_addr ) {
        $handler->{data}{shipping_address}  = $shipping_addr->comma_seperated_str;
    }

    $handler->process_template( undef );

    return OK;
}


1;

__END__
