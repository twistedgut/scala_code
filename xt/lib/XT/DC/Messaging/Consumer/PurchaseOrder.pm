package XT::DC::Messaging::Consumer::PurchaseOrder;
# vim: ts=8 sts=4 et sw=4 sr sta
use NAP::policy "tt", 'class';
use XTracker::Constants qw(:message_response);
use XTracker::Constants::FromDB qw/
    :stock_order_status
    :stock_order_type
    :stock_order_item_status
    :purchase_order_status
    :variant_type
/;

use vars qw/
    $STOCK_ORDER_STATUS__ON_ORDER
    $STOCK_ORDER_TYPE__MAIN
    $STOCK_ORDER_ITEM_STATUS__ON_ORDER
    $PURCHASE_ORDER_STATUS__ON_ORDER
/;

use XTracker::Config::Local qw/config_var enable_edit_purchase_order/;

use XTracker::Database::Pricing qw( set_markdown );
use XTracker::Database::PurchaseOrder qw/:create confirm_purchase_order/;
use DateTime;
use DateTime::Format::Pg;
use DateTime::Format::ISO8601;
use XTracker::Utilities 'ff';
use XTracker::Logfile 'xt_logger';
use Data::UUID;
use Data::Dump 'pp';

use XT::DC::Messaging::Spec::PurchaseOrder;

extends 'NAP::Messaging::Base::Consumer';
with 'NAP::Messaging::Role::WithModelAccess';

sub routes {
    return {
        destination => {
            purchase_order => {
                code => \&purchase_order,
                spec => XT::DC::Messaging::Spec::PurchaseOrder->purchase_order,
            },
        },
    };
}

# Catch an error if it's for purchase order and put it on a different error queue
sub _failure_handler {
    my ($status) = @_;

    return sub {
        my ($orig, $self, $ctx, $errors) = @_;

        $ctx->log->info('failure_handler - Caught something on the DLQ!');

        my $original_request = $ctx->request;
        my $rh_original_message = $original_request->data;
        my $headers = $ctx->stash->{headers};

        unless ($headers->{'type'} eq 'purchase_order'
                    or $rh_original_message->{'@type'} eq 'purchase_order') {
            return $self->$orig($ctx, $errors);
        }

        my %payload_message = (
            original_message    => $rh_original_message,
            destination         => $original_request->uri->as_string,
            method              => $original_request->method,
            ( defined $errors ?
                  (errors              => $errors)
                      : ()),
            ( defined $status ?
                  (status              => $status)
                      : ()),
        );
        # prepare response message
        my %return_message = (
            rx_failure      => 1,
            errors          => [ 'Invalid Purchase Order Format' ],  # should be overridden by %payload_message
            %payload_message,
            status          => $MESSAGE_RESPONSE_STATUS_ERROR,
            po_number       => $rh_original_message->{po_number},
        );

        # send the message back to fulcrum
        $self->model('MessageQueue')->transform_and_send(
            'XT::DC::Messaging::Producer::PurchaseOrder::ImportResponse',
            \%return_message
        );
    }
}

around handle_processing_failure => _failure_handler(500);
around handle_validation_failure => _failure_handler(400);

