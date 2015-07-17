package XTracker::Stock::Actions::CreateManualStockCount;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Database::Stock           qw( create_stock_count_variant );
use XTracker::Error;

sub handler {
    my $handler     = XTracker::Handler->new( shift );

    my $ret_params  = "";

    ## gather form data
    my $sku      = $handler->{param_of}{'sku'};      ## SKU entered user
    my $location = $handler->{param_of}{'location'}; ## location entered by user
    my $var_id   = $handler->{param_of}{'var_id'};   ## variant id from hidden form field

    if ( $var_id && $sku && $location) {

        eval {
            create_stock_count_variant($handler->{dbh}, $var_id, $location, "Manual");
            xt_success("The stock count request for PID/SKU: $sku Location: $location has been successfully placed.");
        };

        if ($@) {
            xt_warn($@);
        }
    }

    return $handler->redirect_to("/StockControl/PerpetualInventory/RequestCount".$ret_params);
}

1;
