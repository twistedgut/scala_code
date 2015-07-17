package XTracker::Stock::Actions::SetSampleGoodsOut;

use strict;
use warnings;
use Carp;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Database::Shipment        qw( :DEFAULT get_original_sample_shipment_id get_sample_shipment_return_pending );
use XTracker::Database::Stock           qw( :DEFAULT check_stock_location get_stock_location_quantity);
use XTracker::Utilities                 qw( url_encode );
use XTracker::Constants::FromDB qw(
    :flow_status
    :customer_issue_type
);
use XTracker::Error;


### Subroutine : handler                        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# tt-template  :                                  #
# tt-variables :                                  #

sub handler {

    my $handler = XTracker::Handler->new( shift );

    my $rma;
    my $ret_url     = "";
    my $ret_params  = "";

    $handler->{dbh} = $handler->{schema}->storage->dbh;

    if ( scalar keys(%{ $handler->{param_of} }) ) {

        my @book_out_failed_variants;
        my $counter = 0;
        $handler->{schema}->txn_begin();
        eval {
            foreach my $item ( keys %{ $handler->{param_of} } ) {
                if ( $item =~ m/^return/ ) {

                    my ($ret,$therest)  = split( /_/, $handler->{param_of}{$item} );

                    if ($ret eq 'return') {
                        my @parts   = split( /-/, $therest );
                        next        if ( @parts != 3 );

                        my ( $variant_id, $location_id, $channel_id )   = @parts;

                        my $quantity    = $handler->{param_of}{"quantity_".$variant_id."-".$location_id."-".$channel_id} || 1;

                        ## get available quantity of the specified variant
                        my $stock_location_quantity = get_stock_location_quantity( $handler->{schema}, {
                            variant_id  => $variant_id,
                            location_id => $location_id,
                            channel_id  => $channel_id,
                            status_id   => $FLOW_STATUS__SAMPLE__STOCK_STATUS
                        } );

                        ## fail if stock_location_quantity quantity is insufficient to fulfil request
                        if ( $stock_location_quantity < $quantity ) {
                            push @book_out_failed_variants, $variant_id;
                            next;
                        }

                        $rma    = _book_out_stock($handler, $variant_id, $handler->operator_id, $channel_id, $quantity);
                        $counter++;

                        $ret_params = "?variant_id=".$variant_id;
                    }
                }
            }
        };

        xt_warn('Following variants could not be booked out as quantity not available: ' . join ', ', @book_out_failed_variants)
            if (@book_out_failed_variants);

        my $e = $@;
        if ( $e || !$counter ) {
            $handler->{schema}->txn_rollback();

            $ret_params = "?".$handler->{param_of}{orig_type}."=".$handler->{param_of}{orig_type_id};

            if ($e) {
                xt_warn($@);
            }
            else {
                xt_success("Nothing Selected for Return");
            }
        }
        else {
            $handler->{schema}->txn_commit();

            $ret_params .= "&action=RMA";
            $ret_params .= "&rma=".$rma;
#           xt_success("Stock Returned");
        }
    }

    # redirect to Sample Summary
    $ret_url    = "/StockControl/Sample/ReturnStock";

    return $handler->redirect_to( $ret_url.$ret_params );
}


### Subroutine : _book_out_stock                ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub _book_out_stock {

    my ($handler, $variant_id, $operator_id, $channel_id, $quantity) = @_;
    my $dbh = $handler->{dbh};

    my ($rma_number, $shipment, $ship_item, @overflow);

    # find original sample shipment
    my $shipment_id = get_original_sample_shipment_id( $dbh, { 'type' => 'variant_id', 'id' => $variant_id, 'channel_id' => $channel_id } );

    # found sample shipment
    if ( $shipment_id ){
        $shipment = $handler->{schema}->resultset('Public::Shipment')->find($shipment_id);

        # loop through items and create return items for them - WILL ALWAYS BE ONE ITEM FOR SAMPLES
        ($ship_item, @overflow) = $shipment->shipment_items->all;

        if (@overflow) {
            Carp::confess "Creating a return for samples expects only one shipment"
                        . "item on shipment $shipment_id, but we got "
                        . scalar(@overflow)+1
        }

        my $return = $handler->domain('Returns')->create({
            shipment_id => $shipment_id,
            operator_id => $operator_id,
            pickup => 0,
            refund_type_id => 0, # No refund
            return_items => {
                $ship_item->id => {
                    reason_id => $CUSTOMER_ISSUE_TYPE__7__JUST_UNSUITABLE,
                    type => 'Return'
                }
            },
            send_email => 0,
            this_is_a_sample_return => 1,
        });

        $rma_number = $return->rma_number;
    }
    # couldn't find a sample shipment with status of dispatched
    # check for one with an outstanding RMA in case of a duplicate return request
    else {
        ($shipment_id, $rma_number) = get_sample_shipment_return_pending( $dbh, {
            'type' => 'variant_id',
            'id' => $variant_id
        } );

        if ( !$rma_number ){
            die "Could not find original sample transfer shipment for this SKU (variant_id $variant_id), please contact Service Desk";
        }

        $shipment = $handler->{schema}->resultset('Public::Shipment')->find($shipment_id);
        ($ship_item, @overflow) = $shipment->shipment_items->all;

        if (@overflow) {
            Carp::confess "Creating a return for samples expects only one shipment"
                        . "item on shipment $shipment_id, but we got "
                        . scalar(@overflow)+1
        }
    }

    ## decrement 'Sample Room' location
    update_quantity($dbh, {
        "variant_id" => $variant_id,
        "location" => 'Sample Room',
        "quantity" => ($quantity * -1),
        "type" => 'dec',
        "channel_id" => $channel_id,
        current_status_id => $FLOW_STATUS__SAMPLE__STOCK_STATUS,
        next_status_id => $FLOW_STATUS__SAMPLE__STOCK_STATUS,
    });

    ### check if Sample Room location now 0 - delete it if it is
    if ( get_stock_location_quantity( $dbh, { "variant_id" => $variant_id,
                                              "location" => "Sample Room",
                                              "channel_id" => $channel_id,
                                              status_id => $FLOW_STATUS__SAMPLE__STOCK_STATUS,
                                            } ) <= 0 ) {
        delete_quantity($dbh, {
            "variant_id" => $variant_id,
            "location" => "Sample Room",
            "channel_id" => $channel_id,
            status_id => $FLOW_STATUS__SAMPLE__STOCK_STATUS,
        });
    }

    ### insert or update 'Transfer Pending' location
    if (check_stock_location($dbh, { "variant_id" => $variant_id,
                                     "location" => "Transfer Pending",
                                     "channel_id" => $channel_id,
                                     status_id => $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS,
                                   }) > 0){
        update_quantity($dbh, {
            "variant_id" => $variant_id,
            "location" => "Transfer Pending",
            "quantity" => $quantity,
            "type" => 'inc',
            "channel_id" => $channel_id,
            current_status_id => $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS,
            next_status_id => $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS,
        });
    }
    else {
        insert_quantity($dbh, {
            "variant_id" => $variant_id,
            "location" => "Transfer Pending",
            "quantity" => $quantity,
            "channel_id" => $channel_id,
            initial_status_id   => $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS,
        });
    }

    return $rma_number;
}


1;

__END__


This module is a copy of XTracker::Stock::Actions::SetSampleGoodsIn;

It allows a user to return sample stock back from the Dome to DC1 via a customer return shipment.

andrew.mcGregor@net-a-porter.com
2006-02-06


