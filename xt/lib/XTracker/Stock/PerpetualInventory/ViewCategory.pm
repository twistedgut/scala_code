package XTracker::Stock::PerpetualInventory::ViewCategory;

use strict;
use warnings;
use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Database::Stock qw( get_stock_count_variances_count get_category_name get_category_list );

sub handler {
    my $handler = XTracker::Handler->new(shift);

    ### check for any variances to highlight in the side nav
    my $variance_highlight  = "";
    my $vars    = get_stock_count_variances_count($handler->{dbh});
    if ( $vars ) {
        $variance_highlight = "&nbsp;+&nbsp;(".$vars.")";
    }

    ## TT data set
    $handler->{data}{content}       = 'stocktracker/perpetual_inventory/view_category.tt';
    $handler->{data}{section}       = 'Stock Control';
    $handler->{data}{subsection}    = 'Perpetual Inventory';
    $handler->{data}{subsubsection} = 'View Category';
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
    $handler->{data}{cat_id}        = $handler->{param_of}{'cat'};
    $handler->{data}{category}      = get_category_name($handler->{dbh}, $handler->{param_of}{'cat'});

    ### remove most of the left nav links if not a "manager" auth level
    if ($handler->auth_level < 3) {
        $handler->{data}{sidenav} = [{
            "None" => [
                {   'title' => 'Overview',
                    'url'   => "/StockControl/PerpetualInventory"
                },
                {   'title' => 'Process Stock Count',
                    'url'   => "/StockControl/PerpetualInventory/CountVariant"
                }
            ]
        }],
    }

    $handler->{data}{cat}   = $handler->{param_of}{'cat'};
    $handler->{data}{sort}  = $handler->{param_of}{'sort'};

    ### get results set
    $handler->{data}{list}  = get_category_list($handler->{dbh}, $handler->{param_of}{'cat'}, $handler->{param_of}{'sort'});

    ### set up paging vars
    $handler->{data}{page_limit}    = 250;

    $handler->{data}{page}          = 1;

    if ($handler->{param_of}{'page'}){
        $handler->{data}{page}  = $handler->{param_of}{'page'};
    }

    $handler->{data}{num_records}   = keys( %{$handler->{data}{list}} );

    $handler->{data}{num_pages}     = sprintf( "%.0f", ($handler->{data}{num_records} / $handler->{data}{page_limit}));

    if ($handler->{data}{num_pages} == 0){ $handler->{data}{num_pages} = 1; }

    if ($handler->{data}{page} == $handler->{data}{num_pages}){
        $handler->{data}{next}  = "";

        if ($handler->{data}{num_pages} > 1){
            $handler->{data}{prev}  = "<a href=\"/StockControl/PerpetualInventory/ViewCategory?cat=".$handler->{param_of}{'cat'}."&page=".($handler->{data}{page}-1)."&sort=".$handler->{param_of}{'sort'}."\">< Previous Page</a>";
        }
        else {
            $handler->{data}{prev}  = "";
        }
    }
    else {

        if ($handler->{data}{num_pages} > 1){
            $handler->{data}{next} = "<a href=\"/StockControl/PerpetualInventory/ViewCategory?cat=".$handler->{param_of}{'cat'}."&page=".($handler->{data}{page}+1)."&sort=".$handler->{param_of}{'sort'}."\">Next Page ></a>";
        }
        else {
            $handler->{data}{next} = "";
        }

        if ($handler->{data}{page} > 1){
            $handler->{data}{prev} = "<a href=\"/StockControl/PerpetualInventory/ViewCategory?cat=".$handler->{param_of}{'cat'}."&page=".($handler->{data}{page}-1)."&sort=".$handler->{param_of}{'sort'}."\">< Previous Page</a>";
        }
        else {
            $handler->{data}{prev} = "";
        }
    }

    if ($handler->{data}{page} == 1){
        $handler->{data}{page_start} = 1;
    }
    else {
        $handler->{data}{page_start} = ($handler->{data}{page} - 1) * $handler->{data}{page_limit};
    }

    $handler->{data}{page_end} = $handler->{data}{page_start} + $handler->{data}{page_limit};


    $handler->process_template( undef );

    return OK;
}

1;
