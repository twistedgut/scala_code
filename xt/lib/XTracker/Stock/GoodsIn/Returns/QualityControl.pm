package XTracker::Stock::GoodsIn::Returns::QualityControl;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Image;
use XTracker::Config::Local             qw( config_var );
use XTracker::Database::Return;
use XTracker::Database::Shipment;
use XTracker::Database::Order;
use XTracker::Database::Invoice;
use XTracker::Database::Product         qw( :DEFAULT );
use XTracker::Database::StockProcess;
use XTracker::Database::Delivery;
use XTracker::Database::StockTransfer   qw( get_stock_transfer );
use XTracker::Database::Location        qw( get_location_of_stock get_suggested_stock_location );

use XTracker::Constants::FromDB         qw( :business :stock_process_type :stock_process_status );

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    $handler->{data}{section}           = 'Goods In';
    $handler->{data}{subsection}        = 'Returns QC';
    $handler->{data}{subsubsection}     = '';
    $handler->{data}{content}           = 'stocktracker/goods_in/returns_in/qualitycontrol.tt';

    # This returns a redirection if no printer is selected
    return $handler->check_for_printer if $handler->check_for_printer;

    my $schema = $handler->schema;
    my $dbh = $schema->storage->dbh;

    # delivery id from for post or url
    if ( $handler->{request}->param('delivery_id') ) {
        $handler->{data}{delivery_id} = $handler->{request}->param('delivery_id');

        # check if RMA number submitted rather than delivery id
        if ($handler->{data}{delivery_id} =~ m/-/){
            $handler->{data}{delivery_id} =  get_delivery_id_by_rma($dbh, $handler->{data}{delivery_id});
        }
    }

    # get delivery info if id defined
    if ( $handler->{data}{delivery_id} ) {

        # page title
        $handler->{data}{subsubsection} = 'Process Return';

        # get delivery details
        _get_delivery_info( $handler );

        my $has_order_id = defined($handler->{data}{return}{shipment_info}{orders_id});
        my $orders_id = $has_order_id ? $handler->{data}{return}{shipment_info}{orders_id} : '';
        my $xfer_str = defined($handler->{data}{return}{stock_transfer}{id}) ? '&sample_xfer_id=' . $handler->{data}{return}{stock_transfer}{id} : '';
        my $return_id = $handler->{data}{return_id};
        my $delivery_id = $handler->{data}{delivery_id};

        # left nav links
        $handler->{data}{sidenav} = [{
            'None'  => [ {
                    title   => 'Back',
                    url     => '/GoodsIn/ReturnsQC'
                }, {
                    title   => 'Add Note',
                    url     => "/GoodsIn/ReturnsQC/Note?parent_id=$orders_id&note_category=Return&sub_id=$return_id&came_from=returns_qc$xfer_str&search_string=$delivery_id"
                },
            ]
        }];

        if ($has_order_id) {
            push(@{$handler->{data}{sidenav}->[0]->{None}}, {
                title   => 'Order Summary',
                url     => "/GoodsIn/ReturnsQC/OrderView?order_id=$orders_id"
            });
        }

    }
    # get all deliveries awaiting QC
    else {
          $handler->{data}{sidenav} = [{ None => [ {
            title => 'Set Return Station',
            url   => '/My/SelectPrinterStation?section=GoodsIn&subsection=ReturnsQC&force_selection=1',
        } ] }];
        my $deliveries  = XTracker::Database::Delivery->get_return_deliveries( $dbh, [
                                                                                    $STOCK_PROCESS_STATUS__NEW,
                                                                                    $STOCK_PROCESS_TYPE__MAIN,
                                                                                    $STOCK_PROCESS_STATUS__NEW,
                                                                                    $STOCK_PROCESS_TYPE__MAIN,
                                                                                ] );

        # get data into a channelised list
        foreach my $item ( @{ $deliveries } ){
            $handler->{data}{return_deliveries}{$item->{sales_channel}}{$item->{id}} = $item;
        }
    }

    return $handler->process_template;
}


