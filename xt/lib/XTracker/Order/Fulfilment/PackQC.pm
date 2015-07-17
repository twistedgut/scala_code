package XTracker::Order::Fulfilment::PackQC;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Constants::FromDB     qw( :shipment_item_status :flow_status );
use XTracker::Database::Stock       qw( get_located_stock );

use XTracker::Image                 qw( get_images );

sub handler {
    my $handler = XTracker::Handler->new(shift);

    my $schema              = $handler->{schema};

    # get params
    $handler->{param_of}{shipment_id} =~ s{\s+}{}g;
    my $shipment_id     = $handler->{param_of}{shipment_id};
    my $qc_inprogress   = $handler->{param_of}{qc_inprogress};
    my $qc_voucher_code = $handler->{param_of}{voucher_code};

    my $itemtoqc_count  = 0;
    my $qceditem_count  = 0;
    my $qced_codes      = {};
    my $qced_items      = {};
    if ( $qc_inprogress && exists( $handler->session->{pack_qc} ) ) {
        $qced_codes = $handler->session->{pack_qc}{qced_codes};
        $qced_items = $handler->session->{pack_qc}{qced_items};
    }

    my $shipment        = $schema->resultset('Public::Shipment')->find( $shipment_id );
    my $shipment_items  = $shipment->shipment_items->search(
        {
            is_physical => 1,
            shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PICKED,
        },
        {
            join    => [ { voucher_variant => 'product' } ],
            order_by=> 'me.id',
        }
    );

    # set-up main data hash for TT
    $handler->{data}{content}       = 'ordertracker/fulfilment/packqc.tt',
    $handler->{data}{section}       = 'Fulfilment';
    $handler->{data}{subsection}    = 'Packing';
    $handler->{data}{subsubsection} = 'Pack QC';
    $handler->{data}{sidenav}       = [ { 'None' => [ { title => 'Back', url => '/Fulfilment/Packing' } ] } ];
    $handler->{data}{sales_channel} = $shipment->order->channel->name;

    $handler->{data}{shipment_id}   = $shipment_id;

    # do we have a voucher code to QC
    if ( $qc_voucher_code ) {
        my $result  = $shipment_items->check_voucher_code( {
            for         => 'qc',
            vcode       => $qc_voucher_code,
            chkd_codes  => $qced_codes,
            chkd_items  => $qced_items,
        } );
        if ( !$result->{success} ) {
            $handler->{data}{input_err} = $result->{err_msg};
            $handler->{data}{err_code}  = $qc_voucher_code;
        }
    }

    # get all vouchers to QC
    my @ship_items  = $shipment_items->all;
    foreach my $item ( @ship_items ) {

        # get the stock location for the Voucher
        my $location    = "Unknown";
        my $stock_locations = get_located_stock(
                $schema->storage->dbh,
                { type => 'variant_id', id => $item->voucher_variant_id },
                'stock_main'
            )->{ $handler->{data}{sales_channel} }{ $item->voucher_variant_id };
        # only want MAIN stock locations
        foreach (
            sort {
                $stock_locations->{$a}{$FLOW_STATUS__MAIN_STOCK__STOCK_STATUS}{quantity}
            <=> $stock_locations->{$b}{$FLOW_STATUS__MAIN_STOCK__STOCK_STATUS}{quantity}
             || $a <=> $b
            } grep {
                exists( $stock_locations->{$_}{ $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS } )
            } keys %{ $stock_locations }
        ) {
            my $stck_loc    = $stock_locations->{$_}{ $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS };
            if ( $stck_loc->{quantity} > 0 ) {
                # only one location needed with the lowest quantity
                # but is > zero
                $location   = $stck_loc->{location};
                last;
            }
        }

        my $ttdata  = {
            id          => $item->id,
            product_id  => $item->voucher_variant->voucher_product_id,
            designer    => $item->voucher_variant->product->designer,
            name        => $item->voucher_variant->product->name,
            sku         => $item->voucher_variant->sku,
            location    => $location,
            image       => get_images({
                product_id => $item->voucher_variant->voucher_product_id,
                live => 1,
                schema => $schema,
            }),
        };
        if ( exists $qced_items->{ $item->id } ) {
            $qceditem_count++;
            $handler->{data}{qced_shipitems}{ $item->id }   = $ttdata;
        }
        else {
            $itemtoqc_count++;
            $handler->{data}{shipitems_to_qc}{ $item->id }  = $ttdata;
        }
    }

    $handler->session->{pack_qc}{qced_codes}    = $qced_codes;
    $handler->session->{pack_qc}{qced_items}    = $qced_items;

    $handler->{data}{itemtoqc_count}    = $itemtoqc_count;
    $handler->{data}{qceditem_count}    = $qceditem_count;
    $handler->{data}{qc_complete}       = 0;
    if ( $itemtoqc_count == 0 && $qceditem_count == scalar( @ship_items ) ) {
        $handler->{data}{qc_complete}   = 1;
        $handler->{data}{display_msg}   = "QC'ing Now Complete";
    }

    return $handler->process_template;
}

1;
