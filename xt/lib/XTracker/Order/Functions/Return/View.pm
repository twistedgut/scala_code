package XTracker::Order::Functions::Return::View;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Image qw( get_images );
use XTracker::Database::Order;
use XTracker::Database::Shipment;
use XTracker::Database::Address;
use XTracker::Database::Return;
use XTracker::Utilities qw( parse_url );
use XTracker::Constants::FromDB qw( :department :return_status :return_item_status :renumeration_status );


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
    $handler->{data}{subsubsection} = 'View Return';
    $handler->{data}{content}       = 'ordertracker/returns/view.tt';
    $handler->{data}{short_url}     = $short_url;

    # get order_id, shipment_id and return_id from URL
    $handler->{data}{return_id} = $handler->{param_of}{return_id};
    $handler->{data}{order_id}  = $handler->{param_of}{order_id};

    my $schema = $handler->schema;
    # Set or derive the shipment_id if we can
    $handler->{data}{shipment_id}
        = $handler->{param_of}{shipment_id}
       || $handler->{data}{return_id} && $schema->resultset('Public::Return')
                                                ->find($handler->{data}{return_id})
                                                ->shipment_id;

    # get sales channel if order id defined
    if ($handler->{data}{order_id}) {
        $handler->{data}{order}         = get_order_info( $handler->{dbh}, $handler->{data}{order_id} );
        $handler->{data}{sales_channel} = $handler->{data}{order}{sales_channel};
    }

    # get shipment item info
    $handler->{data}{shipment_items}
        = defined $handler->{data}{shipment_id}
        ? get_shipment_item_info( $handler->{dbh}, $handler->{data}{shipment_id} )
        : {};


    # return id defined we're working on a specific RMA
    if ($handler->{data}{return_id}) {

        my $return  = $handler->schema->resultset('Public::Return')->find( $handler->{data}{return_id} );

        # get return data from db
        $handler->{data}{return}            = get_return_info( $handler->{dbh}, $handler->{data}{return_id} );
        $handler->{data}{return_log}        = get_return_log( $handler->{dbh}, $handler->{data}{return_id} );
        $handler->{data}{return_notes}      = get_return_notes( $handler->{dbh}, $handler->{data}{return_id} );
        $handler->{data}{return_items}      = get_return_item_info( $handler->{dbh}, $handler->{data}{return_id} );
        $handler->{data}{return_items_log}  = get_return_items_log( $handler->{dbh}, $handler->{data}{return_id} );
        $handler->{data}{return_email_log}  = $return->get_correspondence_logs->formatted_for_page;

        $handler->{data}{awaiting_count}    = 0;
        $handler->{data}{received_count}    = 0;

        # loop over return items to work out what status they're in
        foreach my $item_id ( keys %{ $handler->{data}{return_items} } ) {
            if ( $handler->{data}{return_items}{$item_id}{return_item_status_id} == $RETURN_ITEM_STATUS__AWAITING_RETURN ){
                $handler->{data}{awaiting_count}++;
            }
            elsif ( $handler->{data}{return_items}{$item_id}{return_item_status_id} < $RETURN_ITEM_STATUS__CANCELLED ){
                $handler->{data}{received_count}++;
            }

            # get product images
            my $shipment_item_id = $handler->{data}{return_items}{$item_id}{shipment_item_id};
            $handler->{data}{return_items}{$item_id}{images} = get_images({
                product_id => $handler->{data}{shipment_items}{$shipment_item_id}{product_id},
                live => 1,
                size => 'l',
                schema => $handler->schema,
            });
        }

        # Sort by status, with cancelled at the bottom.
        $handler->{data}{return_items} = [ sort {
            if ($a->{return_item_status_id} != $b->{return_item_status_id}) {
                $a->{return_item_status_id} <=> $b->{return_item_status_id}
            }
            else {
                $b->{id} <=> $a->{id}
            }
        } values %{$handler->{data}{return_items} } ];
        # Need this new HASH so that the SKU can be retrieved when listing the Return Item Status Logs
        $handler->{data}{return_items_sku}  = {
            map { $_->{id} => $_->{sku} } @{ $handler->{data}{return_items} }
        };

        # build side nav

        my $url_extension = "order_id=$handler->{data}{order_id}&shipment_id=$handler->{data}{shipment_id}&return_id=$handler->{data}{return_id}";

        # back links
        push( @{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => "Back to Order", 'url' => "$short_url/OrderView?order_id=$handler->{data}{order_id}" } );
        push( @{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => "Back to Returns", 'url' => "$short_url/Returns/View?order_id=$handler->{data}{order_id}&shipment_id=$handler->{data}{shipment_id}" } );

        # actions dependant on return not being completed
        if ( $handler->{data}{return}{return_status_id} < $RETURN_STATUS__COMPLETE ) {

            push( @{ $handler->{data}{sidenav}[0]{'None'} },
                { 'title' => "Edit Dates",
                  'url' => "$short_url/Returns/Edit?return_id=$handler->{data}{return_id}"
                }
            );

            push( @{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => "Add Item", 'url' => "$short_url/Returns/AddItem?$url_extension" } );

            if ( $handler->{data}{awaiting_count} > 0 ) {
                push( @{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => "Remove Item", 'url' => "$short_url/Returns/RemoveItem?$url_extension" } );
            }
            if ( $handler->{data}{received_count} == 0 ) {
                push( @{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => "Cancel Return", 'url' => "$short_url/Returns/Cancel?$url_extension" } );
            }

            push( @{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => "Convert to Exchange", 'url' => "$short_url/ConvertToExchange?$url_extension" } );

        }

        # actions dependant on return not being cancelled
        if ( $handler->{data}{return}{return_status_id} < $RETURN_STATUS__CANCELLED ) {

            push( @{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => "Convert From Exchange", 'url' => "$short_url/ConvertFromExchange?$url_extension" } );

            # actions restricted by department
            if ($handler->department_id == $DEPARTMENT__STOCK_CONTROL || $handler->department_id == $DEPARTMENT__DISTRIBUTION_MANAGEMENT ) {
                push( @{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => "Reverse Booked In Item", 'url' => "$short_url/Returns/ReverseItem?$url_extension" } );
            }
        }

        # EN-2347: Check to see if any Invoice has been Completed for the Return
        if ( grep { $_->renumeration_status_id == $RENUMERATION_STATUS__COMPLETED } $return->renumerations->all ) {
            # if so display the 'Manual Alteration' option
            push( @{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => "Manual Alterations Post Refund", 'url' => "$short_url/ManualReturnAlteration?$url_extension" } );
        }

        push( @{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => "Add Note", 'url' => "$short_url/Note?parent_id=$handler->{data}{order_id}&note_category=Return&sub_id=$handler->{data}{return_id}" } );

    }
    # no return_id but shipment_id defined - get all returns on shipment
    elsif ( $handler->{data}{shipment_id} ) {

        $handler->{data}{ship_info}     = get_shipment_info( $handler->{dbh}, $handler->{data}{shipment_id} );
        $handler->{data}{ship_address}  = get_address_info( $handler->{dbh}, $handler->{data}{ship_info}{shipment_address_id} );
        $handler->{data}{returns}       = get_shipment_returns( $handler->{dbh}, $handler->{data}{shipment_id} );

        foreach my $return_id ( keys %{ $handler->{data}{returns} } ) {
            $handler->{data}{returns}{$return_id}{return_items} = get_return_item_info( $handler->{dbh}, $return_id );

            # loop over return items to get images
            foreach my $item_id ( keys %{ $handler->{data}{returns}{$return_id}{return_items} } ) {
                my $shipment_item_id = $handler->{data}{returns}{$return_id}{return_items}{$item_id}{shipment_item_id};
                $handler->{data}{returns}{$return_id}{return_items}{$item_id}{images} = get_images({
                    product_id => $handler->{data}{shipment_items}{$shipment_item_id}{product_id},
                    live => 1,
                    size => 'l',
                    schema => $handler->schema,
                });
            }
        }

        push( @{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => "Back", 'url' => "$short_url/OrderView?order_id=$handler->{data}{order_id}" } );
        push( @{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => "Create Return", 'url' => "$short_url/Returns/Create?order_id=$handler->{data}{order_id}&shipment_id=$handler->{data}{shipment_id}" } );

    }
    # no return or shipment id - get all shipments on order for user to select from
    else {
        $handler->{data}{shipments}     = get_order_shipment_info( $handler->{dbh}, $handler->{data}{order_id} );

        # back link
        push( @{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => "Back", 'url' => "$short_url/OrderView?order_id=$handler->{data}{order_id}" } );
    }

    return $handler->process_template( undef );
}

1;
