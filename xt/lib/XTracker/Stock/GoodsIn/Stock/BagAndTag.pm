package XTracker::Stock::GoodsIn::Stock::BagAndTag;

use strict;
use warnings;
use Carp;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Image;
use XTracker::Database::Delivery qw( get_delivery get_delivery_channel );
use XTracker::Database::StockProcess qw( get_delivery_id get_stock_process_items get_process_group );
use XTracker::Database::Product qw( get_product_id get_product_summary );

### Subroutine : handler                        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# tt-template  :                                  #
# tt-variables :                                  #

sub handler {

    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    # process group id and errors from url
    $handler->{data}{process_group_id}  = $handler->{request}->param('process_group_id') || 0;
    $handler->{data}{process_group_id} =~ s/^p-//i;
    $handler->{data}{error}             = $handler->{request}->param('error') || 0;

    $handler->{data}{section}       = 'Goods In';
    $handler->{data}{subsection}    = 'Bag & Tag';
    $handler->{data}{subsubsection} = '';
    $handler->{data}{content}       = 'goods_in/stock/bag_and_tag.tt';


    CASE: {
        # if a process group is defined we're doing bag & tag
        if ( $handler->{data}{process_group_id} && ($handler->{data}{process_group_id} !~ /[^\d]/) ) {

            $handler->{data}{subsubsection} = 'Process Item';

            # get delivery id && stock process items
            $handler->{data}{delivery_id}           = get_delivery_id( $handler->{dbh}, $handler->{data}{process_group_id} );
            $handler->{data}{stock_process_items}   = get_stock_process_items( $handler->{dbh}, 'process_group', $handler->{data}{process_group_id}, 'bagandtag' );
            # get product id
            $handler->{data}{product_id}            = get_product_id( $handler->{dbh}, { type => 'process_group', id => $handler->{data}{process_group_id} } );

            if ( $handler->{data}{delivery_id} && ( @{ $handler->{data}{stock_process_items} } ) && $handler->{data}{product_id} ) {

                # get delivery data
                $handler->{data}{delivery}      = get_delivery( $handler->{dbh}, $handler->{data}{delivery_id});

                # sales channel for delivery
                $handler->{data}{sales_channel} = get_delivery_channel( $handler->{dbh}, $handler->{data}{delivery_id});

                # get common product summary data for header
                $handler->add_to_data( get_product_summary( $handler->{schema}, $handler->{data}{product_id} ) );

                # left nav links
                push(@{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => 'Back', 'url' => "/GoodsIn/BagAndTag" } );
                push(@{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => 'Hold Delivery', 'url' => "/GoodsIn/DeliveryHold/HoldDelivery?delivery_id=$handler->{data}{delivery_id}" } );

                last CASE;
            }
            else {
                if ( !$handler->{data}{delivery_id} ) {
                    $handler->{data}{error_msg} = "Couldn't Find a Delivery for Process Group Id: ".$handler->{data}{process_group_id};
                }
                elsif ( !@{ $handler->{data}{stock_process_items} } ) {
                    $handler->{data}{error_msg} = "Couldn't Find any Items to be Bag & Tag'd for Process Group Id: ".$handler->{data}{process_group_id};
                }
                else {
                    $handler->{data}{error_msg} = "Couldn't Find a Product for Process Group Id: ".$handler->{data}{process_group_id};
                }

                # get rid of any success so that the initial list is shown again
                delete $handler->{data}{delivery_id};
                delete $handler->{data}{stock_process_items};
                delete $handler->{data}{product_id};
            }
        }

        # no process group defined show list

        # data to populate barcode form
        $handler->{data}{scan}{action}  = '/GoodsIn/BagAndTag';
        $handler->{data}{scan}{field}   = 'process_group_id';
        $handler->{data}{scan}{name}    = 'Process Group';
        $handler->{data}{scan}{heading} = 'Bag & Tag';

        # get list of process groups
        $handler->{data}{process_groups} = get_process_group( $handler->{dbh}, 'BagAndTag' );

        # load css & javascript for tab view
        $handler->{data}{css}   = ['/yui/tabview/assets/skins/sam/tabview.css'];
        $handler->{data}{js}    = ['/yui/yahoo-dom-event/yahoo-dom-event.js', '/yui/element/element-min.js', '/yui/tabview/tabview-min.js'];
    };

    $handler->process_template( undef );

    return OK;

}



1;
