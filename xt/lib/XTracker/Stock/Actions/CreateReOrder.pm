package XTracker::Stock::Actions::CreateReOrder;

use strict;
use warnings;
use Carp;

use XTracker::Handler;
use XTracker::Database::PurchaseOrder qw( get_purchase_order mark_po_as_not_editable_in_fulcrum :create);
use XTracker::Database::Product       qw( set_product_cancelled );
use XTracker::Error;
use XTracker::WebContent::StockManagement::Broadcast;

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    # set up vars to store user responses
    my $redirect    = '';
    my $display_msg = '';
    my $error_msg   = '';

    # store the new po id created
    my $po_id_to_use;

    # form submitted
    if ( $handler->{param_of}{purchase_order_id} ){
        my $po_id = $handler->{param_of}{purchase_order_id};

        # process form data
        my $po_number           = $handler->{param_of}{po_number};
        my $start_ship_date     = $handler->{param_of}{start_ship_date};
        my $cancel_ship_date    = $handler->{param_of}{cancel_ship_date};

        my $schema = $handler->schema;
        my $dbh = $schema->storage->dbh;

        if ( !$po_number ) {
            $error_msg .= 'Please provide a PO Number for the re-order<br />';
        }
        else {
            # Check if the PO number is already marked as not editable in fulcrum, issue a warning if it is
            my $sth = $dbh->prepare( "select count(*) as count from public.purchase_orders_not_editable_in_fulcrum where number = ?" );
            $sth->execute($po_number);
            my $previously_marked = $sth->fetchrow_hashref();
            if ( $previously_marked->{count} > 0 ) {
                $error_msg .= 'You cannot use the same purchase order number for a re-order, please provide a unique one<br />';
            }
        }
        if (!$start_ship_date) {
            $error_msg .= 'Please provide a Start Ship Date for the re-order<br />';
        }
        if (!$cancel_ship_date) {
            $error_msg .= 'Please provide a Cancel Ship Date for the re-order<br />';
        }

        my %stock_order = ();

        # loop through post data and get items for stock order
        foreach my $form_key ( %{ $handler->{param_of} } ) {

            # match confirmation form fields
            if( $form_key =~ m/quantity_(\d*)_(\d*)/ ){

                # get product id and variant id out of form field name
                my ( $product_id, $variant_id ) = ( $1, $2 );

                if ($handler->{param_of}{$form_key} && $handler->{param_of}{$form_key} > 0) {
                    $stock_order{$product_id}{$variant_id} = $handler->{param_of}{$form_key};
                }
            }
        }

        # do we have any items ordered?
        if (keys %stock_order < 1) {
            $error_msg .= 'Please enter ordered quantities for the re-order<br />';
        }


        # if we found any errors then put the message in the session and go back to previous page
        if ($error_msg ne '') {
            xt_warn($error_msg);
            return $handler->redirect_to( "/StockControl/PurchaseOrder/ReOrder?po_id=$po_id" );

        }

        # form data okay - create re-order
        eval {
            my $guard = $schema->txn_scope_guard;
            # get existing po data (to reorder from)
            my $po_data = get_purchase_order( $dbh, $po_id, 'purchase_order_id'  )->[0];

            # see if the reorder po number exists already (see EN-988)
            my $existing_reorder_po_data = get_purchase_order( $dbh, $po_number, 'purchase_order'  )->[0];

            if ($existing_reorder_po_data) {
                $po_id_to_use = $existing_reorder_po_data->{id};
            } else {
                # create purchase order
                my $purchase_order_id = create_purchase_order (
                                        $dbh,
                                        {
                                            'purchase_order_nr'     => $po_number,
                                            'description'           => '',
                                            'designer_id'           => $po_data->{'designer_id'},
                                            'status_id'             => 1,
                                            'comment'               => '',
                                            'season_id'             => $po_data->{'season_id'},
                                            'currency_id'           => $po_data->{'currency_id'},
                                            'type_id'               => 2,
                                            'cancel'                => 0,
                                            'supplier_id'           => $po_data->{'supplier_id'},
                                            'act_id'                => $po_data->{'act_id'},
                                            'confirmed'             => 0,
                                            'confirmed_operator_id' => undef,
                                            'placed_by'             => '',
                                            'channel_id'            => $po_data->{'channel_id'},
                                        }
                                    );

                $po_id_to_use = $purchase_order_id;

            }

            # create stock orders
            foreach my $product_id ( sort {$a <=> $b} keys %stock_order ) {

                # create stock order
                my $stock_order_id = create_stock_order (
                                        $dbh,
                                        $po_id_to_use,
                                        {
                                            'product_id'                => $product_id,
                                            'start_ship_date'           => $start_ship_date,
                                            'cancel_ship_date'          => $cancel_ship_date,
                                            'status_id'                 => 1,
                                            'comment'                   => '',
                                            'type_id'                   => 1,
                                            'consignment'               => 0,
                                            'cancel'                    => 0,
                                            'confirmed'                 => 0,
                                            'shipment_window_type_id'   => 0,
                                        }
                                    );

                # create stock order items
                foreach my $variant_id ( sort {$a <=> $b} keys %{ $stock_order{ $product_id } } ) {

                    # create stock order item
                    my $soi_id = create_stock_order_item (
                                    $dbh,
                                    $stock_order_id,
                                    {
                                        'variant_id'        => $variant_id,
                                        'quantity'          => $stock_order{ $product_id }{ $variant_id },
                                        'original_quantity' => $stock_order{ $product_id }{ $variant_id },
                                        'status_id'         => 1,
                                        'type_id'           => 0,
                                        'cancel'            => 0,
                                    }
                                );
                }

                set_product_cancelled( $dbh, {
                   product_id => $product_id,
                   channel_id => $po_data->{'channel_id'}
                });


                # Notify anyone who cares about stock levels
                my $broadcast
                    = XTracker::WebContent::StockManagement::Broadcast->new({
                    schema => $schema,
                    channel_id => $po_data->{'channel_id'},
                });
                $broadcast->stock_update(
                    quantity_change => 0,
                    product_id => $product_id,
                    full_details => 1,
                );
                $broadcast->commit();
            }

            mark_po_as_not_editable_in_fulcrum($dbh, $po_number );

            $guard->commit();
            xt_success('Re-Order successfully created');
            $redirect      = '/StockControl/PurchaseOrder/Overview?po_id='.$po_id_to_use;
        };

        if ($@) {
            xt_warn("An error occured whilst trying to create the Re-Order: $@");
            $redirect   = '/StockControl/PurchaseOrder/ReOrder?po_id=' . $po_id;
        }
    }
    return $handler->redirect_to( $redirect );
}

1;
