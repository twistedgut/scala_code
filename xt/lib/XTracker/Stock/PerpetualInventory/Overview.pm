package XTracker::Stock::PerpetualInventory::Overview;

use strict;
use warnings;
use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Database::Stock qw( get_stock_count_variances_count get_stock_count_summary get_category_summary get_count_summary );
use XTracker::Constants::FromDB qw( :shipment_item_status );

sub handler {
    my $handler = XTracker::Handler->new(shift);

    $handler->{data}{SHIPMENT_ITEM_STATUS__CANCELLED}=$SHIPMENT_ITEM_STATUS__CANCELLED;

    ### define date ranges for each quarter
    my %quarter_dates = (
        "1" => { "start" => "01-01", "end" => '03-31', "start_month" => "Jan", "end_month" => "Mar" },
        "2" => { "start" => "04-01", "end" => '06-30', "start_month" => "Apr", "end_month" => "Jun" },
        "3" => { "start" => "07-01", "end" => '09-30', "start_month" => "Jul", "end_month" => "Sep" },
        "4" => { "start" => "10-01", "end" => '12-31', "start_month" => "Oct", "end_month" => "Dec" },
    );

    ### work out current and last quarter
    my $cur_quarter;
    my $cur_year;
    my $last_quarter;
    my $last_year;

    my ( $sec, $min, $hour, $mday, $month, $year, $wday, $yday, $isdst )    = localtime(time);
    $month  = ($month + 1);
    $year   = ($year + 1900);

    $cur_year = $year;
    $last_year = $year;

    if ($month < 4){
        $cur_quarter = 1;
        $last_quarter = 4;
        $last_year = $last_year - 1;
    }
    elsif ($month < 7){
        $cur_quarter = 2;
        $last_quarter = 1;
    }
    elsif ($month < 10){
        $cur_quarter = 3;
        $last_quarter = 2;
    }
    else {
        $cur_quarter = 4;
        $last_quarter = 3;
    }


    ### check for any variances to highlight in the side nav
    my $variance_highlight = "";
    my $vars    = get_stock_count_variances_count($handler->{dbh});
    if ( $vars ) {
        $variance_highlight = "&nbsp;+&nbsp;(".$vars.")";
    }


    ## TT data set
    $handler->{data}{content}       = 'stocktracker/perpetual_inventory/overview.tt';
    $handler->{data}{section}       = 'Stock Control';
    $handler->{data}{subsection}    = 'Perpetual Inventory';
    $handler->{data}{subsubsection} = 'Overview';
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
            ]
        }];
    $handler->{data}{category}              = get_category_summary($handler->{dbh});
    $handler->{data}{current}               = get_count_summary($handler->{dbh}, $cur_year."-".$quarter_dates{$cur_quarter}{start}, $cur_year."-".$quarter_dates{$cur_quarter}{end});
    $handler->{data}{current_quarter_range} = $quarter_dates{$cur_quarter}{start_month}. " " . $cur_year . " - " . $quarter_dates{$cur_quarter}{end_month}. " " . $cur_year;
    $handler->{data}{last}                  = get_stock_count_summary($handler->{dbh}, $last_year."-".$quarter_dates{$last_quarter}{start}, $last_year."-".$quarter_dates{$last_quarter}{end});
    $handler->{data}{last_quarter_range}    = $quarter_dates{$last_quarter}{start_month}. " " . $last_year . " - " . $quarter_dates{$last_quarter}{end_month}. " " . $last_year;


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
        }];
    }

    $handler->process_template( undef );

    return OK;
}

1;
