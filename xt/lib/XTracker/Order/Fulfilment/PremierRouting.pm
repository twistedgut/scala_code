package XTracker::Order::Fulfilment::PremierRouting;

use strict;
use warnings;
use XTracker::Handler;
use XTracker::Database::Routing qw( get_routing_export_list get_working_export_list get_routing_export get_routing_export_status_log get_routing_export_shipment_list get_routing_export_return_list );
use XTracker::Database::Channel    qw( get_channels );

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    $handler->{data}{section}          = 'Fulfilment';
    $handler->{data}{subsection}       = 'Premier Routing';
    $handler->{data}{content}          = 'ordertracker/fulfilment/premier_routing.tt';
    $handler->{data}{today}            = DateTime->now( time_zone => 'local' );
    $handler->{data}{tomorrow}         = DateTime->now( time_zone => 'UTC' )
                                                 ->add( days => 1 )
                                                 ->set_time_zone('local');
    $handler->{data}{select_channels}  = get_channels( $handler->{dbh} );


    # routing export ID - get list of shipments in routing export
    if ( $handler->{param_of}{routing_export_id} ){
        $handler->{data}{export_id}     = $handler->{param_of}{routing_export_id};
        $handler->{data}{view}          = 'shipment';
        $handler->{data}{export}        = get_routing_export( $handler->{dbh}, $handler->{data}{export_id} );
        $handler->{data}{log}           = get_routing_export_status_log( $handler->{dbh}, $handler->{data}{export_id} );
        $handler->{data}{shipment_list} = get_routing_export_shipment_list( $handler->{dbh}, $handler->{data}{export_id} );
        $handler->{data}{return_list}   = get_routing_export_return_list( $handler->{dbh}, $handler->{data}{export_id} );

        push(
                @{ $handler->{data}->{sidenav}[0]{'None'} },
                { 'title' => 'Back', 'url' => "/Fulfilment/PremierRouting" },
                { 'title' => 'View Text File', 'url' => "/routing/".$handler->{data}{export}{filename}.".txt" }
            );
    }
    # export overview
    else {
        $handler->{data}{view} = "export";

            # list of working exports
            $handler->{data}{working} = get_working_export_list( $handler->{dbh} );

            # export search
            if ( $handler->{param_of}{search} ) {

                # export search by shipment
                if ( $handler->{param_of}{shipment_id} ) {
                    $handler->{data}{search} = get_routing_export_list( $handler->{dbh}, { 'type' => 'shipment', 'shipment_id' => $handler->{param_of}{'shipment_id'} } );
                }
                # export search by rma number
                elsif ( $handler->{param_of}{rma_number} ) {
                    $handler->{data}{search} = get_routing_export_list( $handler->{dbh}, { 'type' => 'return', 'rma_number' => $handler->{param_of}{'rma_number'} } );
                }
                # export search by date
                else {
                    my $start_date  = $handler->{param_of}{fromyear}.'-'.$handler->{param_of}{frommonth}.'-'.$handler->{param_of}{fromday};
                    my $end_date    = $handler->{param_of}{toyear}.'-'.$handler->{param_of}{tomonth}.'-'.$handler->{param_of}{today};

                    $handler->{data}{search} = get_routing_export_list( $handler->{dbh}, { 'type' => 'date', 'start' => $start_date, 'end' => $end_date } );
            }
            }


        }

    return $handler->process_template( undef );
}

1;
