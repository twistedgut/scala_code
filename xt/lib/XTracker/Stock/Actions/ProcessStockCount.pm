package XTracker::Stock::Actions::ProcessStockCount;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Database::Stock           qw( get_stock_count set_stock_count check_stock_count_complete get_stock_location_quantity set_last_count_date
                                                                                delete_quantity check_stock_count_variant create_stock_count_variant check_stock_count_variance
                                                                                update_stock_count );
use XTracker::Database::Logging         qw( log_stock log_location );
use XTracker::Database::Product         qw( get_product_summary get_variant_product_data );
use XTracker::Database::Channel         qw( get_channels );
use XTracker::Database::Utilities   qw( is_valid_database_id );
use XTracker::Constants::FromDB         qw( :stock_count_origin :stock_count_status :flow_status );
use XTracker::Utilities                         qw( url_encode );
use XTracker::Error;

sub handler {

    # set up Handler
    my $handler     = XTracker::Handler->new( shift );

    my @levels              = split /\//, $handler->{data}{uri};

    # gather form data
    my $process_type    = $handler->{param_of}{'process_type'};                                                 # default process type is auto feed - overidden in url to manual
    my $view            = ( $handler->{param_of}{'view'} // '' );                       # page accessed via HandHeld
    my $var_id          = $handler->{param_of}{'variant_id'};                           # variant_id being counted
    my $location        = $handler->{param_of}{'location'};                             # location being counted
    my $group_id        = $handler->{param_of}{'group_id'};                             # possible group id hidden field
    my $round           = $handler->{param_of}{'round'} || 1;                           # possible round of counting
    my $finish          = $handler->{param_of}{'finish'};                               # finish count button for SKU scan counting
    my $counted         = $handler->{param_of}{'input_value'};                          # count entered by user
    my $redirect_type   = $handler->{param_of}{'redirect_type'};                        # what type of page we need to redirect back to
    my $redirect_id     = $handler->{param_of}{'redirect_id'};                          # id of whatever record we need to redirect back to

    my $origin_id       = $STOCK_COUNT_ORIGIN__MANUAL;                                  # origin of count - default to manual count


    # set up redirect url for use later - defaults back to count next variant - auto feeding counts
    my $redirect_location       = "/StockControl/PerpetualInventory/CountVariant";
    my $ret_params                  = "?sku_location=$location&view=$view";

    # manual counting set in URL - don't go to next count - go back to front page
    if ($process_type eq "manual") {
        $redirect_location      = "/StockControl/PerpetualInventory/CountVariant";
        $ret_params                     = "?process_type=manual&view=$view";
    }

    # redirect back to picking
    if ($redirect_type eq "Pick"){
        if ($handler->{data}{handheld} == 1){
            $redirect_location  = "/Fulfilment/Picking/PickShipment";
            $ret_params                     = "?view=HandHeld&shipment_id=$redirect_id";
        }
        else{
            $redirect_location = "/Fulfilment/Picking/PickShipment";
            $ret_params                     = "?shipment_id=$redirect_id";
        }

        $origin_id = $STOCK_COUNT_ORIGIN__PICKING;
    }

    # redirect back to returns put away
    if ($redirect_type eq "Return"){
        if ($handler->{data}{handheld} == 1){
            $redirect_location  = "/GoodsIn/Putaway";
            $ret_params                     = "?view=HandHeld";
        }
        else{
            $redirect_location  = "/GoodsIn/Putaway";
            $ret_params                     = "";
        }

        $origin_id = $STOCK_COUNT_ORIGIN__RETURNS;
    }

    my $schema = $handler->schema;
    my $dbh = $schema->storage->dbh;
    my $guard = $schema->txn_scope_guard;
    if ($var_id) {
        $handler->{data}{variant}       = get_variant_product_data($dbh, $var_id);
        $handler->{data}{product_id}= $handler->{data}{variant}{product_id};
        $handler->add_to_data( get_product_summary( $handler->{schema}, $handler->{data}{product_id} ) );
    }

    # form submitted - do stuff
    if ( $finish ) {
        eval {

            # quick check to see if we're counting a variant not on the list to be counted - we'll need to create it
            if (!check_stock_count_variant($dbh, $var_id, $location, 1)) {
                create_stock_count_variant($dbh, $var_id, $location, "Miscellaneous");
            }

            my $cur_stock           = undef;
            my $count_channel_id    = $handler->{data}{active_channel}{channel_id}; # what channel we're counting for - default to active channel of product
            my $channels            = get_channels($dbh);

            # get current stock level for SKU & location counted
            foreach my $channel_id ( keys %{ $channels } ) {
                my $stock       = get_stock_location_quantity($dbh, {
                    "variant_id" => $var_id,
                    "location" => $location,
                    "channel_id" => $channel_id,
                    status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
                });

                # set the channel id of the count to that of the matching stock
                # may not always be counting the active channel for a product
                if ( $stock ) {
                    $cur_stock          = $stock;
                    $count_channel_id   = $channel_id;
                }
            }

            if ($cur_stock == 0){ $cur_stock = "none"; }

            # record count
            my $check_id = set_stock_count($dbh,
                {
                    'variant_id'    => $var_id,
                    'location'      => $location,
                    'round'         => $round,
                    'cur_stock'     => $cur_stock,
                    'count'         => $counted,
                    'operator_id'   => $handler->operator_id,
                    'group'         => $group_id,
                    'origin_id'     => $origin_id
                }
            );

            # count complete
            if (check_stock_count_complete($dbh, $check_id)) {
                # complete the stock count - either log no variance or flag up variance to stock control
                _complete_stock_count($dbh, $check_id, $var_id, $location, $handler, $count_channel_id);

                $ret_params     .= ($ret_params =~ /^\?/ ? '&' : '?');
                xt_success("Stock Count for SKU: ".$handler->{data}{variant}{sku}." Updated.");
            }
            # count incomplete - count didn't match expected
            else {
                # get count info for page
                my $stock_count = get_stock_count($dbh, $check_id);
                my $sep                 = '';
                my %usethese    = qw(
                    variant_id              1
                    group_id                1
                );

                $redirect_location      = '/'.$levels[1].'/'.$levels[2].'/CountVariant';
                $ret_params                     = '?';

                # Get recent stock count details into parameters to pass back
                foreach ( keys %$stock_count ) {
                    next            if (!exists $usethese{$_});
                    $ret_params     .= $sep.$_.'='.$stock_count->{$_};
                    $sep            = '&';
                }

                # set flag for message on screen
                $ret_params     .= "&mismatch=1";

                # increment round of counting
                $ret_params     .= "&round=".($round + 1);

                $ret_params     .= "&redirect_type=".$redirect_type;
                $ret_params     .= "&redirect_id=".$redirect_id;
                $ret_params     .= "&process_type=".$process_type;
                $ret_params     .= "&location=".$location;
                $ret_params     .= "&view=".$view;
            }

            $guard->commit();
        };

        if ($@) {
            $redirect_location      = '/'.$levels[1].'/'.$levels[2].'/CountVariant';

            $ret_params      = "?variant_id=".$var_id;
            $ret_params     .= "&location=".$location;
            $ret_params     .= "&group_id=".$group_id;
            $ret_params     .= "&round=".$round;
            $ret_params     .= "&redirect_type=".$redirect_type;
            $ret_params     .= "&redirect_id=".$redirect_id;
            $ret_params     .= "&process_type=".$process_type;
            $ret_params     .= "&view=".$view;
            xt_warn($@);
        }
    }
    else {
        $redirect_location      = '/'.$levels[1].'/'.$levels[2].'/CountVariant';
        $ret_params                     = '?view='.$view;
    }

    return $handler->redirect_to($redirect_location.$ret_params);
}

# complete a stock count - either log no variance or flag up variance to stock control
sub _complete_stock_count {

    my ( $dbh, $count_id, $var_id, $location, $handler, $channel_id )   = @_;

    # flag to check for variance between counted and expected quantity
    my $variance        = 0;

    # var to keep track of the final counted quantity
    my $count           = 0;

        # Get counted quantity and any variance between counted & expected quantities
        ($count,$variance)      = check_stock_count_variance($dbh,$count_id);

    # no variance found - just log it in stock log
    if ($variance == 0) {
        # log the stock count
        log_stock($dbh, { "variant_id" => $var_id, "action" => 12, "quantity" => 0, "operator_id" => $handler->operator_id, "notes" => $location, "channel_id" => $channel_id });

        # update stock count group as complete
        update_stock_count($dbh,{ status_id => $STOCK_COUNT_STATUS__ACCEPTED, type => 'all_group', type_id => $count_id });

        # if the stock level counted was 0 we can delete the location entry
        if ($count == 0){
            log_location($dbh, { "variant_id" => $var_id, "old_loc" => $location, "operator_id" => $handler->operator_id, "channel_id" => $channel_id } );
            delete_quantity($dbh, {
                "variant_id" => $var_id,
                "location" => $location,
                "channel_id" => $channel_id,
                status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
            } );
        }
    }
    # variance found - leave for Stock Control to investigate
    else {
        # update last stock count to 'Pending Investogation'
        update_stock_count($dbh,{ status_id => $STOCK_COUNT_STATUS__PENDING_INVESTIGATION, type => 'id', type_id => $count_id });
    }

    # set the last count date for this variant and location
    set_last_count_date($dbh, $var_id, $location);
}

1;
