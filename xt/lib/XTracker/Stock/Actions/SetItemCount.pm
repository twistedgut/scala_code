package XTracker::Stock::Actions::SetItemCount;

use strict;
use warnings;
use Carp;

use XTracker::Config::Local qw{config_section_slurp};
use XTracker::Constants::FromDB qw(
    :delivery_action
    :delivery_item_status
    :department
    :stock_process_type
);
use XTracker::Database;
use XTracker::Database::Attributes qw(:update);
use XTracker::Database::Delivery;
use XTracker::Database::Logging qw( log_delivery );
use XTracker::Database::Product qw/validate_product_weight/;
use XTracker::Database::PurchaseOrder qw(
    check_soi_status
    set_soi_status
);
use XTracker::Database::StockProcess;
use XTracker::Error;
use XTracker::Handler;
use XTracker::PrintFunctions;
use XTracker::Utilities qw( unpack_handler_params );
use XTracker::Session;
use XTracker::WebContent::StockManagement::Broadcast;

use Data::Dumper;

sub handler {
    my $handler = XTracker::Handler->new( shift );
    my $schema = $handler->{schema};
    my $dbh = $schema->storage->dbh;

    my $location;
    my $delivery_id = 0;

    my $session = XTracker::Session->session();
    my $operator_id = $handler->operator_id;

    eval {

        # Use a txn_scope_guard instead of txn_do so that the error doesn't get mangled.
        my %vars   = ();
        my $di_ref = ();
        my $total_count = 0;

        # unpack request parameters
        my ( $data_ref, $rest_ref ) = unpack_handler_params($handler->{param_of});

        foreach my $delivery_item_id ( keys %{$data_ref} ) {
            # EN-298 commented out next line so 0s entered into packing slip will still be checked
            #next if $data_ref->{$delivery_item_id}->{count} == 0;
            push @{$di_ref},
                { delivery_item_id => $delivery_item_id,
                  item_count       => $data_ref->{$delivery_item_id}{count},
                };

            $total_count += $data_ref->{$delivery_item_id}{count};
        }

        # save delivery_id for error redirect
        $delivery_id = $rest_ref->{delivery_id};

        # create stock_process entries
        my $data = { delivery_items => $di_ref, };

        my $strict_count = $handler->department_id != $DEPARTMENT__DISTRIBUTION_MANAGEMENT
                        && $handler->department_id != $DEPARTMENT__STOCK_CONTROL;

        my $sender = $handler->msg_factory;
        my $guard = $schema->txn_scope_guard;
        _set_item_count( $schema, $sender, $data, $delivery_id, $strict_count );

        log_delivery( $dbh, {
            delivery_id => $delivery_id,
            action      => $DELIVERY_ACTION__COUNT,
            operator    => $operator_id,
            quantity    => $total_count,
            type_id     => $STOCK_PROCESS_TYPE__MAIN,
        });

        # Note that this doesn't return voucher items
        my $item_data_ref = get_stock_delivery_items( $dbh, $delivery_id );

        # print out barcode labels
        my $printer_station_name
            = $handler->operator->operator_preference->printer_station_name;
        foreach my $item_ref ( sort { $a->{size_id} <=> $b->{size_id} } @{$item_data_ref} ) {
            next unless $data_ref->{ $item_ref->{id} }->{count};
            _print_barcode_labels(
                $schema,
                $item_ref->{variant_id},
                $data_ref->{ $item_ref->{id} }{count},
                $printer_station_name
            );
        }

        ## set shipping attributes
        if ($rest_ref->{'country'}){
            set_shipping_attribute(
                $dbh, $rest_ref->{'prod_id'},
                'country',
                $rest_ref->{'country'},
                $operator_id );
        }

        # If the user entered nothing ("" rather than undef) then ignore it
        if (defined($rest_ref->{'weight'}) && length($rest_ref->{'weight'})) {
            $rest_ref->{'weight'} =~ s/[kgslbs]//gi;

            validate_product_weight( product_weight => $rest_ref->{'weight'} );

            set_shipping_attribute(
                $dbh, $rest_ref->{'prod_id'},
                'weight',
                $rest_ref->{'weight'},
                $operator_id );
        }

        if ($rest_ref->{'fabric_content'}){
            set_shipping_attribute(
                $dbh,
                $rest_ref->{'prod_id'},
                'fabric_content',
                $rest_ref->{'fabric_content'},
                $operator_id );
        }

        # redirect to delivery scan
        $location = "/GoodsIn/ItemCount";
        $guard->commit;
        xt_success( "Item count completed for delivery $delivery_id" );
    };
    if($@){
        xt_warn( "There was an error updating this delivery's item count: $@" );
        $location = "Book?delivery_id=$delivery_id";
    }
    $handler->redirect_to( $location );
}


