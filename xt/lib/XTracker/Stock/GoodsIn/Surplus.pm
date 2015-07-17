package XTracker::Stock::GoodsIn::Surplus;

use strict;
use warnings;

use URI;

use XTracker::Handler;
use XTracker::Image;
use XTracker::Database::Delivery qw( get_delivery_channel );
use XTracker::Database::StockProcess qw(
    get_delivery_id get_stock_process_items get_process_group
);
use XTracker::Database::Product;

sub handler {
    my $handler = XTracker::Handler->new(shift);

    return $handler->redirect_to($handler->printer_station_uri)
        unless $handler->operator->has_location_for_section('surplus');

    # process group id and errors from url
    $handler->add_to_data({
        process_group_id => ($handler->{request}->param('process_group_id')//0 =~ s{^p-}{}r),
        error_id         => $handler->{request}->param('error_id')//undef,
        section          => 'Goods In',
        subsection       => 'Surplus',
        content          => 'goods_in/surplus.tt',
    });

    my $dbh = $handler->dbh;
    # No process group, we return a list
    unless ( $handler->{data}{process_group_id} ) {
        # data to populate barcode form
        $handler->add_to_data({
            scan => {
                action  => '/GoodsIn/Surplus',
                field   => 'process_group_id',
                name    => 'Process Group',
                heading => 'Surplus',
            },
            process_groups => get_process_group( $dbh, 'Surplus' ),
        });
        my $uri = URI->new('/My/SelectPrinterStation');
        $uri->query_form(
            section         => 'GoodsIn',
            subsection      => 'Surplus',
            force_selection => 1,
        );
        push @{ $handler->{data}{sidenav}[0]{'None'} }, {
            title => 'Set Surplus Station',
            url   => '/My/SelectPrinterStation?section=GoodsIn&subsection=Surplus&force_selection=1',
        };
        return $handler->process_template;
    }

    # We have a process group - we're doing surplus
    $handler->{data}{subsubsection} = 'Process Item';

    # get details of delivery
    $handler->{data}{surplus_items} = get_stock_process_items(
        $dbh, 'process_group', $handler->{data}{process_group_id}, 'surplus'
    );

    # get delivery data
    $handler->{data}{delivery_id}
        = get_delivery_id($dbh, $handler->{data}{process_group_id});

    # sales channel for delivery
    $handler->{data}{sales_channel}
        = get_delivery_channel($dbh, $handler->{data}{delivery_id});

    # get product data
    $handler->{data}{product_id} = get_product_id($dbh, {
        type => 'process_group',
        id   => $handler->{data}{process_group_id}
    });

    $handler->{data}{product} = get_product_data($dbh, {
        type => 'product_id',
        id   => $handler->{data}{product_id}
    });

    $handler->{data}{images} = get_images({
        product_id => $handler->{data}{product_id},
        live       => $handler->{data}{product}{live},
        schema     => $handler->schema,
    });

    # left nav links
    push @{ $handler->{data}{sidenav}[0]{'None'} },
        {'title' => 'Back', 'url' => "/GoodsIn/Surplus"};

    return $handler->process_template;
}

1;
