package XTracker::Stock::Actions::SetSampleGoodsIn;

use strict;
use warnings;
use Carp;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Database::Shipment;
use XTracker::Database::Stock qw( :DEFAULT check_stock_location );
use XTracker::Utilities qw( url_encode );
use XTracker::Constants::FromDB qw( :flow_status );
use XTracker::Error;

my @delivered_shipments;
my $any_shipment_received;

### Subroutine : handler                        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# tt-template  :                                  #
# tt-variables :                                  #

sub handler {

    my $handler = XTracker::Handler->new( shift );

    my $ret_params  = "";

    if ( scalar keys(%{ $handler->{param_of} }) ) {
        @delivered_shipments   = ();
        $any_shipment_received = 0;
        eval {
            my $schema = $handler->{schema};

            $schema->txn_do(sub{
                foreach my $item ( keys %{ $handler->{param_of} } ) {

                    my @parts = split /-/, $item;
                    next if (@parts != 3);

                    my ( $type, $id, $channel_id )  = @parts;

                    _book_in_stock($schema, $id, $channel_id);
                }
            });
        };

        if($@){
            xt_warn($@);
        }
        else{
            xt_success('Stock Received') if $any_shipment_received;
            if (scalar @delivered_shipments) {
                my $message = 'Shipments already received: ' .
                            join(', ', @delivered_shipments);

                xt_warn($message);
            }
        }
    }

    # redirect to Sample Summary
    my $loc = "/StockControl/Sample/GoodsIn";

    return $handler->redirect_to( $loc.$ret_params );
}


### Subroutine : _book_in_stock                 ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub _book_in_stock {

    my ($schema, $shipment_id, $channel_id)    = @_;

    my $dbh = $schema->storage->dbh;

    ### update shipment as 'delivered'
    my $shipment = $schema->resultset('Public::Shipment')->find( $shipment_id );

    # if someone clicks submit button twice by mistake, dont do anything
    if ($shipment->delivered) {
        push @delivered_shipments, $shipment_id;
        return undef;
    }

    $shipment->update({ delivered => 1 });
    ### get shipment items
    my $ship_items = get_shipment_item_info( $dbh, $shipment_id );

    foreach my $ship_item_id ( keys %{ $ship_items } ) {

        # set a variable to display success message
        $any_shipment_received = 1;

        my $var_id = $$ship_items{$ship_item_id}{variant_id};
        ### remove 'Transfer Pending' location
        update_quantity($dbh, {
            "variant_id"        => $var_id,
            "location"          => "Transfer Pending",
            "quantity"          => -1,
            "type"              => 'dec',
            "channel_id"        => $channel_id,
            current_status_id   => $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS,
        });

        ### check if transfer pending location now 0 - delete it if it is
        if ( get_stock_location_quantity( $dbh, { "variant_id" => $var_id,
                                                  "location"   => "Transfer Pending",
                                                  "channel_id" => $channel_id,
                                                  status_id  => $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS,
                                                }) <= 0 ) {
            delete_quantity($dbh, { "variant_id" => $var_id,
                                    "location"   => "Transfer Pending",
                                    "channel_id" => $channel_id,
                                    status_id  => $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS,
                                });
        }

        ### insert 'Sample' location
        if (check_stock_location($dbh, { "variant_id" => $var_id,
                                         "location" => "Sample Room",
                                         "channel_id" => $channel_id,
                                         status_id => $FLOW_STATUS__SAMPLE__STOCK_STATUS,
                                         }) > 0){
            update_quantity($dbh, { "variant_id" => $var_id,
                                    "location"   => "Sample Room",
                                    "quantity"   => 1,
                                    "type"       => 'inc',
                                    "channel_id" => $channel_id,
                                    current_status_id   => $FLOW_STATUS__SAMPLE__STOCK_STATUS,
 });
        }
        else {
            insert_quantity($dbh, { "variant_id" => $var_id,
                                    "location"   => "Sample Room",
                                    "quantity"   => 1,
                                    "channel_id" => $channel_id,
                                    initial_status_id => $FLOW_STATUS__SAMPLE__STOCK_STATUS,
                                });
        }

    }
}

1;