### Subroutine : _set_item_count                ###
# usage        :                                  #
# description  :                                  #
# parameters   :  $strict, if true then item      #
#                 counts are checked against      #
#                 packing count                   #
# returns      :                                  #

sub _set_item_count {
    my ( $schema, $sender, $data_ref, $delivery_id, $strict ) = @_;

    my $dbh = $schema->storage->dbh;

    my $delivery = $schema->resultset('Public::DeliveryItem')
                          ->find($data_ref->{delivery_items}[0]{delivery_item_id})
                          ->delivery;
    my $stock_order_id = $delivery->stock_order->id;
    my $purchase_order = $delivery->stock_order->purchase_order;
    my $old_po_status_id = $purchase_order->status_id;
    my $group_id = 0;

    DELIVERY_ITEM:
    foreach my $di_ref ( @{ $data_ref->{delivery_items} } ) {

        # TODO: sanity check data
        # if delivery_item is wrong status then die ??
        die "already processed\n" if check_delivery_item( $dbh,
                                                        $di_ref->{delivery_item_id},
                                                        $DELIVERY_ITEM_STATUS__COUNTED,
                                                      );
        if( $strict && !check_delivery_item_count( $dbh, $di_ref->{delivery_item_id}, $di_ref->{item_count} )) {
            die "Quantities entered different to those expected. Please check again\n";
        }

        set_delivery_item_quantity( $dbh,
                                    $di_ref->{delivery_item_id},
                                    $di_ref->{item_count} );

        set_delivery_item_status( $dbh,
                                  $di_ref->{delivery_item_id},
                                  'delivery_item_id',
                                  $DELIVERY_ITEM_STATUS__COUNTED );


        create_stock_process( $dbh,
                              $STOCK_PROCESS_TYPE__MAIN,
                              $di_ref->{delivery_item_id},
                              $di_ref->{item_count},
                              \$group_id );

        set_soi_status( $dbh,
                        $di_ref->{delivery_item_id},
                        'delivery_item_id',
                        check_soi_status( $dbh, $di_ref->{delivery_item_id}, 'delivery_item_id' ),
                      );
    }

    # update status values for each level of the PO, also sends a
    # stock update message
    $delivery->mark_as_counted;
    # Check if po status has changed
    if ( $purchase_order->is_voucher_po
     and $old_po_status_id != $purchase_order->discard_changes->status_id ) {
        $sender = $sender->transform_and_send( 'XT::DC::Messaging::Producer::PurchaseOrder', $purchase_order );
    }

    return;
}


sub _print_barcode_labels {
    my ( $schema, $variant_id, $item_count, $location ) = @_;

    my $variant = $schema->resultset('Public::Variant')->find($variant_id);
    my $product = $variant->product;

    # Print large labels if we need to
    if ( my $copies = $item_count * $product->large_labels_per_item ) {
        $variant->large_label->print_at_location($location, $copies);
    }

    # Print small labels if we need to
    if ( my $copies = $item_count * $product->small_labels_per_item ) {
        $variant->small_label->print_at_location($location, $copies);
    }
}

1;