sub _get_delivery_info {
    my ( $handler ) = @_;

    my $schema = $handler->schema;
    my $dbh = $schema->storage->dbh;

    $handler->{data}{return_id}              = get_return_id_by_delivery($dbh, $handler->{data}{delivery_id});
    $handler->{data}{return}                 = get_return_info($dbh, $handler->{data}{return_id});
    $handler->{data}{return}{return_items}   = get_return_item_info($dbh, $handler->{data}{return_id});
    $handler->{data}{return}{return_notes}   = get_return_notes($dbh, $handler->{data}{return_id});
    $handler->{data}{return}{shipment_info}  = get_shipment_info($dbh, $handler->{data}{return}{shipment_id});
    $handler->{data}{return}{shipment_items} = get_shipment_item_info($dbh, $handler->{data}{return}{shipment_id});
    $handler->{data}{return}{shipment_notes} = get_shipment_notes($dbh, $handler->{data}{return}{shipment_id});

    my $channel_id;
    if ($handler->{data}{return}{shipment_info}{orders_id}) {
        $handler->{data}{return}{order_info}    = get_order_info($dbh, $handler->{data}{return}{shipment_info}{orders_id});
        $handler->{data}{sales_channel}         = $handler->{data}{return}{order_info}{sales_channel};
        $channel_id                             = $handler->{data}{return}{order_info}{channel_id};
    }
    else {
        my $stock_transfer_id                       = get_shipment_stock_transfer_id($dbh, $handler->{data}{return}{shipment_id});
        $handler->{data}{return}{stock_transfer}    = get_stock_transfer($dbh, $stock_transfer_id);
        $handler->{data}{sales_channel}             = $handler->{data}{return}{stock_transfer}{sales_channel};
        $channel_id                                 = $handler->{data}{return}{stock_transfer}{channel_id};
    }

    # get current locations of stock
    foreach my $return_item_id ( keys %{$handler->{data}{return}{return_items}} ) {

        # get stock location or suggested stock location zone if can't find any
        my $suggested_location  = get_suggested_stock_location( $dbh, $handler->{data}{return}{return_items}{$return_item_id}{variant_id}, $channel_id );
        if ( defined $suggested_location ) {
            if ( $suggested_location->{type} ne "ZONE" ) {
                $handler->{data}{return}{return_items}{$return_item_id}{locations}  = $suggested_location->{location};
            }
            else {
                # format the ZONE locations to look a bit nicer on the page
                foreach ( 0..$#{$suggested_location->{location}} ) {
                    $suggested_location->{location}[$_]->{location}  .= config_var('Stock_Location', 'suggest_location');

#                    if ( config_var('DistributionCentre', 'name') ne 'DC2' ) {
#                        $suggested_location->{location}[$_]->{location}  .= "....";
#                    }
#                    else {
#                        $suggested_location->{location}[$_]->{location}  .= "-.....";
#                    }
                }
                $handler->{data}{return}{return_items}{$return_item_id}{locations}  = $suggested_location->{location};
            }
        }

    }

    # get product images & packing notes & current sales channel
    foreach my $item ( values %{$handler->{data}{return}{shipment_items}} ) {
        my $active_channel_name;
        my $product = $schema->resultset('Public::Product')->find($item->{product_id});
        $active_channel_name = $product->get_current_channel_name() if $product;
        $item->{active_channel} = $active_channel_name;

        $item->{ship_att} = get_product_shipping_attributes(
            $dbh,
            $item->{product_id}
        );

        $item->{image} = get_images({
            product_id => $item->{product_id},
            live => 1,
            schema => $handler->schema,
        });
        $item->{product} = $handler->schema->resultset('Public::Product')->find($item->{product_id});
    }

    # get stock process for return
    my $stock_ref = get_return_stock_process_items( $dbh, 'delivery_id', $handler->{data}{delivery_id} );

    foreach my $item ( @$stock_ref ){
        if ($item->{complete} == 0){
            $handler->{data}{return}{process_items}{$item->{return_item_id}} = $item;
        }
    }

    return;
}

1;
