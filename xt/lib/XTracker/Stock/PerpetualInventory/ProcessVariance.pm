package XTracker::Stock::PerpetualInventory::ProcessVariance;

use strict;
use warnings;
use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Database::Stock qw( get_stock_count_variances_count );

sub handler {
        my $handler     = XTracker::Handler->new(shift);

        ### check for any variances to highlight in the side nav
        my $variance_highlight = "";

        my $vars = get_stock_count_variances_count($handler->{dbh});

        if ( $vars ) {
                $variance_highlight = "&nbsp;+&nbsp;(".$vars.")";
        }

        ## TT data set
        $handler->{data}{content}               = 'stocktracker/perpetual_inventory/process_variance.tt',
        $handler->{data}{section}               = 'Stock Control',
        $handler->{data}{subsection}    = 'Perpetual Inventory',
        $handler->{data}{subsubsection} = 'Process Variance',
        $handler->{data}{sidenav}               = [
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
        $handler->{data}{count_id}                      = $handler->{param_of}{'count_id'};
        $handler->{data}{decision}                      = $handler->{param_of}{'decision'};
        $handler->{data}{variant_id}            = $handler->{param_of}{'variant_id'};
        $handler->{data}{location_id}           = $handler->{param_of}{'location_id'};
        $handler->{data}{expected_quantity}     = $handler->{param_of}{'expected_quantity'};
        $handler->{data}{variance}                      = $handler->{param_of}{'variance'};
        $handler->{data}{sku}                           = $handler->{param_of}{'sku'};
        $handler->{data}{location}                      = $handler->{param_of}{'location'};

        $handler->process_template( undef );

        return OK;
}

1;
