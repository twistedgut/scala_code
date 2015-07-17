package XTracker::Stock::Actions::CreateSamplePurchaseOrder;

use strict;
use warnings;
use Carp;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Database::Product                 qw( get_variant_list create_sample_variant );
use XTracker::Database::PurchaseOrder   qw( :create get_purchase_order get_product );
use XTracker::Utilities                                 qw( url_encode );
use XTracker::Error;

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    my $return_url    = "/StockControl/Sample/PurchaseOrder";
    my $return_params = "?action=create";
    $return_params    .= "&po_id=".$handler->{param_of}{po_id};
    $return_params    .= "&orig_product_id=".$handler->{param_of}{orig_product_id} if (defined $handler->{param_of}{orig_product_id});
    $return_params    .= "&orig_variant_id=".$handler->{param_of}{orig_variant_id} if (defined $handler->{param_of}{orig_variant_id});

    if ( $handler->{param_of}{type} eq 'reallycreatesamplepo' ) {
        eval {
            my $po_id;
            $handler->schema->txn_do(sub{
                $po_id = _insert_purchase_order( $handler );
            });
            $return_url     = "/StockControl/PurchaseOrder/Overview";
            $return_params  = "?po_id=".$po_id;
            xt_success("Sample Purchase Order Created");
        };
        if ($@) {
            xt_warn($@);
        }
    }

    return $handler->redirect_to( $return_url.$return_params );
}

sub _insert_purchase_order {
    my $handler             = shift;

    my ( $po_data, $sampleproducts, $purchase_order_number );

    foreach my $key ( keys %{ $handler->{param_of} } ) {

        if ( $key eq 'sample_purchase_order' ) {
            $purchase_order_number = $handler->{param_of}{$key};
            die "sample purchase order number not found $handler->{param_of}{$key} $key" unless $handler->{param_of}{$key} =~m/^.+$/;
        }
        elsif ( $key =~m/^sample_(.*)-date_start_ship$/ ) {
            $sampleproducts->{$1}->{date_start_ship} = $handler->{param_of}{$key};
            die "start date not in a valid format" unless $handler->{param_of}{$key} =~m/^\d{4}-\d{2}-\d{2}$/;
        }
        elsif ( $key =~m/^sample_(.*)-date_cancel_ship$/ ) {
            $sampleproducts->{$1}->{date_cancel_ship} = $handler->{param_of}{$key};
            die "cancel date not in a valid format" unless $handler->{param_of}{$key} =~m/^\d{4}-\d{2}-\d{2}$/;
        }
        elsif ( $key =~m/^sample_(.*)-status$/ ) {
            $sampleproducts->{$1}->{status} = $handler->{param_of}{$key};
            die "status not found $handler->{param_of}{$key} $key" unless $handler->{param_of}{$key} =~m/^.+$/;
        }
        elsif ( $key =~m/^sample_(.*)_(.*)-ord$/ ) { # sample_12539_44100-ord  (sample_productId_variantId-ord)
            $sampleproducts->{variants}->{$2}->{ord} = $handler->{param_of}{$key}           if ($handler->{param_of}{$key} > 0);
        }

    }

    if ( !defined $sampleproducts->{variants} ) {
        die "No Products Ordered\n";
    }

    my $po_list     = get_purchase_order( $handler->{dbh}, $handler->{param_of}{"po_id"}, 'purchase_order_id' );    # get extra id's for below d/s
    my $products    = get_product( $handler->{dbh}, {
        type => 'purchase_order_id',
        id => $po_list->[0]{id},
        clause => 'stock_order_type',
        value => 'Main',
        results => 'array'
    } );

    foreach my $product ( @{ $products } ) {
        $product->{variants}    = get_variant_list( $handler->{dbh}, { type => 'product_id', id => $product->{product_id} } );
    }

    my $stock_orders        = [];

    foreach my $product ( @{ $products } ) {
        my $p                   = {};
        $p->{product_id}        = $product->{product_id};
        $p->{status_id}         = 1;
        $p->{start_ship_date}   = $product->{date_start_ship};
        $p->{cancel_ship_date}  = $product->{date_cancel_ship};
        $p->{start_ship_date}   = $sampleproducts->{$product->{product_id}}->{date_start_ship};
        $p->{cancel_ship_date}  = $sampleproducts->{$product->{product_id}}->{date_cancel_ship};
        $p->{stock_order_items} = ();
        $p->{comment}           = '';
        $p->{type_id}           = 3;
        $p->{consignment}       = 'false';

        my $yes = 0;

        foreach my $key ( %{$product->{variants}} ) {

            if ( $sampleproducts->{variants}->{$key}->{ord} ) {

                my $v;
                $v->{variant_id} = create_sample_variant( $handler->{dbh}, { variant_id => $product->{variants}{$key}{id} } );
                $v->{ordered}    = $sampleproducts->{variants}->{$key}->{ord};
                $v->{size}       = $sampleproducts->{variants}->{$key}->{size};
                $v->{type_id}    = 3;
                $yes             = 1;
                push @{$p->{stock_order_items}}, $v;

            }
        }

        push @$stock_orders, $p if $yes;
    }

    $po_data = {
        purchase_order_nr     => $purchase_order_number,
        description           => $po_list->[0]{description},
        designer_id           => $po_list->[0]{designer_id},
        status_id             => 1,
        comment               => $po_list->[0]{comment} || '',
        currency_id           => $po_list->[0]{currency_id},
        exchange_rate         => $po_list->[0]{exchange_rate},
        season_id             => $po_list->[0]{season_id},
        type_id               => 3,
        cancel                => 'false',
        supplier_id           => $po_list->[0]{supplier_id} || 0,
        act_id                => 0,
        confirmed             => 0,
        confirmed_operator_id => undef,
        placed_by             => '',
        stock_orders          => $stock_orders,
        channel_id            => $po_list->[0]{channel_id}
    };

    # Allow existing sample po's to be added to - EN-988
    my $existing_reorder_po_data = get_purchase_order( $handler->{dbh}, $purchase_order_number, 'purchase_order'  )->[0];

    # create sample po
    my $po_id;

    if ($existing_reorder_po_data) {
        $po_id = $existing_reorder_po_data->{id};
    } else {
        $po_id = create_purchase_order( $handler->{dbh}, $po_data );
    }
    die "Failed to Create Purchase Order\n" unless $po_id;

    #$logger->debug("Created PO $purchase_order_number");

    # create stock orders
    foreach my $so_ref ( @{ $po_data->{stock_orders} } ) {

        #$logger->debug("Created SO for $so_ref->{product_id}");

        my $so_id = create_stock_order(
            $handler->{dbh},
            $po_id,
            {
                product_id              => $so_ref->{product_id},
                start_ship_date         => $so_ref->{start_ship_date},
                cancel_ship_date        => $so_ref->{cancel_ship_date},
                status_id               => 1,
                comment                 => '',
                type_id                 => 3,
                consignment             => 0,
                cancel                  => 0,
                confirmed               => 0,
                shipment_window_type_id => 0,

            }
        );

        # create stock order items
        foreach my $soi_ref ( @{ $so_ref->{stock_order_items} } ) {
            #$logger->debug("Created SOI for $soi_ref->{variant_id}");

            create_stock_order_item (
                $handler->{dbh},
                $so_id,
                {
                    'variant_id'        => $soi_ref->{variant_id},
                    'quantity'          => $soi_ref->{ordered},
                    'original_quantity' => $soi_ref->{ordered},
                    'status_id'         => 1,
                    'type_id'           => 3,
                    'cancel'            => 0,
                }
            );
        }
    }

    return $po_id;
}

1;
