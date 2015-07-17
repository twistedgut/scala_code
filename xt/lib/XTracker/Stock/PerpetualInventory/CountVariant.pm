package XTracker::Stock::PerpetualInventory::CountVariant;

use strict;
use warnings;
use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Database::Location    qw( :iws );
use XTracker::Database::Product     qw( get_product_summary get_variant_by_sku get_variant_product_data );
use XTracker::Database::Stock       qw( get_stock_count_variances_count get_stock_count_by_location );
use XTracker::Error;
use XTracker::Handler;
use XTracker::Utilities             qw( :string);

sub handler {
    my $handler = XTracker::Handler->new(shift);

    my @levels    = split( /\//, $handler->{data}{uri} );

    # check for any variances to highlight in the side nav
    my $variance_highlight = "";
    my $vars    = get_stock_count_variances_count($handler->{dbh});
    if ( $vars ) {
        $variance_highlight = "&nbsp;+&nbsp;(".$vars.")";
    }

    # TT data set
    $handler->{data}{content}           = 'stocktracker/perpetual_inventory/count_variant.tt';
    $handler->{data}{section}           = 'Stock Control';
    $handler->{data}{subsection}        = 'Perpetual Inventory';
    $handler->{data}{subsubsection}     = 'Item Count';
    $handler->{data}{sidenav}           = [
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

    # Set up ACTION destination for FORM
    $handler->{data}{form_submit}           = '/'.$levels[1].'/'.$levels[2].'/CountVariant';
    $handler->{data}{form_submit_complete}  = '/'.$levels[1].'/'.$levels[2].'/ProcessStockCount';

    # remove most of the left nav links if not a "manager" auth level
    if ($handler->auth_level < 3) {
        $handler->{data}{sidenav} = [{
            "None" => [
                {   'title' => 'Overview',
                    'url'   => "/StockControl/PerpetualInventory"
                },
                {   'title' => 'Process Stock Count',
                    'url'   => "/StockControl/PerpetualInventory/CountVariant"
                }
            ]}
        ];
    }

    # gather form data
    my $mismatch        = $handler->{param_of}{'mismatch'};                             # Mismatch Flag indicating the user needs to re-input a stock count
    my $process_type    = $handler->{param_of}{'process_type'};                         # default process type is auto feed - overidden in url to manual
    my $handheld        = $handler->{param_of}{'handheld'};                             # page accessed via HandHeld
    my $var_id          = $handler->{param_of}{'variant_id'};                           # variant_id being counted
    my $location        = $handler->{param_of}{'location'};                             # location being counted
    my $group_id        = $handler->{param_of}{'group_id'};                             # possible group id hidden field
    my $round           = $handler->{param_of}{'round'} || 1;                           # possible round of counting
    my $redirect_type   = $handler->{param_of}{'redirect_type'};                        # what type of page we need to redirect back to
    my $redirect_id     = $handler->{param_of}{'redirect_id'};                          # id of whatever record we need to redirect back to

    my $sku_location; # optional SKU / Location entered
    if ( $handler->{param_of}{'sku_location'} // 0 ) {
        $sku_location    = uc( trim( $handler->{param_of}{'sku_location'} ) );
    }

    # use handheld template & side nav if required
    if ($handler->{data}{handheld} == 1) {
        $handler->{data}{content}   = 'stocktracker/perpetual_inventory/handheld_count_variant.tt';
        $handler->{data}{view}      = 'HandHeld';
        $handler->{data}{sidenav}   = "";
    }

    # if no var id but we have a SKU / Location entered by user then get var id from SKU
    if (!$var_id && $sku_location){

        # if value entered is a sku, get the variant_id for the sku
        if ($sku_location =~ m{^\d+-\d+$}){
            $var_id = get_variant_by_sku($handler->{dbh}, $sku_location);
            unless ( $var_id ) {
                xt_warn( "Variant $sku_location not found." );
                return $handler->redirect_to($handler->path)
            }
        }
        # if value entered is a location, get the nearest stock count job
        else {
            if ( matches_iws_location($sku_location) ) {
                xt_warn("Location $sku_location may not be listed");
                return $handler->redirect_to($handler->path)
            }
            else {
                ($var_id, $location) = get_stock_count_by_location($handler->{dbh}, $sku_location);
                unless ( $location ) {
                    xt_warn( "Location $sku_location not found" );
                    return $handler->redirect_to($handler->path)
                }
            }
        }
    }

    # set data for use on the page
    $handler->{data}{mismatch}                      = ($mismatch ? 1 : 0);
    $handler->{data}{stock_count}{process_type}     = $process_type;
    $handler->{data}{stock_count}{variant_id}       = $var_id;
    $handler->{data}{stock_count}{sku}              = $sku_location;
    $handler->{data}{stock_count}{location}         = $location;
    $handler->{data}{stock_count}{group_id}         = $group_id;
    $handler->{data}{stock_count}{round}            = $round;
    $handler->{data}{stock_count}{redirect_type}    = $redirect_type;
    $handler->{data}{stock_count}{redirect_id}      = $redirect_id;

    if ($var_id) {
        $handler->{data}{variant}   = get_variant_product_data($handler->{dbh}, $var_id);
        $handler->{data}{product_id}= $handler->{data}{variant}{product_id};
        $handler->add_to_data( get_product_summary( $handler->{schema}, $handler->{data}{product_id} ) );
    }

    $handler->process_template( undef );

    return OK;
}

1;
