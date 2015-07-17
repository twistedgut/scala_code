package XT::Domain::Product::Sizing;

use NAP::policy "tt", 'class';
use Moose;
use Carp qw{croak};
use JSON qw/to_json/;

use XTracker::Constants::FromDB qw(
  :stock_order_item_status
  :stock_order_item_type
  :stock_order_type
);

with qw(XTracker::Role::WithAMQMessageFactory);

use Data::Dump qw[ pp ];

has 'schema' => ( is => 'ro', );

has 'log' => ( is => 'ro', );

=head1 XT::Domain::Product::Sizing - handle product sizing (quantities and size scheme) updates

When product size updates are requested, this module carries out consistency
checks and performs the updates.

Called from XT::DC::Controller::API::Product.

=head2 new({ schema => $db_schema, log => $logger })

Constructor.

=head2 sizing_state( $sizing_data )

Given the incoming sizing data hashref, returns an equivalent hashref of the current state.

To be used by both GET and PUT (GET should return the current state, PUT
should make the modifications then return the original state for rollback).

XXX It therefore doesn't make sense that this requires $sizing_data as GET
will surely not work. !!!

=cut

sub sizing_state {
    # XXX-PM TODO: why does it need the incoming $sizing_data?
    # Surely this means that GET won't work
    my ( $self, $sizing_data ) = @_;

    # We expect all PIDs with a purchase order specified to exist
    # Those without a purchase order may or may not exist.
    my @pids =
        grep { exists $sizing_data->{$_}->{purchase_orders} }
        keys %{$sizing_data};

    my $products_rs =
      $self->schema->resultset('Public::Product')->search( { id => [@pids] } );

    # We found fewer products than we were expecting, so we cannot continue
    unless ( $products_rs->count() == scalar @pids ) {
        die "Product Not Found in XT: Expecting to find at least "
          . scalar(@pids)
          . " products but found only "
          . $products_rs->count()
          . " - update not possible (@pids)\n";
    }

    my %sizing_backup;
    while ( my $product = $products_rs->next ) {

        my $size_scheme = $product->attribute->size_scheme;
        $sizing_backup{ $product->id }->{name} = $size_scheme->name;

        # Build a hash of the current sizing state
        my $stock_orders = $product->stock_order;
        while ( my $stock_order = $stock_orders->next ) {
            $sizing_backup{ $product->id }->{purchase_orders}
              ->{ $stock_order->purchase_order->purchase_order_number } = {};
            my $sizing = $stock_order->stock_order_items;
            while ( my $item = $sizing->next ) {
                $sizing_backup{ $product->id }->{sizes}
                  ->{ $item->variant->size->size } = {
                    designer_size => $item->variant->designer_size->size,
                    variant_id    => $item->variant->id,
                  };
                $sizing_backup{ $product->id }->{purchase_orders}
                  ->{ $stock_order->purchase_order->purchase_order_number }
                  ->{quantities}->{ $item->variant->size->size } =
                  $item->quantity;

            }
            # Compare all sizes in size scheme with sizes in hash
            # If size not found in hash, append and set quantity = 0
            my @size_scheme_variant_sizes =
              $self->_find_all_sizes_in_size_scheme($size_scheme);
            foreach my $size_variant (@size_scheme_variant_sizes) {
                unless ( $sizing_backup{ $product->id }->{purchase_orders}
                    ->{ $stock_order->purchase_order
                          ->purchase_order_number }->{quantities}
                    ->{ $size_variant->size->size } )
                {
                    $sizing_backup{ $product->id }->{purchase_orders}
                      ->{ $stock_order->purchase_order
                          ->purchase_order_number }->{quantities}
                      ->{ $size_variant->size->size } = 0;

                    # Find the variant ID. Needed to match the message format from fulcrum.
                    my $variant_id_rs =
                        $size_variant
                            ->size
                            ->search_related(
                                'variant_size_ids',
                                {
                                    product_id => $product->id,
                                }
                            )
                        ;

                    my $variant_id;
                    if  ( $variant_id_rs->count ) {
                        $variant_id = $variant_id_rs->first->id;
                    }
                    else {
                        # TODO: Identify why we might need to know when this occurs?
                        # $self->log->debug("Variant not found for product "
                        #   . $product->id
                        #   . " size "
                        #   . $size_variant->size->size
                        #   . " when creating rollback data for sizing change");
                    }
                    $sizing_backup{ $product->id }->{sizes}
                        ->{ $size_variant->size->size } = {
                            designer_size => $size_variant->designer_size->size,
                            variant_id    => $variant_id
                        };
                }
            }
        }

    }
    return \%sizing_backup;
}

