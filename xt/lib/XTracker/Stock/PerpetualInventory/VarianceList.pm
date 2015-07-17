package XTracker::Stock::PerpetualInventory::VarianceList;

use strict;
use warnings;
use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Database::Stock qw( get_stock_count_variances get_stock_count_variances_count get_stock_count  get_on_hand_quantity get_stock_count_group );
use XTracker::Image;

sub handler {
    my $handler = XTracker::Handler->new(shift);

    ### check for any variances to highlight in the side nav
    my $variance_highlight = "";

    my $vars = get_stock_count_variances_count($handler->{dbh});

    if ( $vars ) {
        $variance_highlight = "&nbsp;+&nbsp;(".$vars.")";
    }

    $handler->{data}{content} = 'stocktracker/perpetual_inventory/variance_list.tt';
    $handler->{data}{section} = 'Stock Control';
    $handler->{data}{subsection} = 'Perpetual Inventory';
    $handler->{data}{subsubsection} = 'Variance List';
    $handler->{data}{sidenav} = [
        { "None" => [
            {   'title' => 'Overview',
                'url'   => "/StockControl/PerpetualInventory"
            },
            {   'title' => 'Variance List'.$variance_highlight,
                'url'   => "/StockControl/PerpetualInventory/VarianceList"
            },
            {   'title' => 'Request Stock Count',
                'url'   => "/StockControl/PerpetualInventory/RequestCount"
            },
            {   'title' => 'Process Stock Count',
                'url'   => "/StockControl/PerpetualInventory/CountVariant"
            },
            {   'title' => 'Manual Stock Count',
                'url'   => "/StockControl/PerpetualInventory/CountVariant?process_type=manual"
            },
            {   'title' => 'Settings',
                'url'   => "/StockControl/PerpetualInventory/Settings"
            }
        ] },
        { "Reports" => [
            {   'title' => 'Date Select',
                'url'   => "/StockControl/PerpetualInventory/Reports/DateSelect"
            },
            {   'title' => 'Quarter Summary',
                'url'   => "/StockControl/PerpetualInventory/Reports/QuarterSummary"
            }
        ]}
    ];
    $handler->{data}{list} = get_stock_count_variances($handler->{dbh}, $handler->{param_of}{'sort'});

    foreach my $id (keys %{$handler->{data}{list}} ) {
        $handler->{data}{list}{$id}{group} = get_stock_count_group($handler->{dbh}, $handler->{data}{list}{$id}{id});
    }

    $handler->process_template( undef );

    return OK;
}

1;
