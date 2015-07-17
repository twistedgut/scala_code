package XTracker::Stock::PerpetualInventory::Settings;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Database::Stock qw( get_stock_count_setting set_stock_count_setting get_stock_count_variances_count );

sub handler {
    my $handler = XTracker::Handler->new( shift );
    my $dbh = $handler->dbh;

    if ( $handler->{request}->method eq 'POST' ) {
        set_stock_count_setting( $dbh,
            map { $handler->{param_of}{$_} ? 'true' : 'false' } qw{picking returns}
        );
    }

    ### check for any variances to highlight in the side nav
    my $variance_highlight  = "";
    my $vars    = get_stock_count_variances_count($dbh);
    if ( $vars ) {
        $variance_highlight = "&nbsp;+&nbsp;(".$vars.")";
    }

    ## TT data set
    $handler->{data}{content}       = 'stocktracker/perpetual_inventory/settings.tt';
    $handler->{data}{section}       = 'Stock Control';
    $handler->{data}{subsection}    = 'Perpetual Inventory';
    $handler->{data}{subsubsection} = 'Settings';
    $handler->{data}{sidenav}       = [
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

    $handler->{data}{picking}   = get_stock_count_setting($dbh, "picking");
    $handler->{data}{returns}   = get_stock_count_setting($dbh, "returns");

    return $handler->process_template( undef );
}

1;