=head2 update_sizing ( $sizing_data )

Updates the sizing for a set of products.

Requires a hashref of data for all of the purchase orders relevant to that
product.

The size scheme will be updated if it is different from the existing one.
All variants and stock_order_items will be deleted and recreated as specified
in the $sizing_data hashref.

The client (i.e. Fulcrum) should notify the user that all purchase orders
associated with the product should be reviewed and updated if necessary.

This is intended to be called from the sizing_PUT on the product API.

It dispatches most of the work off to _update_size_scheme_and_quantities or
_update_size_quantities (according to whether the size scheme has changed or
not).

=cut

sub update_sizing {
    my ( $self, $sizing_data ) = @_;

    my $schema = $self->schema;
    my $pids_processed = {
        skipped => [],
        size_scheme_updated => [],
        size_quantities_updated => [],
    };
    # Products with no POs specified and not found will be skipped

  PRODUCT: foreach my $pid ( keys %{$sizing_data} ) {

        my $product = $schema->resultset('Public::Product')->find($pid);

        unless ( $product ) {
            # Product not found.
            # This should be error if purchase orders were specified,
            # skipped if no purchase orders were specified.
            if ( $sizing_data->{ $pid }->{purchase_orders} ) {
                # Fulcrum thinks this product has POs in this DC
                # but product not found => error
                die "Validation Failed - Product $pid does not exist in XT"
                    . " but is specified with purchase orders by Fulcrum\n";
            }
            else {
                # Fulcrum does not think there are any POs
                # just a size scheme update for information => skip
                push @{ $pids_processed->{skipped} }, $pid;
                next PRODUCT;
            }
        }

        my $size_scheme =
          $schema->resultset('Public::SizeScheme')
          ->search( { name => $sizing_data->{$pid}->{name} } )->first;

        unless ( defined $size_scheme ) {
            die "Validation Failed - Size scheme: "
              . $sizing_data->{$pid}->{name}
              . " sent from fulcrum, does not exist in XT.\n";
        }

        # If size scheme HAS changed
        my $has_changed = $product->has_size_scheme_changed( $size_scheme->id );

        if ($has_changed) {
            # Size scheme has changed.

            # Return error if any purchase orders found in XT for a
            # given product where a size scheme change is being requested
            # are not found in the $sizing_data sent from Fulcrum, as
            # we have not received all the information from fulcrum.

            my $purchase_orders_found =
                $self->schema->resultset('Public::PurchaseOrder')->search(
                    { 'stock_orders.product_id' => $pid },
                    {
                        join => 'stock_orders',
                        select => ['purchase_order_number']
                    }
                );

            while ( my $so = $purchase_orders_found->next ) {
                unless ( $sizing_data->{ $product->id }->{purchase_orders}
                    ->{ $so->purchase_order_number } )
                {
                    die "Validation Failed: The purchase_order: "
                    . $so->purchase_order_number
                    . " is in XT but not in data from fulcrum ($pid),"
                    . " update not possible\n";
                }
            }

            $self->_update_size_scheme_and_quantities(
                product     => $product,
                pid         => $pid,
                sizing_data => $sizing_data,
                size_scheme => $size_scheme,
                pids_processed => $pids_processed,
            );
        }
        else {

            # Size scheme has not changed.
            $self->_update_size_quantities(
                product     => $product,
                pid         => $pid,
                sizing_data => $sizing_data,
                size_scheme => $size_scheme,
                 pids_processed => $pids_processed,
            );

        }
    }
    return $pids_processed;
}

=head2 _update_size_scheme_and_quantities

Updates the size scheme and quantities for the products and purchase orders
listed.

=cut

