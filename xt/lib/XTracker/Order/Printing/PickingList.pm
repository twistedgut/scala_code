package XTracker::Order::Printing::PickingList;

use strict;
use warnings;
use Perl6::Export::Attrs;

use Carp;

use XT::Rules::Solve;
use XTracker::Barcode;
use XTracker::PrintFunctions;

use XTracker::Database::Address;
use XTracker::Database::Customer;
use XTracker::Database::Product            qw(:DEFAULT);
use XTracker::Database::Order            qw( :DEFAULT );
use XTracker::Database::Shipment        qw( :DEFAULT );
use XTracker::Database::StockTransfer    qw( get_stock_transfer );
use XTracker::Database::Stock;
use XTracker::Database::Channel            qw( get_channel_details );

use XTracker::Config::Local                qw( config_var );
use XTracker::Constants::FromDB qw(
    :flow_status
    :shipment_item_status
    :shipment_status
);

sub generate_picking_list :Export(:DEFAULT) {
    my ( $schema, $shipment_id ) = @_;

    croak "Picking lists are only supported by this DC"
        unless config_var('Fulfilment', 'requires_picksheet');

    my $data;
    $data->{SHIPMENT_ITEM_STATUS__NEW}=$SHIPMENT_ITEM_STATUS__NEW;
    $data->{SHIPMENT_ITEM_STATUS__SELECTED}=$SHIPMENT_ITEM_STATUS__SELECTED;

    $data->{shipment_id} = $shipment_id;
    my $shipment = $schema->resultset('Public::Shipment')->find($shipment_id);

    ### get order/shipment info
    my $dbh = $schema->storage->dbh;
    $data->{shipment}         = get_shipment_info( $dbh, $data->{shipment_id} );
    $data->{shipment_address} = get_address_info( $dbh, $data->{shipment}{shipment_address_id} );
    $data->{shipment_items}   = get_shipment_item_info( $dbh, $data->{shipment_id} );
    $data->{shipment_notes}   = get_shipment_notes( $dbh, $data->{shipment_id} );
    my $shipment_log          = get_shipment_status_log( $dbh, $data->{shipment_id} );

    # check if customer order
    my $order_id              = get_shipment_order_id( $dbh, $data->{shipment_id} );

    if ($order_id) {
        my $order              = get_order_info( $dbh, $order_id );
        $data->{customer}      = get_customer_info( $dbh, $order->{customer_id} );
        $data->{sales_channel} = $order->{sales_channel};
    }
    # must be a stock transfer shipment
    else {
        my $stock_transfer_id      = get_shipment_stock_transfer_id( $dbh, $data->{shipment_id} );
        $data->{stock_transfer}    = get_stock_transfer( $dbh, $stock_transfer_id );
        $data->{sales_channel}     = $data->{stock_transfer}{sales_channel};
    }

    # loop through shipment items to sort out Location display and sorting
    foreach my $shipment_item_id ( keys %{ $data->{shipment_items} } ) {
        my $shipment_item = $schema->resultset('Public::ShipmentItem')
                                   ->find($shipment_item_id);
        my $variant_id = $data->{shipment_items}{$shipment_item_id}{variant_id};

        # don't want Virtual Vouchers
        next if $shipment_item->is_virtual_voucher;

        # we don't want items that have already been picked
        next unless $shipment_item->is_pre_picked;

        # get locations for item
        my $stock_ref = XTracker::Database::Stock::get_located_stock( $dbh, {
            'type'  => 'variant_id',
            'id'    => $variant_id,
            exclude_prl => 1,
            exclude_iws => 1
        }, 'stock_main',);
        my $stock_locations = $stock_ref->{ $data->{sales_channel} }{ $variant_id };

        # get the number of selected but not picked lines for this variant,
        # excluding those for the current shipment
        my $selected_stock_count = $shipment_item->selected_outside_of_shipment->count;

        my $total_quantity_count = 0;
        $total_quantity_count
            += $stock_locations->{$_}{$FLOW_STATUS__MAIN_STOCK__STOCK_STATUS}{quantity}
                for keys %$stock_locations;

        # if we have no stock for this variant or it's all selected set
        # location to 'Unknown' and check the next item
        if ( !(keys %{ $stock_locations||{} }) || $selected_stock_count >= $total_quantity_count ) {
            $data->{locations}{$shipment_item_id}{primary}{location} = "Unknown";
            next;
        }

        # Return locations with the SKU (ordered by smallest quantity)
        my @locations = map {[
            $_,
            $stock_locations->{$_->id}{$FLOW_STATUS__MAIN_STOCK__STOCK_STATUS}{quantity}
        ]} sort {
            ( $stock_locations->{$a->id}{$FLOW_STATUS__MAIN_STOCK__STOCK_STATUS}{quantity}
          <=> $stock_locations->{$b->id}{$FLOW_STATUS__MAIN_STOCK__STOCK_STATUS}{quantity}
            )
         || $a->location eq $b->location
        } $schema->resultset('Public::Location')
                 ->search({id => {-in => [keys %$stock_locations]} })
                 ->all;

        # We have a bug here which we're not fixing as part of WHM-4314 (it's
        # apparently been here forever), where we don't take into account where
        # we are in the loop. So if we're picking 2 of the same item, we'll
        # always return the first available location, even if it has just one
        # item in it
        my $location = _location_from_index(\@locations, $selected_stock_count);

        if ( $location ) {
            my $dc_loc = sprintf('%02d', config_var('DistributionCentre', 'name') =~ m{(\d+$)});
            my $display_location
                = $location->location =~ m{$dc_loc(\d+)(\w{1})-(\d{4})(\w{1})}
                ? "$1-$2-$3-$4"
                : 'Unknown';

            # set primary location for item
            $data->{locations}{$shipment_item_id}{primary}{location} = $display_location;
            $data->{locations}{$shipment_item_id}{primary}{quantity}
                = $stock_locations->{$location->id}{$FLOW_STATUS__MAIN_STOCK__STOCK_STATUS}{quantity};
        } else {
            $data->{locations}{$shipment_item_id}{primary}{location} = 'Unknown';
            $data->{locations}{$shipment_item_id}{primary}{quantity} = 0;
        }
    }

    # loop through locations for all items in shipment and sort into logical
    # order for display on picking list
    foreach my $item_id ( keys %{ $data->{locations} } ) {

        # Channelisation Note: We did have a DC1 branch here
        # check for DC2 format location
        if (${$data}{locations}{$item_id}{primary}{location} =~ m{(\d+)-(\w{1})-(\d{4})-(\w{1})}){
            # put item into ordered locations hash using location as keys
            $data->{ordered_locations}{$1}{$2}{$3}{$4}{$item_id} = 1;
        }
        # no match on location format
        else {
            $data->{ordered_locations}{1}{A}{1}{A}{$item_id} = 1;
        }
    }

    # credit check and release dates
    my $check_date   = "";
    $data->{release_date} = "";

    # go through the shipment log in date order to get the ones we need
    foreach my $id ( sort keys %{$shipment_log} ) {

        # credit check date
        if ( $shipment_log->{$id}{shipment_status_id} == $SHIPMENT_STATUS__FINANCE_HOLD ) {
            $check_date = $shipment_log->{$id}{display_date};
        }

        # release date
        if ( $shipment_log->{$id}{shipment_status_id} == $SHIPMENT_STATUS__PROCESSING ) {
            $data->{release_date} = $shipment_log->{$id}{display_date};
        }
    }

    # no need to store release date if not check date set
    if ( $check_date eq "" ) {
        $data->{release_date} = "";
    }

    # workout correct picking list class to display
    $data->{list_class} = $shipment->list_class;

    # print date for document
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst )= localtime(time);
    $data->{print_date}= $mday . "-" . ($mon+1) . "-" . ($year + 1900) . " " . $hour . ":" . $min;

    ### create barcode if necessary
    my $barcode = create_barcode("pickorder".$data->{shipment_id}, $data->{shipment_id}, "small", 3, 1, 65);

    ### printing of list
    my $result = 0;

    ### get the printer based on the printer type and sales channel
    my $channel_info      = get_channel_details( $dbh, $data->{sales_channel} );

    my $printer = XT::Rules::Solve->solve(
        'PickSheet::select_printer' => {
            'Shipment::is_transfer' => $shipment,
            'Shipment::is_premier' => $shipment,
            'Shipment::is_staff' => $shipment,
            'Business::config_section' => $channel_info->{config_section},
            -schema => $schema,
        },
    );
    my $printer_info = get_printer_by_name(
        config_var('DefaultPickingPrinters', $printer )
    ) || die "Could not find config value for picking printer $printer";

    if ( %{$printer_info||{}} ) {
        my $html = create_document(
            "pickinglist-$data->{shipment_id}", 'print/pickinglist.tt', $data );

        log_shipment_document(
            $dbh, $data->{shipment_id},
            'Picking List',
            "pickinglist-$data->{shipment_id}",
            $printer_info->{name}
        );

        $result = print_document(
            "pickinglist-$data->{shipment_id}",
            $printer_info->{lp_name},
            1, '', ''
        );
    }

    return 1;
}

sub _location_from_index {
    my ( $location_array, $index ) = @_;

    my @locations_exploded;
    for ( @$location_array ) {
        my ( $location, $count ) = @$_;
        push( @locations_exploded, $location ) for 1 .. $count;
    }

    return $locations_exploded[ $index ];
}

1;
