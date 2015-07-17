package XTracker::Stock::PerpetualInventory::Reports::DateSelect;

use strict;
use warnings;
use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Database::Stock qw( get_stock_count_variances_count get_stock_count_list get_stock_count_group );
use XTracker::Utilities qw( isdates_ok );

sub handler {
    my $handler = XTracker::Handler->new(shift);

    ### check for any variances to highlight in the side nav
    my $variance_highlight = "";
    my $vars    = get_stock_count_variances_count($handler->{dbh});
    if ( $vars ) {
        $variance_highlight = "&nbsp;+&nbsp;(".$vars.")";
    }

    ## TT data set
    $handler->{data}{content}       = 'stocktracker/perpetual_inventory/dateselect_report.tt',
    $handler->{data}{section}       = 'Stock Control',
    $handler->{data}{subsection}    = 'Perpetual Inventory',
    $handler->{data}{subsubsection} = 'Reports',
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

    my ($sec,$min,$hour,$day,$month,$year,$wday,$yday,$isdst)   = localtime(time);
    $month++;
    $year = $year+1900;

    $handler->{data}{day}   = $day;
    $handler->{data}{month} = $month;
    $handler->{data}{year}  = $year;

    ### form submitted
    if ( $handler->{param_of}{"fromyear"} ) {

        my $start_date  = $handler->{param_of}{"fromyear"}."-".$handler->{param_of}{"frommonth"}."-".$handler->{param_of}{"fromday"};
        my $end_date    = $handler->{param_of}{"toyear"}."-".$handler->{param_of}{"tomonth"}."-".$handler->{param_of}{"today"};

        $handler->{data}{form}{fromday}     = $handler->{param_of}{"fromday"};
        $handler->{data}{form}{frommonth}   = $handler->{param_of}{"frommonth"};
        $handler->{data}{form}{fromyear}    = $handler->{param_of}{"fromyear"};
        $handler->{data}{form}{today}       = $handler->{param_of}{"today"};
        $handler->{data}{form}{tomonth}     = $handler->{param_of}{"tomonth"};
        $handler->{data}{form}{toyear}      = $handler->{param_of}{"toyear"};

        if (isdates_ok($start_date,$end_date)) {
            $handler->{data}{results}   = get_stock_count_list($handler->{dbh}, $start_date, $end_date, $handler->{param_of}{'sort'});
        }
        else {
            $handler->{data}{error_msg} = "Invalid Dates Selected.";
        }

#       foreach my $id (keys %{$handler->{data}{results}} ){
#           $handler->{data}{results}{$id}{group} = get_stock_count_group($handler->{dbh}, $handler->{data}{results}{$id}{id});
#       }

    }

    $handler->process_template( undef );

    return OK;
}

1;