sub _update_size_scheme_and_quantities {
    my ( $self, %args ) = @_;

    my $schema      = $self->schema;
    my $pid         = $args{pid} or croak "named argument pid missing";
    my $product     = $args{product} or croak "named argument product missing";
    my $sizing_data = $args{sizing_data}
      or croak "named argument sizing_data missing";
    my $size_scheme = $args{size_scheme}
      or croak "named argument size_scheme missing";
    my $pids_processed = $args{pids_processed};

    $self->_fail_if_has_rtv_or_measurements($product);

    $self->_update_size_scheme_name( $product, $size_scheme );

    $self->_fail_if_stock_booked_in($product);

    # Delete all stock_order_items for product
    $product->delete_related_stock_order_items;

    # Delete all variants for product
    $product->variants->delete();

    # Fetch the size_variants for this product from the big hash
    my $size_variant = $sizing_data->{$pid}->{sizes};

    # Find all sizes for given size scheme
    my @size_scheme_variant_sizes =
      $self->_find_all_sizes_in_size_scheme($size_scheme);

    $self->_fail_if_size_missing_from_size_variant_data(
        pid                       => $pid,
        size_variant              => $size_variant,
        size_scheme_variant_sizes => \@size_scheme_variant_sizes
    );

    my $purchase_orders_to_update =
      $self->_find_purchase_orders_to_update(
        $sizing_data->{$pid}->{purchase_orders} );

    SIZE: foreach my $size (@size_scheme_variant_sizes) {

        # Unable to save size scheme changes, size not found
        unless ( $size_variant->{ $size->size->size } ) {
            die "Validation Failed - Size "
              . $size->size->size
              . "not found in data from fulcrum.\n";
        }

        # Unable to save size scheme changes, designer size name mismatch
        unless ( $size->designer_size->size eq
            $size_variant->{ $size->size->size }->{designer_size} )
        {
            die "Validation Failed - Designer size : "
              . $size_variant->{ $size->size->size }->{designer_size}
              . " in data from fulcrum does not match size in database.\n";
        }

        # Create new variant and update standardised sizes
        my $new_variant = $self->_create_variant(
            size_scheme_variant_size => $size,
            product                  => $product,
            variant_id => $size_variant->{ $size->size->size }->{variant_id},
        );

        # IF there are no purchase orders, just update product
        # variants and skip to next.
        next SIZE unless $purchase_orders_to_update;

        # Now create new stock order items (the quantity for each size)
        # in purchase orders
        $self->_create_stock_order_items(
            product                   => $product,
            purchase_orders_to_update => $purchase_orders_to_update,
            sizing_data               => $sizing_data,
            size                      => $size,
            new_variant               => $new_variant,
        );
    }
    push @{ $pids_processed->{size_scheme_updated} }, $product->id;
    return;
}

=head2 _create_stock_order_items

Given a product, a bunch of purchase orders, a load of sizing data, a size
and a newly created variant: Create new stock order items for all of the
relevant purchase orders containing the quantities specified for each size
in the sizing data hash.

=cut

sub _create_stock_order_items {
    my ( $self, %args ) = @_;

    my $product = $args{product} or croak "Missing named argument product";
    my $purchase_orders_to_update = $args{purchase_orders_to_update}
      or croak "Missing named parameter purchase_orders_to_update";
    my $sizing_data = $args{sizing_data}
      or croak "Missing named parameter sizing_data";
    my $size = $args{size} or croak "Missing named parameter size";
    my $new_variant = $args{new_variant}
      or croak "Missing named parameter new_variant";

    # Create Stock Order Items
    foreach my $so ( $product->stock_order->all ) {
        if ( $purchase_orders_to_update->{ $so->purchase_order_id } ) {
            my $quantity =
              $sizing_data
                ->{ $product->id }
                ->{purchase_orders}
                ->{ $so->purchase_order->purchase_order_number }
                ->{quantities}
                ->{ $size->size->size };

            # Creates stock order items for any quantities passed which are greater than 0.
            $so->create_related(
                'stock_order_items',
                {
                    variant_id        => $new_variant->id,
                    quantity          => $quantity,
                    status_id         => $STOCK_ORDER_ITEM_STATUS__ON_ORDER,
                    type_id           => $STOCK_ORDER_ITEM_TYPE__UNKNOWN,
                    original_quantity => $quantity
                }
            ) if ( defined $quantity && $quantity > 0 );
        }
        else {

            # If it gets into this else, it's an internal error
            die "Internal Error in XT Product API: purchase order id "
              . $so->purchase_order_id
              . "has disappeared from the XT database"
              . " while processing this request.\n";
        }
    }
    return;
}

