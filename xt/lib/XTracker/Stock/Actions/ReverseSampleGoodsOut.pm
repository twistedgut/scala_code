package XTracker::Stock::Actions::ReverseSampleGoodsOut;

use strict;
use warnings;
use Carp;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Database::Return;
use XTracker::Database::Channel                 qw( get_channels );
use XTracker::Database::Logging                 qw( &log_stock );
use XTracker::Database::Shipment                qw( :DEFAULT get_original_sample_shipment_id get_sample_shipment_return_pending );
use XTracker::Database::Stock                   qw( :DEFAULT check_stock_location );
use XTracker::Database::StockTransfer;
use XTracker::Constants::FromDB                 qw( :shipment_item_status
                                            :return_status
                                            :return_item_status
                                            :flow_status );
use XTracker::Utilities                                 qw( url_encode );
use XTracker::Error;

sub handler {
    my $handler     = XTracker::Handler->new( shift );

    my $ret_url     = "";
    my $ret_params  = "";


    if ( scalar keys(%{ $handler->{param_of} }) ) {

        eval {

            $ret_params = '?variant_id='.$handler->{param_of}{variant_id};

            my $variant_id = $handler->{param_of}{variant_id};
            my $channel_id = $handler->{param_of}{channel_id};
            my $quantity   = $handler->{param_of}{quantity};

            my $schema = $handler->schema;
            my $guard = $schema->txn_scope_guard;
            _reverse_book_out($schema->storage->dbh, $variant_id, $channel_id, $quantity, $handler->operator_id);
            $guard->commit();
            xt_success("Stock moved back to Sample Room");
        };
        if ( $@ ) {
            xt_warn($@);
        }
    }

    # redirect to Inventory
    $ret_url        = "/StockControl/Inventory/Overview";

    return $handler->redirect_to( $ret_url.$ret_params );
}

sub _reverse_book_out {

    my ($dbh, $variant_id, $channel_id, $quantity, $operator_id)        = @_;

        # find sample shipment info
    my ($shipment_id, $rma_number, $return_id) = get_sample_shipment_return_pending( $dbh, { 'type' => 'variant_id', 'id' => $variant_id } );

    # found sample shipment
        if ( !$shipment_id ){
                die 'Could not locate sample shipment for this SKU, please contact Service Desk';
        }
        # get shipment items and set back to dispatched
        my $shipment_item = get_shipment_item_info( $dbh, $shipment_id );
        foreach my $ship_item_id ( keys %{$shipment_item} ) {
                update_shipment_item_status( $dbh, $shipment_item->{$ship_item_id}{id}, $SHIPMENT_ITEM_STATUS__DISPATCHED );
                log_shipment_item_status( $dbh, $shipment_item->{$ship_item_id}{id}, $SHIPMENT_ITEM_STATUS__DISPATCHED, $operator_id );
        }

        # set return to cancelled
        update_return_status( $dbh, $return_id, $RETURN_STATUS__CANCELLED );
        log_return_status( $dbh, $return_id, $RETURN_STATUS__CANCELLED, $operator_id );

        # get return items and set to cancelled
        my $return_item = get_return_item_info( $dbh, $return_id );
        foreach my $ret_item_id ( keys %{$return_item} ) {
                update_return_item_status( $dbh, $return_item->{$ret_item_id}{id}, $RETURN_ITEM_STATUS__CANCELLED );
                log_return_item_status( $dbh, $return_item->{$ret_item_id}{id}, $RETURN_ITEM_STATUS__CANCELLED, $operator_id );
        }

        # move units back into Sample Room

        # decrement 'Transfer Pending' location
        update_quantity($dbh, { "variant_id" => $variant_id,
                            "location" => 'Transfer Pending',
                            "quantity" => ($quantity * -1),
                            "type" => 'dec',
                            "channel_id" => $channel_id,
                            current_status_id => $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS,
                           });

        # check if Transfer Pending location now 0 - delete it if it is
        if ( get_stock_location_quantity( $dbh, { "variant_id" => $variant_id,
                                              "location" => "Transfer Pending",
                                              "channel_id" => $channel_id,
                                              status_id => $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS,
                                            } ) <= 0 ) {
                delete_quantity($dbh, { "variant_id" => $variant_id,
                                "location" => "Transfer Pending",
                                "channel_id" => $channel_id,
                                status_id => $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS,
                              });
        }

        # insert or update 'Sample Room' location
        if (check_stock_location($dbh, { "variant_id" => $variant_id,
                                     "location" => "Sample Room",
                                     "channel_id" => $channel_id,
                                     status_id => $FLOW_STATUS__SAMPLE__STOCK_STATUS,
                                   }) > 0){
                update_quantity($dbh, { "variant_id" => $variant_id,
                                "location" => "Sample Room",
                                "quantity" => $quantity,
                                "type" => 'inc',
                                "channel_id" => $channel_id,
                                current_status_id => $FLOW_STATUS__SAMPLE__STOCK_STATUS,
                              });
        }
        else {
                insert_quantity($dbh, { "variant_id" => $variant_id,
                                "location" => "Sample Room",
                                "quantity" => $quantity,
                                "channel_id" => $channel_id,
                                initial_status_id   => $FLOW_STATUS__SAMPLE__STOCK_STATUS,
                              });
        }

    return;
}


1;

__END__


