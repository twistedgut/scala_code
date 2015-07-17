package XTracker::Order::Functions::Return::ManualReturnAlteration;

use strict;
use warnings;

use URI;

use XTracker::Handler;
use XTracker::Utilities                 qw( parse_url );
use XTracker::Error;

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    # get section and sub-section out of URL
    my ($section, $subsection, $short_url)  = parse_url($r);

    $handler->{data}{section}           = $section;
    $handler->{data}{subsection}        = $subsection;
    $handler->{data}{subsubsection}     = "Manual Return Alterations Post Refund";
    $handler->{data}{short_url}         = $short_url;
    $handler->{data}{content}           = 'ordertracker/returns/manualalteration.tt';

    # get order_id, shipment_id and return_id
    $handler->{data}{order_id}      = $handler->{param_of}{order_id};
    $handler->{data}{shipment_id}   = $handler->{param_of}{shipment_id};
    $handler->{data}{return_id}     = $handler->{param_of}{return_id};

    my $params = {
        order_id => $handler->{data}{order_id},
        shipment_id => $handler->{data}{shipment_id},
        return_id => $handler->{data}{return_id},
    };
    my $back_uri = URI->new("$short_url/Returns/View");
    $back_uri->query_form($params);

    push @{ $handler->{data}{sidenav}[0]{'None'} }, {
        'title' => 'Back to Return',
        'url' => $back_uri,
    };

    my ( $return, $order );
    if ( $handler->{data}{order_id} && $handler->{data}{order_id} !~ m/[^\d]/ ) {
        $order  = $handler->schema->resultset('Public::Orders')->find( $handler->{data}{order_id} );
        $handler->{data}{sales_channel} = $order->channel->name     if ( defined $order );
    }

    if ( $handler->{data}{return_id} && $handler->{data}{return_id} !~ m/[^\d]/ ) {
        $return = $handler->schema->resultset('Public::Return')->find( $handler->{data}{return_id} );
    }

    return $handler->process_template unless $return;

    # if we've found a Return then do something
    $handler->{data}{return}            = $return;
    $handler->{data}{shipment}          = $return->shipment;
    $handler->{data}{exchange_shipment} = $return->exchange_shipment;

    # if the form was submitted then process the items
    if ( $handler->{param_of}{select_item} ) {
        my $done_something;
        my $stock_manager = $handler->{data}{shipment}->get_channel->stock_manager;

        # Remember whether IWS knows about shipment now, before we start cancelling shipment items
        my $exchange_shipment = $return->exchange_shipment;
        my $iws_knows = $exchange_shipment && $exchange_shipment->does_iws_know_about_me();

        my $cancel_exchange;
        eval {
            $handler->schema->txn_do( sub {
                ( $done_something, $cancel_exchange ) = _process_items( $handler, $stock_manager );
                $stock_manager->commit;
            } );
            if ( $done_something ) {
                xt_info(
                    '<strong>Please Remember:</strong><br/>No Invoices have been touched whilst updating these Return Items, any requirements to adjust Refund Invoices<br/>after these updates will <strong>now</strong> need to be dealt with <strong>separately</strong>.'
                );
                xt_success("Updated Item(s)");
            }
        };
        if ( my $err = $@ ) {
            $stock_manager->rollback;
            xt_warn("Error occurred whilst making changes:<br/>$err");
        }
        else {
            $handler->domain('Returns')->
                send_msgs_for_exchange_items( $exchange_shipment ) if $iws_knows;
        }

        # Let's redirect so we can get to this page with our query, not post parameters
        my $uri = URI->new($handler->path);
        $uri->query_form($params);
        return $handler->redirect_to( $uri );
    }

    $handler->{data}{exchange_pack_status} = $return->exchange_shipment->pack_status
        if $return->exchange_shipment;
    $handler->{data}{return_items} = [
        $return->return_items->search( {}, { order_by => 'me.shipment_item_id,me.id' } )->all
    ];

    return $handler->process_template;
}

sub _process_items {
    my ( $handler, $stock_manager ) = @_;

    my $return  = $handler->{data}{return};
    my %data    = (
            return_id   => $return->id,
            operator_id => $handler->operator_id,
        );

    my $num_cancel_items    = 0;
    my $num_convert_items   = 0;

    foreach my $param ( keys %{ $handler->{param_of} } ) {
        next unless $param =~ m/(\w*)-(\d*$)/;
        my $action  = $1;
        my $item_id = $2;

        my $retitem = $return->return_items->find( $item_id );
        next        if ( $retitem->is_cancelled );

        # set-up basic info for the return item
        my $item    = {
                type            => $retitem->type->type,
                reason_id       => $retitem->customer_issue_type_id,
                shipment_item_id=> $retitem->shipment_item_id,
            };

        # Want to Convert from Exchange to Return (Refund)
        if ( $action eq "convert" && $retitem->is_exchange ) {
            $item->{remove}             = 1;
            $item->{change}             = 1;
            $item->{current_status_id}  = $retitem->return_item_status_id;
            $item->{current_return_awb} = $retitem->return_airway_bill;

            $num_convert_items++;
        }

        # Want to Cancel Exchange/Return
        if ( $action eq "cancel" ) {
            $item->{remove} = 1;

            $num_cancel_items++;
        }

        $data{return_items}{ $retitem->id } = $item;
    }

    if ( ( $num_cancel_items + $num_convert_items ) == 0 ) {
        # no items were requested so do nothing
        return 0;
    }

    $data{num_convert_items}    = $num_convert_items;
    $data{num_cancel_items}     = $num_cancel_items;

    # Make the changes to the Return Items
    my $cancel_exchange = $handler->domain('Returns')->manual_alteration({
        %data, stock_manager => $stock_manager,
    });

    return ( $num_cancel_items + $num_convert_items, $cancel_exchange );
}


1;