sub purchase_order {
    my ($self, $m, $h) = @_;

    my $schema = $self->model('Schema')->schema;

    return unless $schema->resultset('Public::Channel')->find($m->{channel_id});

    my $guard = $schema->txn_scope_guard;

    my ($name, $meth);
    if (exists $m->{vouchers}) {
        $name = 'Voucher::PurchaseOrder';
        $meth = "voucher_po_create";
    }
    else {
        $name = 'Public::PurchaseOrder';
        $meth = "product_po_create";
    }

    my $status = $m->{status};
    my $err;
    try {

        my $rs = $schema->resultset($name);
        if( my $po = $rs->find({ purchase_order_number => $m->{po_number} }) ) {
            if ($status eq 'Cancelled') {
                # If we get this far, and fulcrum thinks there is no stock then
                # log the action and go ahead and cancel.
                # Eventually fulcrum will either use the stock service or
                # product service to determine this info, rather than the stock.
                $po->cancel_po();
                xt_logger->info("Successfully cancelled purchase order $m->{po_number}");
            }
            elsif ($status eq 'Confirmed') {
                confirm_purchase_order({
                    dbh => $schema->storage->dbh,
                    purchase_order_id => $po->id,
                    operator_id => $m->{confirmed_by},
                });

                # If purchase order is set to "confirmed" and is cancelled
                # and we want to uncancel it.
                if($po->cancel){
                    $po->uncancel_po();
                    xt_logger->info("Successfully uncancelled purchase order $m->{po_number}");
                }
            }
            elsif ($status eq 'On Order'
                or $status eq 'Placed') {
                # PO's are not updateable - can only create or cancel them in XT.
                die "PO $m->{po_number} already exists - can't recreate it\n";
            }
            else {
                # ???
            }
        }
        elsif (! ($status eq 'On Order' or $status eq 'Placed' or $status eq 'Confirmed')) {
            die "Unexpected status '$status' for PO '$m->{po_number}' - expecting On Order or Placed\n";
        }
        else {
            # Delegate to the PO-type specific handler function
            $self->$meth( $m );
        }
        $err=0;
    }
    catch {
        $err=1;my $error = $_;
        # Create a new error_id for each incident. Then pass that around in the
        # log, message to Fulcrum, email etc. so we can tie them together.
        state $uuid_generator = Data::UUID->new;
        my $error_id = 'XT-PO-IMPORT-ERROR-' . $uuid_generator->create_hex;

        my %msg = (
            status      => $MESSAGE_RESPONSE_STATUS_ERROR,
            message     => "$_", # if error is an object, stringify it...
            po_number   => $m->{po_number},
            # Fulcrum doesn't know about error_id yet (which is why I've bunged
            # it into $msg{message}... But it would be nice to display it to the
            # user without all of the stack trace stuff
            error_id    => $error_id,
        );

        # If we send the stack trace separately, Fulcrum can log it or show it
        # to tech users only.
        $msg{stack_trace} = $error->stack_trace if $error->can('stack_trace');

        $msg{user_message} = "XTracker encountered an error importing purchase order $m->{po_number}";

        # There was an error, so log it as an error
        xt_logger->error(
            "Purchase Order $msg{po_number} failed to import: $error - $error_id"
        );
        # If we're tracing, log the full contents of the failure message
        xt_logger->debug(
            "Purchase order failure message for error $error_id: " . pp(\%msg)
        );

        $self->generate_po_import_response( %msg );

    };
    # return without committing the transaction if an exception was caught
    return if $err;

    $self->generate_po_import_response(
        status      => $MESSAGE_RESPONSE_STATUS_SUCCESS,
        po_number   => $m->{po_number},
    );

    $guard->commit;

    # Record the successful import with a brief INFO message.
    xt_logger->info(
        "Successfully consumed purchase order message for $name $m->{po_number}"
    );
}

sub voucher_po_create {
    my ($self, $m) = @_;

    my $currency = $self->model('Schema::Public::Currency')
                     ->find_by_name( config_var('Currency', 'local_currency_code') )
                     ->id;

    my $po = $self->model('Schema::Voucher::PurchaseOrder')->create({
        purchase_order_number => $m->{po_number},
        channel_id            => $m->{channel_id},
        date                  => $m->{date},
        created_by            => $m->{created_by},
        status_id             => $PURCHASE_ORDER_STATUS__ON_ORDER,
        currency_id           => $currency,
    });

    my $rs = $self->model('Schema::Voucher::Product');

    my $window_start = DateTime->now;
    my $window_end = $window_start->clone->add(days => 60);

    # Need to create a stock order for each voucher.
    for my $v ( @{ $m->{vouchers} } ) {
        my $v_prod = $rs->find( $v->{pid} ) ||
            die "No Voucher::Product with pid $v->{pid} found!";

        # StockOrder is linked to SuperPurchaseOrder
        # stock_order_item links a stock_order to a {voucher,public}.variant
        #
        # For 'classic' products, a StockOrder is the product, and
        # StockOrderItem is each variant. So for vouchers we need one of each
        # (as a voucher only ever has one variant)
        #
        my $so = $po->create_related(stock_orders => {
            voucher_product_id => $v->{pid},
            status_id => $STOCK_ORDER_STATUS__ON_ORDER,
            type_id => $STOCK_ORDER_TYPE__MAIN,
            cancel => 0,
            start_ship_date => $window_start,
            cancel_ship_date => $window_end,
            stock_order_items => [ {
                voucher_variant_id => $v_prod->variant->id,
                quantity => scalar @{ $v->{codes} },
                status_id => $STOCK_ORDER_ITEM_STATUS__ON_ORDER,
            } ],
        });

        my $soi = $so->stock_order_items->first;

        my $codes_rs = $v_prod->codes;
        $codes_rs->create( { stock_order_item_id => $soi->id, created => $m->{date}, code => $_ } )
            foreach @{ $v->{codes} };
    }
}