=head2 _find_purchase_orders_to_update( $purchase_orders )

Searches through the specified $purchase_orders hash (keyed by PO number)
and returns a new hash of purchase orders that are actually present in the
database (keyed by ID).

=cut

sub _find_purchase_orders_to_update {
    my ( $self, $purchase_orders ) = @_;
    my $purchase_orders_to_update;
    foreach my $po_num ( keys %{$purchase_orders} ) {
        my $po =
          $self->schema->resultset('Public::PurchaseOrder')
          ->search( { purchase_order_number => $po_num } )->first;
        if ($po) {
            $purchase_orders_to_update->{ $po->id } = $po;
        }
    }
    return $purchase_orders_to_update;
}

=head2 _fail_if_size_missing_from_size_variant_data

Args named args hash:
    size_variant => $size_variant,
    pid => $pid,
    size_scheme_variant_sizes => $size_schema_variant_sizes

Check the size variant data specified and ensure that it contains all of the
sizes in the size scheme specified.

=cut

sub _fail_if_size_missing_from_size_variant_data {
    my ( $self, %args ) = @_;

    my $size_variant = $args{size_variant}
      or croak "missing named argument size_variant";
    my $pid = $args{pid} or croak "missing named argument pid";
    my $size_scheme_variant_sizes = $args{size_scheme_variant_sizes}
      or croak "missing named argument size_scheme_variant_sizes";

    foreach my $size_scheme_variant ( @{$size_scheme_variant_sizes} ) {
        unless ( $size_variant->{ $size_scheme_variant->size->size } ) {
            die "Validation Failed - Found size : "
              . $size_scheme_variant->size->size
              . " in XT that does not exist in data from Fulcrum, for product : "
              . $pid
              . "\n";
        }
    }

}

=head2 _find_all_sizes_in_size_scheme( $size_scheme )

Returns all of the SizeSchemeVariantSize records
(which link sizes into size schemes) for a given size scheme.

=cut

sub _find_all_sizes_in_size_scheme {
    my ( $self, $size_scheme ) = @_;

    return $self->schema->resultset('Public::SizeSchemeVariantSize')
      ->search( { size_scheme_id => $size_scheme->id } )->all;
}

=head2 _fail_if_stock_booked_in( $product )

Fail is stock has ever been booked in for this product.
We can't update the size scheme.

=cut

sub _fail_if_stock_booked_in {
    my ( $self, $product ) = @_;

    # Stock has been counted in if this is > 0:
    #
    my $stock_count =
      $product
        ->variants
        ->related_resultset('stock_order_items')
        ->related_resultset('link_delivery_item__stock_order_items')
        ->related_resultset('delivery_item')
        ->related_resultset('stock_processes')
        ->count;

    if ( $stock_count > 0 ) {
        die "Validation Failed - Stock has been booked in for product: "
          . $product->id
          . "\n";
    }

    return;
}

=head2 _fail_if_has_rtv_or_measurements( $product )

If we have rtvs or measurements on any of those variants we can't update the
size scheme.

=cut

sub _fail_if_has_rtv_or_measurements {
    my ( $self, $product ) = @_;
    my $error_message;
    foreach my $variant ( $product->variants ){
        if ($variant->log_rtv_stocks->count){
            $error_message .= " Has or had units assigned to RTV";
        }
        if ($variant->variant_measurements->count){
            $error_message .= ($error_message ? " and has" : " Has")." measurements";
        }
        if($error_message){
            die ("Validation Failed - PID ".$variant->product_id."$error_message".", therefore size scheme changes are not allowed. Please contact service desk.\n")
        }
    }

    return;
}


=head2 _update_size_scheme_name( $size_scheme )

Updates the product's size scheme name. Note that this doesn't actually
change the size scheme in terms of the sizing data model.

=cut

sub _update_size_scheme_name {
    my ( $self, $product, $size_scheme ) = @_;

    # Update size scheme name in Product Attribute table
    $product->product_attribute->update(
        { size_scheme_id => $size_scheme->id } );
    return;
}

=head2 _update_size_quantities

Update the sizes and quantities (stock_order_items) for a purchase order.

New stock order items will be created if specified for a size that
was not already in the order. Otherwise, the existing stock order item
quantities will be updated.

