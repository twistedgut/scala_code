package XTracker::Stock::PerpetualInventory::Reports::QuarterSummary;

use strict;
use warnings;
use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Database::Stock   qw( get_stock_count_variances_count get_stock_count_list get_stock_count_group
                                    get_stock_count_summary get_stock_count_category_summary );

sub handler {
    my $handler = XTracker::Handler->new(shift);

    ### check for any variances to highlight in the side nav
    my $variance_highlight = "";
    my $vars    = get_stock_count_variances_count($handler->{dbh});
    if ( $vars ) {
        $variance_highlight = "&nbsp;+&nbsp;(".$vars.")";
    }

    ## TT data set
    $handler->{data}{content}       = 'stocktracker/perpetual_inventory/quartersummary_report.tt';
    $handler->{data}{section}       = 'Stock Control';
    $handler->{data}{subsection}    = 'Perpetual Inventory';
    $handler->{data}{subsubsection} = 'Reports';
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


    # form submitted ?
    if ( $handler->{param_of}{"quarter"} ) {

        ### define date ranges for each quarter
        my %quarter_dates = (
            '1' => { 'start' => '01-01', 'end' => '03-31' },
            '2' => { 'start' => '04-01', 'end' => '06-30' },
            '3' => { 'start' => '07-01', 'end' => '09-30' },
            '4' => { 'start' => '10-01', 'end' => '12-31' },
        );

        # get start and end dates for quarter
        my $start_date  = $handler->{param_of}{'year'}.'-'.$quarter_dates{$handler->{param_of}{'quarter'}}{start};
        my $end_date    = $handler->{param_of}{'year'}.'-'.$quarter_dates{$handler->{param_of}{'quarter'}}{end};

        # pass form data to template data
        $handler->{data}{quarter}   = $handler->{param_of}{'quarter'};
        $handler->{data}{year}      = $handler->{param_of}{'year'};

        # get count data
        $handler->{data}{category_results} = get_stock_count_category_summary($handler->{dbh}, $start_date, $end_date);
        $handler->{data}{overview_results} = get_stock_count_summary($handler->{dbh}, $start_date, $end_date);

    }

    $handler->process_template( undef );

    return OK;
}

1;
