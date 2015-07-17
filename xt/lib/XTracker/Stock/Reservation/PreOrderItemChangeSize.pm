package XTracker::Stock::Reservation::PreOrderItemChangeSize;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Error;
use XTracker::Constants::FromDB         qw( :pre_order_item_status );
#use XTracker::Navigation;

use Try::Tiny;

sub handler {
    my $handler     = XTracker::Handler->new(shift);


    $handler->{data}{section}       = 'Reservation';
    $handler->{data}{subsection}    = 'Pre-Order';
    $handler->{data}{subsubsection} = 'Size Change';
    $handler->{data}{content}       = 'stocktracker/reservation/preorder_itemsizechange.tt';
    $handler->{data}{css}           = ['/css/preorder.css'];
    $handler->{data}{js}            = '/javascript/preorder.js';

    my $pre_order_id    = $handler->{param_of}{pre_order_id} // 0;

    push @{ $handler->{data}{sidenav}[0]{'None'} }, {
                                            title   => "Back",
                                            url     => "/StockControl/Reservation/PreOrder/Summary?pre_order_id=${pre_order_id}",
                                        };

    my $schema  = $handler->schema;

    try {
        my $pre_order   = $schema->resultset('Public::PreOrder')->find( $pre_order_id );
        $handler->{data}{pre_order} = $pre_order;
        $handler->{data}{customer}  = $pre_order->customer;

        # renders the page in the Sales Channel's colours
        $handler->{data}{sales_channel} = $pre_order->channel->name;

        my @items   = $pre_order->pre_order_items->search( {
                                                        pre_order_item_status_id => { '!=' => $PRE_ORDER_ITEM_STATUS__CANCELLED },
                                                    } )->order_by_sku->all;
        foreach my $item ( @items ) {
            my $variant = $item->variant;
            my $item_details    = {
                        item_obj        => $item,
                        sku             => $variant->sku,
                        name            => $item->name,
                        size            => $variant->size->size,
                        designer_size   => $variant->designer_size->size,
                        can_change_size => 0,
                    };

            # get alternative sizes
            if ( $item->is_complete ) {
                $item_details->{can_change_size}= 1;
                $item_details->{alt_sizes}      = $variant->product
                                                            ->get_variants_for_pre_order( $pre_order->channel, {
                                                                                            exclude_variant_id => $variant->id,
                                                                                        } );
            }

            push @{ $handler->{data}{pre_order_items} }, $item_details;
        }
    }
    catch {
        xt_warn("Error Occured: $_");
    };


    return $handler->process_template;
}

1;
