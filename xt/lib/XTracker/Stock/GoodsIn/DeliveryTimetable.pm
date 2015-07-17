package XTracker::Stock::GoodsIn::DeliveryTimetable;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use Plack::App::FakeApache1::Constants qw(:common);
use XTracker::Handler;
use XTracker::Session;
use XTracker::Navigation qw( get_navtype build_nav build_sidenav );
use XTracker::Schema;
use XTracker::Error;

use Data::Page;

use DateTime;

sub handler {
    my $handler = XTracker::Handler->new(shift);

    my $today       = DateTime->now( time_zone => 'floating' );
    my $next_week   = DateTime->now( time_zone => 'floating' )->add( days => 7 );

    my $start       = $handler->{param_of}{start_date} || $today->ymd;
    my $end         = $handler->{param_of}{end_date} || $next_week->ymd;
    my $page = $handler->{param_of}{page} || 1;

    my $stock_order_rs      = $handler->{schema}->resultset('Public::StockOrder');
    #my $stock_order_item_rs = $handler->{schema}->resultset('Public::StockOrderItem');

    $start =~ s/(\d+)-(\d+)-(\d+)/$3-$2-$1/;
    $end =~ s/(\d+)-(\d+)-(\d+)/$3-$2-$1/;

    my $pager = Data::Page->new();
    $pager->entries_per_page(50);
    $pager->total_entries( $stock_order_rs->get_undelivered_stock( $start, $end, "COUNT" ) );
    $pager->current_page( $page );
    my $undelivered_stock = $stock_order_rs->get_undelivered_stock( $start, $end, "LIST", $pager->entries_per_page, $pager->skipped );

    $handler->{data}{yui_enabled}       = 1;
    $handler->{data}{content}           = 'goods_in/delivery_timetable.tt';
    $handler->{data}{section}           = 'Goods In';
    $handler->{data}{subsection}        = 'Delivery Timetable';
    $handler->{data}{undelivered_stock} = $undelivered_stock;
    $handler->{data}{js}                = '/javascript/NapCalendar.js';
    $handler->{data}{start_window}      = $start;
    $handler->{data}{end_window}        = $end;
    $handler->{data}{pager} = $pager;
    $handler->{data}{search_terms} = { start_date => $handler->{param_of}{start_date} || $today->ymd,
                                       end_date => $handler->{param_of}{end_date} || $next_week->ymd };

    $handler->process_template( undef );
    return OK;
}

1;

__END__
