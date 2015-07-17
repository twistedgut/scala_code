package XTracker::Stock::GoodsIn::Stock::FastTrack;

use strict;
use warnings;
use Carp;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Image;
use XTracker::Database::Delivery qw( get_delivery get_delivery_channel );
use XTracker::Database::StockProcess;
use XTracker::Database::Attributes;
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

    # delivery id and errors from url
    $handler->{data}{delivery_id} = $handler->{request}->param('delivery_id') || 0;
    $handler->{data}{error}       = $handler->{request}->param('error') || 0;

    $handler->{data}{section}       = 'Goods In';
    $handler->{data}{subsection}    = 'Quality Control';
    $handler->{data}{subsubsection} = 'Fast Track Item';
    $handler->{data}{content}       = 'goods_in/stock/fast_track.tt';

    # get delivery data
    $handler->{data}{delivery}              = get_delivery( $handler->{dbh}, $handler->{data}{delivery_id});
    $handler->{data}{stock_process_items}   = get_stock_process_items( $handler->{dbh}, 'delivery_id', $handler->{data}{delivery_id}, 'quality_control' );

    # sales channel for delivery
    $handler->{data}{sales_channel} = get_delivery_channel( $handler->{dbh}, $handler->{data}{delivery_id});

    # get product data
    $handler->{data}{product_id}    = get_product_id( $handler->{dbh}, { type => 'delivery_id', id => $handler->{data}{delivery_id} } );

    # get common product summary data for header
    $handler->add_to_data( get_product_summary( $handler->{schema}, $handler->{data}{product_id} ) );

    # left nav links
    push(@{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => 'Back', 'url' => "/GoodsIn/QualityControl/Book?delivery_id=$handler->{data}{delivery_id}" } );

    $handler->process_template( undef );

    return OK;

}

1;

