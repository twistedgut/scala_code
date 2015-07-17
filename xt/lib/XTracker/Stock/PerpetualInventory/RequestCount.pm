package XTracker::Stock::PerpetualInventory::RequestCount;

use strict;
use warnings;
use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Database::Stock           qw( get_located_stock get_stock_count_variances_count );
use XTracker::Database::Product;
use XTracker::Constants::FromDB         qw( :flow_status );

sub handler {
    my $handler = XTracker::Handler->new(shift);

    ### check for any variances to highlight in the side nav
    my $variance_highlight = "";
    my $vars    = get_stock_count_variances_count($handler->{dbh});
    if ( $vars ) {
        $variance_highlight = "&nbsp;+&nbsp;(".$vars.")";
    }

    ## TT data set
    $handler->{data}{content}       = 'stocktracker/perpetual_inventory/request_count.tt';
    $handler->{data}{section}       = 'Stock Control';
    $handler->{data}{subsection}    = 'Perpetual Inventory';
    $handler->{data}{subsubsection} = 'Request Stock Count';
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

    ## gather form data
    my $sku         = $handler->{param_of}{'sku'};                  ## SKU entered user
    my $location    = $handler->{param_of}{'location'};             ## location entered by user
    my $var_id      = $handler->{param_of}{'var_id'};               ## variant id from hidden form field

    ## if no var id but we have a SKU entered by user then get var id from SKU
    if (!$var_id && $sku){
        $var_id = get_variant_by_sku($handler->{dbh}, $sku);
    }

    ## set data for use on the page
    $handler->{data}{sku}               = $sku;
    $handler->{data}{location}          = $location;
    $handler->{data}{var_id}            = $var_id;

    ## form submitted - do stuff
    if ( $var_id ) {

        eval {
            ### get current locations for SKU entered by user
            my $locations = get_located_stock( $handler->{dbh}, { type => 'variant_id', id => $var_id } );

            my $db_location     = "";
            my $location_count  = 0;

            ## loop through all locations from all channels and build up hash
            foreach ( keys %$locations ) {
                foreach my $var_location ( keys %{ $locations->{$_}{$var_id} } ) {
                    if ( exists $locations->{$_}{$var_id}{$var_location}{$FLOW_STATUS__MAIN_STOCK__STOCK_STATUS} ) {
                        $handler->{data}{locations}{$var_location}  = $locations->{$_}{$var_id}{$var_location}{$FLOW_STATUS__MAIN_STOCK__STOCK_STATUS}{location};
                        $location_count++;
                        $db_location    = $locations->{$_}{$var_id}{$var_location}{$FLOW_STATUS__MAIN_STOCK__STOCK_STATUS}{location};
                    }
                }
            }

            ### only one location - preset it in the form
            if ($location_count == 1){
                $handler->{data}{location} = $db_location;
            }

            if ( !$location_count ) {
                $handler->{data}{error_msg} = "No Locations could be found for SKU: ".$handler->{data}{sku};
                $handler->{data}{var_id}    = "";
                $handler->{data}{sku}       = "";
            }
        };

        if ($@) {
            $handler->{data}{error_msg} = $@;
        }
    }

    $handler->process_template( undef );

    return OK;
}

1;