=cut

sub _update_size_quantities {
    my ( $self, %args ) = @_;

    ## no critic(ProhibitDeepNests)

    # Size scheme for product has not changed

    my $schema      = $self->schema;
    my $pid         = $args{pid} or croak "named argument pid missing";
    my $product     = $args{product} or croak "named argument product missing";
    my $sizing_data = $args{sizing_data}
      or croak "named argument sizing_data missing";
    my $size_scheme = $args{size_scheme}
      or croak "named argument size_scheme missing";
    my $pids_processed = $args{pids_processed};

    # Log something so we see what was sent
    my $payload_for_log = to_json($sizing_data);
    $payload_for_log =~ s/\s+/ /g;
    $self->log->trace( "EditPO Sizing update with payload $payload_for_log" );

    # identify purchase order to update
    foreach my $purchase_order_number (
        keys %{ $sizing_data->{$pid}->{purchase_orders} } )
        {

            unless ( defined $purchase_order_number ) {
                die "Validation Failed - "
                  . "purchase order we were currently"
                  . "editing was not specified\n";
            }

            my $purchase_order =
              $schema->resultset('Public::PurchaseOrder')
              ->search( { purchase_order_number => $purchase_order_number } )
              ->first;

            # XXX-PM die if more than one purchase order with the given number?

            if ( defined $purchase_order ) {

                # Purchase order was found.

                # Find stock order.
                my $stock_order_rs =
                  $schema->resultset('Public::StockOrder')->search(
                    {
                        'purchase_order.purchase_order_number' =>
                          $purchase_order_number,
                        'me.product_id' => $pid,
                        'me.type_id' => $STOCK_ORDER_TYPE__MAIN,
                    },
                    { join => 'purchase_order' }
                  );

                if ( $stock_order_rs->count > 1 ) {
                    # There should only be one stock order found.
                    # Die with an error rather than updating a random one...
                    die sprintf(
                        "XTDB: Multiple stock orders for product %s in PO %s",
                        $pid,
                        $purchase_order_number,
                    );
                }
                elsif ( $stock_order_rs->count == 0 ) {
                    die sprintf(
                        "XTDB: No stock order found for product %s in PO %s",
                        $pid,
                        $purchase_order_number,
                    );
                }

                my $stock_order = $stock_order_rs->single;
                $self->log->debug(
                    sprintf(
                        "Updating stock order %s for product %s in PO %s",
                        $stock_order->id,
                        $pid,
                        $purchase_order_number,
                    )
                );

                # Create a more convenient reference to the
                # size/quantities for this PO

                my $quantities =
                  $sizing_data->{$pid}->{purchase_orders}
                  ->{$purchase_order_number}->{quantities};

                # Run through each size
                foreach my $size_name ( keys %{$quantities} ) {

                    # The quantity ordered for this size in the updated PO.
                    my $quantity = $quantities->{$size_name};

                    # Find the stock order item for this size
                    my $soi = $stock_order->stock_order_items->search(
                        { 'size.size' => $size_name, },
                        { join        => { variant => 'size' }, },
                    )->first;

                    if ( defined $soi ) {
                        $self->log->debug(
                            sprintf(
                                "Found stock order item for size %s of product %s in PO %s. Updating quantities.",
                                $size_name,
                                $pid,
                                $purchase_order_number,
                            )
                        );

                        # PM-1284: disallow updates with quantity < delivered
                        my $delivered = $soi->get_delivered_quantity // 0;
                        if ( $quantity < $delivered ) {
                            die "Validation Failed -"
                                . " Cannot update quantity for PID $pid, size"
                                . " '$size_name' to $quantity because it is"
                                . " less than already delivered quantity"
                                . " $delivered\n";
                        }

                        # If a stock order item was found, update it
                        # PM-1315:
                        #      if quantity == 0, cancel,
                        #      if cancelled and quantity > 0, uncancel
                        if ( $quantity ) {
                            # remember this for debug purposes
                            my $was_cancelled = $soi->cancel;

                            # Update quantity and cancellation status
                            $soi->update({
                                quantity                => $quantity,
                                stock_order_item_cancel => 0,
                                cancel                  => 0,
                            });

                            # Log what we did. For clarity, we need to know if
                            # the SOI was cancelled before or not.
                            if ( $was_cancelled ) {
                                $self->log->trace(
                                    sprintf(
                                        "Uncancelled SOI %s for size %s of product %s in PO %s because of quantity %s from API payload",
                                        $soi->id,
                                        $soi->variant->size->size,
                                        $soi->stock_order->product_id,
                                        $soi->stock_order->purchase_order->purchase_order_number,
                                        $quantity,
                                    )
                                );
                            }
                            else {
                                $self->log->trace(
                                    sprintf(
                                        "Set quantity for SOI %s for size %s of product %s in PO %s to %s from API payload",
                                        $soi->id,
                                        $soi->variant->size->size,
                                        $soi->stock_order->product_id,
                                        $soi->stock_order->purchase_order->purchase_order_number,
                                        $quantity,
                                    )
                                );
                            }
                        }
                        else {
                            # If quantity is zero and soi is not already cancelled,
                            # we need to do something here.
                            if (!$soi->cancel) {
                                # Cancel it. The previous quantity will be preserved
                                # for reference (copying the old XT behaviour)
                                $soi->update({
                                    stock_order_item_cancel => 1,
                                    cancel                  => 1,
                                });

                                # Log what we just did.
                                $self->log->trace(
                                    sprintf(
                                        "Cancelled SOI %s for size %s of product %s in PO %s because of quantity %s from API payload",
                                        $soi->id,
                                        $soi->variant->size->size,
                                        $soi->stock_order->product_id,
                                        $soi->stock_order->purchase_order->purchase_order_number,
                                        $quantity,
                                    )
                                );
                            }
                            else {
                                # We don't need to do anything here
                                $self->log->trace(
                                    sprintf(
                                        "Skip SOI %s for size %s of product %s in PO %s because quantity is %s and SOI is already cancelled.",
                                        $soi->id,
                                        $soi->variant->size->size,
                                        $soi->stock_order->product_id,
                                        $soi->stock_order->purchase_order->purchase_order_number,
                                        $quantity,
                                    )
                                );
                            }
                        }

                        # The quantity change may make delivery complete...
                        $soi->update_status;
                    }
                    else {
                        $self->log->debug(
                            sprintf(
                                "No stock order item for size %s of product %s in PO %s.",
                                $size_name,
                                $pid,
                                $purchase_order_number,
                            )
                        );

                        my $variant;
                        # Stock order item not found
                        # This size must not have been on order before.
                        # Create new stock order item.

                        # First need the size scheme variant size to get the size_id etc.
                        my $size_scheme_variant_size =
                          $schema->resultset('Public::SizeSchemeVariantSize')
                          ->search(
                            {
                                'size.size'         => $size_name,
                                'me.size_scheme_id' => $size_scheme->id,
                            },
                            { join => "size" }
                          )->first;

                        # Get the existing variant for this product / size
                        my $variant_rs  = $stock_order->public_product->variants->search(
                            {
                                size_id => $size_scheme_variant_size->size_id,
                            }
                        );
                        if ( $variant_rs->count > 1 ) {
                            # If more than one variant is found for query
                            # this should not happen, and is most likely
                            # down to data inconsistency.
                            die "Expecting to find one variant, but found multiple variants for product: "
                                . $pid
                                . " and size_id "
                                . $size_scheme_variant_size->size_id
                            ;
                        }
                        elsif ( $variant_rs->count == 0 ) {

                            # Variant was not found, create one.

            # Newly created variants should preserve the variant ID from Fulcrum

            # Variant IDs should be specified in the data from fulcrum
            # (_create variant will croak or die as appropriate if it's missing)
                            my $variant_id =
                              $sizing_data->{$pid}->{sizes}->{$size_name}
                              ->{variant_id};

           # _create_variant is a helper that is used when creating new variants
           # whether the size scheme changed or not.
                            $variant = $self->_create_variant(
                                size_scheme_variant_size =>
                                  $size_scheme_variant_size,
                                product    => $product,
                                variant_id => $variant_id,
                            );
                        }
                        elsif ( $variant_rs->count == 1 ) {
                            $variant = $variant_rs->first;
                        }
         # With the variant sorted out, we can create a new stock order item
         # in this stock order for this size/variant and the specified quantity.
                        if ( $quantity > 0 ) {
                            $stock_order->create_related(
                                'stock_order_items',
                                {
                                    stock_order_id => $stock_order->id,
                                    variant_id     => $variant->id,
                                    quantity       => $quantity,
                                    status_id =>
                                        $STOCK_ORDER_ITEM_STATUS__ON_ORDER,
                                    type_id =>
                                        $STOCK_ORDER_ITEM_TYPE__UNKNOWN,
                                    original_quantity => $quantity,
                                }
                            );
                        }
                    }
                }

                # The quantity change may make delivery complete
                # (for the whole stock order or purchase order)
                $stock_order->update_status;
                $purchase_order->update_status;
            }
            else {

         # Purchase order not found. Not an error, as it may be at the other DC.
                $self->log->info(
                    "Info - Product API sizing update: Purchase order number "
                      . $purchase_order_number
                      . "not found in this DC. Not doing anything." );
            }
        }
        push @{ $pids_processed->{size_quantities_updated} }, $product->id;
        return;
      }