sub product_po_create {
    my ($self, $m) = @_;

    my $schema = $self->model('Schema')->schema;
    my $prod_rs = $schema->resultset('Public::Product');

    # ship_origin goes into the "description" field…
    my $po_args={
        status_id => 1,
        comment => '',
        exchange_rate => undef, # historical ruins
        type_id => 1,
        cancel => 0,
        confirmed => (defined $m->{confirmed_by} ? 1 : 0),
        confirmed_operator_id => $m->{confirmed_by},
        purchase_order_nr => $m->{po_number},
        description => ff($m->{ship_origin}),
        placed_by => ff($m->{placed_by}),
        channel_id => $m->{channel_id},
        date => _conv_date($m->{date}),
    };
    $po_args->{currency_id} = $schema->resultset('Public::Currency')
        ->find_by_name( config_var('Currency', 'local_currency_code') )
            ->id;
    for my $po_field (qw(designer season supplier act)) {
        $po_args->{"${po_field}_id"}=$schema->lookup_dictionary_by_name($po_field,ff($m->{$po_field}));
    }

    # also send payment_*_id, and update the products mentioned in this PO with the new values
    my $product_args={ };
    for my $prod_field (qw(payment_term payment_settlement_discount payment_deposit)) {
        $product_args->{"${prod_field}_id"}=$schema->lookup_dictionary_by_name($prod_field,ff($m->{$prod_field}));
    }

    my $stock_order_args=[ ];
    for my $stock_slot (@{$m->{stock}}) {
        my $so_args={
            status_id => 1,
            comment => '',
            type_id => 1,
            consignment => 0,
            cancel => 0,
            confirmed => (defined $m->{confirmed_by} ? 1 : 0),
            product_id => $stock_slot->{product_id},
        };
        for my $so_field (qw(start_ship_date cancel_ship_date)) {
            $so_args->{$so_field}=_conv_date($stock_slot->{$so_field});
        }
        for my $so_field (qw(shipment_window_type size_scheme)) {
            $so_args->{"${so_field}_id"}=$schema->lookup_dictionary_by_name($so_field,ff($stock_slot->{$so_field}));
        }
        my $size_scheme = $schema->resultset('Public::SizeScheme')->find( $so_args->{'size_scheme_id'} );

        $so_args->{markdown} = {
            map { $_ => $stock_slot->{markdown}{$_} } qw{category percentage start_date}
        } if keys %{$stock_slot->{markdown}};

        my $so_item_args = $so_args->{items} = [ ];

        for my $item_slot (@{$stock_slot->{items}}) {
            next if $item_slot->{quantity} == 0;
            my $item_args={
                status_id => 1,
                type_id => 0,
                cancel => 0,
                original_quantity => $item_slot->{quantity},
            };
            $item_args->{quantity} = $item_slot->{quantity};
            # Find the size id the right way rather than the made-up way:
            {
                if ( $size_scheme ) {
                    # We use 'first' as there should only be one...
                    my $size = $size_scheme->sizes->search({ size => ff($item_slot->{'size'}) })->first;
                    if ( $size ) {
                        $item_args->{'size_id'} = $size->id;
                    } else {
                        xt_logger->warn(sprintf(
                            "Couldn't find a size in size scheme %s called %s",
                            $size_scheme->id,
                            $item_slot->{'size'},
                        ));
                        # This is the bad old way, that we'll use as a fallback
                        $item_args->{'size_id'} = $schema
                            ->lookup_dictionary_by_name(
                                'size',
                                ff($item_slot->{'size'})
                            );
                    }
                    my $pid = $stock_slot->{product_id};
                    my $product = $prod_rs->find($pid)
                        or die "Product $pid not found";

                    # Let's use XT's idea of the variant IDs instead of trying
                    # to force Fulcrum's
                    my $variant = $product->search_related(
                        'variants',
                        {
                            size_id => $item_args->{'size_id'},
                            type_id => $VARIANT_TYPE__STOCK,
                        },
                    )->single;
                    unless ( $variant ) {
                        die sprintf(
                            'Variant not found for product %s, size id %s',
                            $pid,
                            $size->id,
                        );
                    }
                    $item_args->{variant_id} = $variant->id;
                } else {
                    warn "Couldn't find size scheme with id " . $so_args->{'size_scheme_id'};
                }
            }

            push @$so_item_args,$item_args;
        }

        push @$stock_order_args,$so_args;
    }

    my $stock_manager = XTracker::WebContent::StockManagement::Broadcast->new({
        schema => $schema,
        channel_id => $po_args->{channel_id},
    });

    eval {
        $schema->txn_do(
            sub {
                my $dbh=$schema->storage->dbh;

                # yes, these functions are obsolete
                #
                # I'm using them because I want this to have the exact
                # same effect as Ben's original import script
                # (script/data_transfer/purchase_order/import_po.pl),
                # and that script uses these function

                my $po_id=create_purchase_order($dbh,$po_args);

                # If the editPO functionality is disabled we need to
                # update the "not editable in fulcrum" flag so we treat
                # every purchase order as being legacy, since it cannot
                # be edited in fulcrum

                if(enable_edit_purchase_order){
                   my $sth=$dbh->prepare("SELECT COUNT(*) from purchase_orders_not_editable_in_fulcrum WHERE number = ?");
                   $sth->execute($po_args->{purchase_order_nr});
                   if( $sth->fetchrow_arrayref->[0] == 0 ){
                       my $sth_insert_po_number = $dbh->prepare("INSERT INTO purchase_orders_not_editable_in_fulcrum (number) VALUES (?)");
                       $sth_insert_po_number->execute($po_args->{purchase_order_nr});
                   }
                }

                for my $so (@$stock_order_args) {

                    my $so_id=create_stock_order($dbh,$po_id,$so);
                    $prod_rs->find({id=>$so->{product_id}})
                        ->update($product_args);

                    for my $item (@{$so->{items}}) {
                        create_stock_order_item($dbh,$so_id,$item);
                    }

                    # Broadcast the new stock levels
                    $stock_manager->stock_update(
                        product_id => $so->{product_id},
                        full_details => 1,
                    );

                    # Add markdowns
                    set_markdown( $dbh, {
                        product_id => $so->{product_id},
                        percentage => $so->{markdown}{percentage},
                        start_date => $so->{markdown}{start_date},
                        category   => $so->{markdown}{category},
                    }) if keys %{$so->{markdown}};

                }

                $stock_manager->commit;
            });
    };
    if ( my $e = $@ ) {
        $stock_manager->rollback;
        die "Couldn't create purchase order $m->{po_number}: $e\n";
    }

    $stock_manager->disconnect;

}

=head2 generate_po_import_repsonse

Sends a PO message back to the integration service

=cut

sub generate_po_import_response {
    my ($self, %args) = @_;

    $self->log->debug('Generating PO import response: '.pp(\%args));

    # prepare response message
    my %return_message = (
        %args,
    );

    # send the message back to fulcrum
    $self->model('MessageQueue')->transform_and_send(
        'XT::DC::Messaging::Producer::PurchaseOrder::ImportResponse',
        \%return_message
    );
}

sub _conv_date {
    DateTime::Format::Pg->new->format_datetime(
        DateTime::Format::ISO8601->new->parse_datetime(
            shift
        )
      );
}
