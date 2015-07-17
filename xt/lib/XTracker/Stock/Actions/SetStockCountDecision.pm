package XTracker::Stock::Actions::SetStockCountDecision;

use strict;
use warnings;
use Carp;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Database              qw( get_database_handle );
use XTracker::Database::Logging     qw( log_stock log_location check_variance_transaction );
use XTracker::Comms::FCP            qw( update_web_stock_level );
use XTracker::Database::Stock       qw( delete_quantity insert_quantity update_quantity accept_stock_count_variance check_stock_location
                                        decline_stock_count_variance get_stock_location_quantity set_decline_stock_count delete_stock_count );
use XTracker::Database::Product     qw( product_present get_product_id );
use XTracker::Database::Channel     qw( get_channels );
use XTracker::Utilities             qw( url_encode );
use XTracker::Constants::FromDB     qw( :flow_status :pws_action );
use XTracker::Error;

sub handler {
    my $handler = XTracker::Handler->new( shift );

    ## gather form data

    my $count_id        = $handler->{param_of}{'count_id'};
    my $decision       = $handler->{param_of}{'decision'};
    my $variant_id      = $handler->{param_of}{'variant_id'};
    my $location        = $handler->{param_of}{'location'};
    my $location_id     = $handler->{param_of}{'location_id'};
    my $variance        = $handler->{param_of}{'variance'};
    my $notes           = $handler->{param_of}{'notes'};
    my $set_variance    = $handler->{param_of}{'set_variance'};
    my $new_count_id    = 0;

    my $ret_params      = "";


    if ($count_id) {
        my %dbh_web;

        ### book items in
        eval{

            my $schema = $handler->schema;
            my $dbh = $schema->storage->dbh;
            my $guard = $schema->txn_scope_guard;

            my $product_id  = get_product_id($dbh,{ type => 'variant_id', id => $variant_id });

            my $prod_chan_id;
                        my $product_row = $schema->resultset('Public::Product')->find($product_id);
                        $prod_chan_id = $product_row->get_current_channel_id() if $product_row;

            my $channels    = get_channels($dbh);

            # connect to each channel's WEB DB
            foreach ( keys %$channels ) {
                if(!$channels->{$_}{fulfilment_only})
                {
                    $dbh_web{$_} = get_database_handle( { name => 'Web_Live_'.$channels->{$_}{config_section}, type => 'transaction', } );
                }
            }

            my $success_message;
            # variance deleted - delete count from db
            if ($decision =~  m/Delete/ ) {
                delete_stock_count($dbh, $count_id);
                $success_message = "Variance Deleted.";
            }
            # variance accepted OR declined with manual override - do stock adjustments
            else {
                if ($decision =~  m/Accept/ || ($decision =~  m/Decline/ && $set_variance)) {

                    ### manual override entered - change variance value to user entered value
                    if ($decision =~  m/Decline/){
                        $variance   = $set_variance;

                        # create a stock count entry with actual variance
                        $new_count_id   = set_decline_stock_count($dbh, $count_id, $variance);
                    }

                    ## quick check for possible duplication of transaction
                    if (check_variance_transaction($dbh, $variant_id, $variance)) { die "duplicate transaction found"; }

                    my $is_located      = 0;

                    # loop over each channel to check if stock is located
                    foreach my $channel_id ( keys %{ $channels } ) {
                        my $located = check_stock_location( $dbh, {
                            "variant_id" => $variant_id,
                            "location" => $location,
                            "channel_id" => $channel_id,
                            status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
                        } );

                        if ( $located ) {
                            $is_located     = 1;
                            $prod_chan_id = $channel_id;
                        }
                    }

                    # XXX TODO check that not getting the channel from
                    # the location doesn't break anything

                    ## update xt stock level
                    if ( $is_located ) {
                        my $updtype = "inc";
                        $updtype    = "dec"         if ($variance < 0);

                        update_quantity( $dbh, {
                            "variant_id" => $variant_id,
                            "location_id" => $location_id,
                            "quantity" => $variance,
                            "type" => $updtype,
                            "channel_id" => $prod_chan_id,
                            current_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS } );
                    }
                    ## create quantity record
                    else {
                        if ($variance > 0) {
                            insert_quantity( $dbh, {
                                "variant_id" => $variant_id,
                                "location_id" => $location_id,
                                "quantity" => $variance,
                                "channel_id" => $prod_chan_id,
                                initial_status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS } );
                        }
                    }

                    ## log the stock level update
                    log_stock($dbh, { "variant_id" => $variant_id, "action" => 12, "quantity" => $variance, "operator_id" => $handler->operator_id, "notes" => $notes, "channel_id" => $prod_chan_id });

                    ## if product live on site update web stock level
                    if (product_present($dbh, { type => 'variant_id', id => $variant_id, channel_id => $prod_chan_id })){

                        if(!$channels->{$prod_chan_id}{fulfilment_only})
                        {
                            update_web_stock_level($dbh, $dbh_web{$prod_chan_id}, {"quantity_change" => $variance, "variant_id" => $variant_id } );
                        }

                        ## log web stock level update
                        $schema->resultset('Public::LogPwsStock')->log_stock_change(
                            variant_id      => $variant_id,
                            channel_id      => $prod_chan_id,
                            pws_action_id   => $PWS_ACTION__STOCK_COUNT,
                            quantity        => $variance,
                            notes           => $notes,
                            operator_id     => $handler->operator_id(),
                        );
                    }
                }
                else {
                    ### variance declined with NO manual override - log the zero variance
                    ####################################################
                    log_stock($dbh, { "variant_id" => $variant_id, "action" => 12, "quantity" => 0, "operator_id" => $handler->operator_id, "notes" => $notes, "channel_id" => $prod_chan_id });
                }


                ### delete quantity record if 0 stock level
                #######################################################

                ### get current stock level for SKU & location counted
                my $cur_stock   = get_stock_location_quantity($dbh, {
                    "variant_id" => $variant_id,
                    "location" => $location,
                    "channel_id" => $prod_chan_id,
                    status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
                });

                ### zero location quantity - delete it
                if ($cur_stock == 0){
                    log_location($dbh, { "variant_id" => $variant_id, "old_loc" => $location, "operator_id" => $handler->operator_id, "channel_id" => $prod_chan_id } );
                    delete_quantity($dbh, {
                        "variant_id" => $variant_id,
                        "location" => $location,
                        "channel_id" => $prod_chan_id,
                        status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
                    } );
                }


                ### accept or decline stock count
                #######################

                if ($decision =~  m/Accept/) {
                    ## update stock count group as 'Accepted'
                    accept_stock_count_variance($dbh, $count_id, $handler->operator_id);
                    $success_message = "Variance Accepted.";
                }
                elsif ($decision =~  m/Decline/ && $set_variance) {
                    # update newly created stock count as 'Declined'
                    accept_stock_count_variance($dbh, $new_count_id, $handler->operator_id);
                    $success_message = "Variance Declined &amp; New Variance Set.";
                }
                else {
                    ## update stock count group as 'Declined'
                    decline_stock_count_variance($dbh, $count_id, $handler->operator_id);
                    $success_message = "Variance Declined.";
                }
            }

            # Commit all WEB DB Transactions
            foreach ( keys %dbh_web ) {
                $dbh_web{$_}->commit();
            }

            $guard->commit();
            xt_success( $success_message );
        };
        if($@) {
            # Rollback all WEB DB Transactions
            foreach ( keys %dbh_web ) {
                $dbh_web{$_}->rollback();
            }

            xt_warn($@);
        }

        # Disconnect all WEB DB Transactions
        foreach ( keys %dbh_web ) {
            $dbh_web{$_}->disconnect();
        }
    }

    # redirect to Variance List
    my $loc = "/StockControl/PerpetualInventory/VarianceList";
    return $handler->redirect_to( $loc.$ret_params );
}

1;