=head2 _create_variant ( variant_id => $variant_id, product => $product, $size_scheme_variant_size => $SSVS )

Create a variant for the size and also locates the standardised size mapping updates standardised sizes
Returns a new variant for a product corresponding to the SizeSchemeVariantSize object
specified.

=cut

sub _create_variant {
    my ( $self, %args ) = @_;

    my $product = $args{product} or croak "Missing named argument product";
    my $size_scheme_variant_size = $args{size_scheme_variant_size}
      or croak "Missing named argument size_scheme_variant_size";

    my $variant_id = $args{variant_id};

   # Try to distinguish between a coding error and an error in the incoming data
    if ( !defined $variant_id && exists $args{variant_id} ) {
        die "Validation Failed - Missing variant ID in size specification"
          . " for product "
          . $product->id
          . " size name "
          . $size_scheme_variant_size->size->size
          . "\n";
    }
    elsif ( !exists $args{variant_id} ) {
        croak "Missing named argument variant_id";
    }

    my $legacy_sku = $product->id;
    $legacy_sku .= "_" . $size_scheme_variant_size->position
      if $size_scheme_variant_size->position > 0;
    my $variant = $product->create_variant(
        {
            variant_id       => $variant_id,
            size_id          => $size_scheme_variant_size->size_id,
            designer_size_id => $size_scheme_variant_size->designer_size_id,
            legacy_sku       => $legacy_sku,
        }
    );
    die "Internal Error - "
      . "Can't find or create variant for product : "
      . $product->id
      . " with size_id "
      . $size_scheme_variant_size->size_id
      . " and designer_size_id "
      . $size_scheme_variant_size->designer_size_id
      . "\n"
      unless defined $variant;

    # Update standardised sizing
    $variant->discard_changes();
    $variant->update_standardised_size_mapping;

    return $variant;
}

=head2 update_product_service_with_stock_detail_level_update

Notify all who care about stock levels when a size quantity gets updated
for a product when we are editing purchase orders.

=cut

sub update_product_service_with_stock_detail_level_update {
    my ( $self, $pid, $channel_id ) = @_;

    my $broadcast = XTracker::WebContent::StockManagement::Broadcast->new(
        {
            schema     => $self->schema,
            channel_id => $channel_id,
        }
    );

    $broadcast->stock_update(
        quantity_change => 0,
        product_id      => $pid,
        full_details    => 1,
    );

    $broadcast->commit();
}

=head2 update_product_service_with_sizing_update

Send a message to product service notifying it that a size
scheme for product x has changed, it will then AskFor sizes
again from XT for every channel on that DC.

A size scheme change will mean that the variants have been recreated
and so new quantities will exist, so we will also need to notify
product service that the stock detail level has changed.

=cut

sub update_product_service_with_sizing_update {
    my ( $self, $pid ) = @_;

    my $product = $self->schema->resultset('Public::Product')->find( $pid );

    return unless $product;

    foreach my $pc ( $product->product_channel ) {
        $self->msg_factory->transform_and_send(
            'XT::DC::Messaging::Producer::ProductService::Sizing',
            {
                product     => $product,
                channel_id  => $pc->channel_id,
                size_scheme => $product->product_attribute->size_scheme->name,
            },
        );

        # Notify product service of stock level detail update
        $self->update_product_service_with_stock_detail_level_update( $pid,
            $pc->channel_id );
    }
}

1;
