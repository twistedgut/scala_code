package XTracker::Database::StockProcessCompletePutaway;

use strict;
use warnings;
use Carp;

use Perl6::Export::Attrs;
use Storable qw(dclone);

use XTracker::Database::StockProcess qw/:DEFAULT :putaway get_delivery_item_id/;
use XTracker::Database::Delivery qw/
    get_delivery_channel
    delivery_item_is_complete
    complete_delivery_item
    delivery_is_complete
    complete_delivery
/;
use XTracker::Database::Product qw/product_present/;
use XTracker::Database::Stock qw/:DEFAULT get_stock_location_quantity check_stock_location insert_quantity update_quantity/;
use XTracker::Database::Return;
use XTracker::Database::Logging qw/log_stock log_delivery log_location/;
use XTracker::Database::RTV qw/insert_rtv_quantity get_rtv_stock_process_row update_fields log_rtv_putaway/;

use XTracker::Comms::FCP qw/amq_update_web_stock_level/;
use XTracker::Constants::FromDB qw(
    :delivery_action
    :flow_status
    :pws_action
    :return_item_status
    :stock_action
    :stock_process_status
    :stock_process_type
    :putaway_type
);

use XTracker::WebContent::StockManagement;
use XTracker::Logfile qw(xt_logger);


### Refactored away from XTracker::Stock::Action::SetPutaway
#   As its required in XT::DC::Messaging::Consumer::XTWMS

sub complete_putaway :Export(:DEFAULT) {
    my ($schema, $stock_manager, $process_group_id, $operator_id, $msg_factory, $putaway_type, $putaway_ref) = @_;

    # is $dbh transactional, when does it commit? (no, never)
    my $dbh = $schema->storage->dbh;
    my $commit_stock_manager = 0;

    my $sp_rs = $schema->resultset('Public::StockProcess');
    $process_group_id =~ s/^p-//i;

    my $voucher = $sp_rs->get_group($process_group_id)->get_voucher;
    if ( $voucher ) {
        # Vouchers don't need to return variant_id or variant_location
        complete_voucher_putaway({
            voucher     => $voucher,
            group_id    => $process_group_id,
            operator_id => $operator_id,
            msg_factory => $msg_factory,
        });

        return;
    }

    my $stock_process = $sp_rs->search({
        group_id => $process_group_id,
        status_id => {'!=' => $STOCK_PROCESS_STATUS__PUTAWAY}
    });
    # everything putaway, nothing to do.
    unless ($stock_process->count) {
        return;
    }

    my $delivery_id = get_delivery_id( $dbh, $process_group_id );
    my $delivery_channel_id = $schema->resultset('Public::Channel')
                                     ->find({ name => get_delivery_channel($dbh, $delivery_id)})
                                     ->id;

    $putaway_type ||= get_putaway_type($dbh, $process_group_id)->{putaway_type};
    $putaway_ref  ||= _get_putaway_ref($dbh, $process_group_id, $putaway_type);

    my ($var_id, $location, $active_channel_id);

    foreach my $sp (@$putaway_ref) {
        # stock process of quantity zero doesn't need any action
        xt_logger()->trace("PUTAWAY: completing stock process id ".$sp->{id}
            ." for variant ".$sp->{variant_id}." with quantity ".($sp->{quantity}//"-"));
        next unless $sp->{quantity};

        $var_id   = $sp->{variant_id};
        $location = $sp->{location};

        # ||= fine as only one pid per sp thus one $active_channel_id
        $active_channel_id ||= $schema->resultset('Public::Variant')
                                ->find($var_id)
                                ->product->get_current_channel_id();

        unless ( defined($stock_manager)){
            $stock_manager = XTracker::WebContent::StockManagement->new_stock_manager({
                schema      => $schema,
                channel_id  => $active_channel_id,
            });
            $commit_stock_manager = 1;
        }

        my $sp_object = $sp_rs->find($sp->{id});
        my $args = _init_putaway_args(
            $sp,
            $sp_object,
            $putaway_type,
            $delivery_id,
            $active_channel_id,
            $operator_id,
        );

        _increment_quantity( $schema, $dbh, $args, $sp, $delivery_channel_id );

        if (   $putaway_type == $PUTAWAY_TYPE__SAMPLE
            || $putaway_type == $PUTAWAY_TYPE__STOCK_TRANSFER) {
            _transfer_putaway($dbh, $sp, $delivery_channel_id, $operator_id);
        }
        elsif ((   $putaway_type == $PUTAWAY_TYPE__GOODS_IN
                || $putaway_type == $PUTAWAY_TYPE__PROCESSED_QUARANTINE)
               and ($sp->{stock_process_type_id} == $STOCK_PROCESS_TYPE__RTV_NON_DASH_FAULTY)
        ) {
            _rtv_non_faulty_putaway($dbh, $sp, $delivery_channel_id, $operator_id);
        }
        elsif ( $sp->{stock_process_type_id} == $STOCK_PROCESS_TYPE__DEAD ) {
            ## insert rtv log record
            log_rtv_putaway({
                dbh              => $dbh,
                stock_process_id => $sp->{id},
                variant_id       => $sp->{variant_id},
                quantity         => $sp->{quantity},
                operator_id      => $operator_id,
                channel_id       => $delivery_channel_id,
            });
        }

        ## set item as completed
        complete_putaway_item( $dbh, $sp->{id}, $sp->{location_id} );
        set_stock_process_status( $dbh, $sp->{id}, $STOCK_PROCESS_STATUS__PUTAWAY );

        ## update return item as put away
        if (   $putaway_type == $PUTAWAY_TYPE__RETURNS
            || $putaway_type == $PUTAWAY_TYPE__STOCK_TRANSFER){
            update_return_item_status($dbh, $sp->{return_item_id}, $RETURN_ITEM_STATUS__PUT_AWAY);
            log_return_item_status($dbh, $sp->{return_item_id}, $RETURN_ITEM_STATUS__PUT_AWAY, $args->{operator_id});
        }
        if (putaway_completed( $dbh, $sp->{id})) {
            _complete_stock_process( $dbh, $sp);
        }
        if ($args->{status_id} eq $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS) {
            _putaway_main_stock( $schema, $dbh, $stock_manager, $args, $sp, $active_channel_id, $delivery_channel_id);
        }
        if ( $args->{status_id} == $FLOW_STATUS__RTV_GOODS_IN__STOCK_STATUS
          or $args->{status_id} == $FLOW_STATUS__RTV_PROCESS__STOCK_STATUS
        ) {
            _rtv_putaway($dbh, $sp, $putaway_type, $delivery_channel_id, $args, $operator_id);
        } ## END IF
    } ## END foreach my $sp (@$putaway_ref)

    my $sp_type_id = get_process_group_type( $dbh, $process_group_id );

    if ( grep { $_ eq $sp_type_id } ($STOCK_PROCESS_TYPE__MAIN, $STOCK_PROCESS_TYPE__FASTTRACK, $STOCK_PROCESS_TYPE__SURPLUS) ) {
        my %delivery_args = ();

        $delivery_args{type_id }    = $sp_type_id;
        $delivery_args{quantity}    = get_process_group_total( $dbh, $process_group_id );
        $delivery_args{operator}    = $operator_id;
        $delivery_args{action}      = $DELIVERY_ACTION__PUTAWAY;
        $delivery_args{delivery_id} = get_delivery_id( $dbh, $process_group_id );

        log_delivery( $dbh, \%delivery_args );
    } ## END if

    if ($commit_stock_manager) {
        $stock_manager->commit;
        $stock_manager->disconnect;
    }

    return $var_id, $location;
}

## Called from complete_putaway
sub complete_voucher_putaway {
    my ( $args ) = @_;

    my $group_id    = $args->{group_id};
    $group_id =~ s/^p-//i;
    my $operator_id = $args->{operator_id};
    my $voucher     = $args->{voucher};
    my $msg_factory = $args->{msg_factory};

    my $variant = $voucher->variant;
    my $channel = $voucher->channel;

    my $schema = $voucher->result_source->schema;
    my $dbh = $schema->storage->dbh;

    # Get the resultset with the group's StockProcess rows
    my $sp_group_rs = $schema->resultset('Public::StockProcess')
                             ->get_group($group_id);

    my $delivery_item = $sp_group_rs->related_resultset('delivery_item')
                                    ->slice(0,0)
                                    ->single;
    my $delivery = $delivery_item->delivery;

    # Get the incomplete putaway items for the group
    my $putaway_rs = $sp_group_rs->related_resultset('putaways')->incomplete;
    #my $putaway_ref = get_putaway( $dbh, $group_id );

    PUTAWAY:
    while ( my $putaway = $putaway_rs->next ) {
        my $location = $putaway->location;

        my $stock_process = $putaway->stock_process;
        $stock_process->mark_as_putaway;

        # Update stock quantity at location
        # This should always return a single row - see TP-682
        my $quantity = $location->update_or_create_related('quantities',
            { location_id => $location->id,
              variant_id  => $variant->id,
              channel_id  => $channel->id,
              status_id   => $stock_process->stock_status_for_putaway,
          },
            { key=>'quantity_id_key' }
        );
        # i.e. UPDATE quantity SET quantity = quantity + 10 - let pg deal with
        # concurrency
        $quantity->update({quantity => \[ 'quantity + ?', [ dummy => $putaway->quantity ] ] });

        # Mark item as completed
        $putaway->update({complete=>1});

        # Check if anything is now complete
        if ( $stock_process->putaway_complete ) {
            $stock_process->complete_stock_process;

            if ( $delivery_item->stock_processes_complete ) {
                $delivery_item->complete;
                $delivery->complete if $delivery->delivery_items_complete;
            }
        }

        ## voucher is live && it's not faulty
        if ( $voucher->live
             && $quantity->status_id == $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS ) {

            amq_update_web_stock_level( $msg_factory, {
                    quantity_change => $putaway->quantity,
                    variant_id      => $variant->id,
                    channel_id      => $channel->id,
                } );

            $schema->resultset('Public::LogPwsStock')->log_stock_change(
                variant_id      => $variant->id,
                channel_id      => $channel->id,
                pws_action_id   => $PWS_ACTION__PUTAWAY,
                quantity        => $putaway->quantity,
                notes           => 'Additional Putaway',
                operator_id     => $operator_id,
            );
        }

        my $stock_action_id = $stock_process->type_id == $STOCK_PROCESS_TYPE__DEAD
                            ? $STOCK_ACTION__DEAD__DASH__NO_RTV
                            : $STOCK_ACTION__PUT_AWAY;
        $schema->resultset('Public::LogStock')->log({
            variant_id      => $variant->id,
            stock_action_id => $stock_action_id,
            operator_id     => $operator_id,
            notes           => $delivery->id,
            quantity        => $putaway->quantity,
            channel_id      => $channel->id,
        });
    }

    my $sp_type_id = $sp_group_rs->slice(0,0)->first->type_id;
    if ( grep { $_ eq $sp_type_id } ($STOCK_PROCESS_TYPE__MAIN, $STOCK_PROCESS_TYPE__SURPLUS) ) {
        $sp_group_rs->log_putaway({
            type_id     => $sp_type_id,
            operator_id => $operator_id,
        });
    }


    # I should probably use the same StockManagement object as in
    # complete_putaway, but this one will work just as well and I
    # don't run the risk of writing to the webdb by mistake
    require XTracker::WebContent::StockManagement::Broadcast;
    my $broadcast = XTracker::WebContent::StockManagement::Broadcast->new({
        schema => $schema,
        channel_id => $channel->id,
    });
    $broadcast->stock_update(
        quantity_change => 0,
        product => $voucher,
        full_details => 1,
    );
    $broadcast->commit();

    return;
}

sub _get_putaway_ref :Export(:DEFAULT) {
    my ($dbh, $process_group_id, $putaway_type) = @_;

    my $putaway_ref;

    if (   $putaway_type == $PUTAWAY_TYPE__RETURNS
        || $putaway_type == $PUTAWAY_TYPE__STOCK_TRANSFER) {
        $putaway_ref = get_return_putaway( $dbh, $process_group_id );
    }
    elsif ($putaway_type == $PUTAWAY_TYPE__SAMPLE) {
        $putaway_ref = get_sample_putaway( $dbh, $process_group_id );
    }
    elsif ($putaway_type == $PUTAWAY_TYPE__PROCESSED_QUARANTINE) {
        $putaway_ref = get_quarantine_putaway( $dbh, $process_group_id );
    }
    else {
        $putaway_ref = get_putaway( $dbh, $process_group_id );
    }

    return $putaway_ref;
}

sub _increment_quantity {
    my ($schema, $dbh, $args, $sp, $delivery_channel_id) = @_;
    if (defined($args->{ext_quantity}) && $args->{ext_quantity} != $sp->{quantity}) {
        ### Quantity table must have the correct quantity.
        ### Other logs with have the expected quantity.
        $args->{quantity} = $args->{ext_quantity};
        $schema->resultset('Public::LogPutawayDiscrepancy')->create({
            stock_process_id => $sp->{id},
            variant_id       => $sp->{variant_id},
            quantity         => $sp->{quantity},
            ext_quantity     => $args->{ext_quantity},
            channel_id       => $args->{channel_id},
        });
    }

    # If this is an RTV putaway, then we want to put away into the delivery channel and
    # not the current channel. (These differ if there was a channel transfer after the
    # delivery shipped.) For safety, we make a copy of the $args hash and modify that.
    if (  $args->{status_id} == $FLOW_STATUS__RTV_GOODS_IN__STOCK_STATUS ||
          $args->{status_id} == $FLOW_STATUS__RTV_PROCESS__STOCK_STATUS     ) {
        $args = { %$args };
        $args->{channel_id} = $delivery_channel_id;
    }

    xt_logger()->trace("PUTAWAY: going to add quantity now: quantity ".($sp->{quantity}//"-")
        .", ext_quantity ".($args->{ext_quantity}//"-"));
    if (check_stock_location( $dbh, $args )) {
        update_quantity( $dbh, $args);
    }
    else {
        insert_quantity( $dbh, $args);
    }
}


sub _init_putaway_args {
    my ($sp, $sp_object, $putaway_type, $delivery_id, $active_channel_id, $operator_id) = @_;

    my %args;

    $args{channel_id}  = $active_channel_id;
    $args{variant_id}  = $sp->{variant_id};
    $args{location_id} = $sp->{location_id};
    $args{location}    = $sp->{location};
    $args{new_loc}     = $sp->{location};
    $args{quantity}    = $sp->{quantity};
    $args{ext_quantity}= $sp->{ext_quantity};
    $args{operator_id} = $operator_id;
    $args{initial_status_id} = $args{current_status_id}
                             = $args{next_status_id}
                             = $args{status_id}
                             = $sp_object->stock_status_for_putaway;

    if ($args{quantity} > 0) {
        $args{type} = 'inc';        # increment
    }
    else {
        $args{type} = 'dec';        # decrement
    }

    if ($putaway_type == $PUTAWAY_TYPE__RETURNS) {
        $args{stock_action}     = $STOCK_ACTION__CUSTOMER_RETURN;
        $args{pws_action}       = $PWS_ACTION__RETURN;
        $args{stock_log_notes}  = $sp->{shipment_id};
        $args{pws_log_notes}    = $sp->{shipment_id};
    }
    elsif ($putaway_type == $PUTAWAY_TYPE__STOCK_TRANSFER) {
        $args{stock_action}     = $STOCK_ACTION__SAMPLE_RETURN;
        $args{pws_action}       = $PWS_ACTION__SAMPLE;
        $args{stock_log_notes}  = $sp->{shipment_id};
        $args{pws_log_notes}    = "Return from sample " . $sp->{shipment_id};
    }
    elsif ($putaway_type == $PUTAWAY_TYPE__SAMPLE) {
        $args{stock_action}     = $STOCK_ACTION__PUT_AWAY;
        $args{pws_action}       = $PWS_ACTION__PUTAWAY;
        $args{stock_log_notes}  = "Vendor Sample";
        $args{pws_log_notes}    = "Vendor Sample";
    }
    elsif ($sp->{stock_process_type_id} == $STOCK_PROCESS_TYPE__QUARANTINE_FIXED) {
        $args{stock_action}     = $STOCK_ACTION__FIXED_QUARANTINE;
        $args{pws_action}       = $PWS_ACTION__FIXED_QUARANTINE;
        $args{stock_log_notes}  = "-";
        $args{pws_log_notes}    = "-";
    }
    else {
        $args{stock_action}     = $STOCK_ACTION__PUT_AWAY;
        $args{pws_action}       = $PWS_ACTION__PUTAWAY;
        $args{stock_log_notes}  = $delivery_id;
        $args{pws_log_notes}    = "Additional Putaway";
    }

    return \%args;
}

sub _rtv_quantity_origin {
    my ($sp, $putaway_type) = @_;

    return $sp->{stock_process_type_id} == $STOCK_PROCESS_TYPE__RTV_NON_DASH_FAULTY ? 'ST'
        : $sp->{stock_process_type_id} == $STOCK_PROCESS_TYPE__RTV_CUSTOMER_REPAIR  ? 'REP'
        : $putaway_type == $PUTAWAY_TYPE__RETURNS                                   ? 'CR'
        : $putaway_type == $PUTAWAY_TYPE__GOODS_IN                                  ? 'GI'
        : $putaway_type == $PUTAWAY_TYPE__PROCESSED_QUARANTINE                      ? 'GI'
        : $putaway_type == $PUTAWAY_TYPE__STOCK_TRANSFER                            ? 'GI'
        :                                                                           $putaway_type
    ;
}

sub _complete_stock_process {
    my ($dbh, $sp) = @_;

    complete_stock_process( $dbh, $sp->{id} );

    ## complete delivery_item if all dealt with
    if ( delivery_item_is_complete( $dbh, { type => 'stock_process', id => $sp->{id} } ) ) {
        complete_delivery_item( $dbh, { type => 'stock_process', id => $sp->{id} } );
    }

    ## complete delivery if all dealt with
    if ( delivery_is_complete( $dbh, { type => 'stock_process', id => $sp->{id} } ) ) {
        complete_delivery( $dbh, { type => 'stock_process', id => $sp->{id} } );
    }
}

sub _transfer_putaway {
    my ($dbh, $sp, $delivery_channel_id, $operator_id) = @_;

    ## decrement transfer pending location
    my $updated_quantity_id = update_quantity( $dbh, {
        variant_id        => $sp->{variant_id},
        location          => 'Transfer Pending',
        quantity          => -1,
        type              => 'dec',
        channel_id        => $delivery_channel_id,
        current_status_id => $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS,
        next_status_id    => $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS,
    });

    ## check if transfer pending location now 0 - delete it if it is
    my $old_quantity = get_stock_location_quantity( $dbh, {
        variant_id  => $sp->{variant_id},
        location    => 'Transfer Pending',
        channel_id  => $delivery_channel_id,
        status_id => $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS,
    });
    if ( $updated_quantity_id && $old_quantity == 0 ) {
        delete_quantity( $dbh, {
            variant_id  => $sp->{variant_id},
            location    => 'Transfer Pending',
            channel_id  => $delivery_channel_id,
            status_id => $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS,
        });

        log_location( $dbh, {
            variant_id  => $sp->{variant_id},
            location    => 'Transfer Pending',
            channel_id  => $delivery_channel_id,
            operator_id => $operator_id,
        });
    }
}

sub _rtv_non_faulty_putaway {
    my ($dbh, $sp, $delivery_channel_id, $operator_id) = @_;

    ## decrement 'RTV Transfer Pending' location
    my $updated_quantity_id = update_quantity( $dbh, {
        variant_id => $sp->{variant_id},
        location   => 'RTV Transfer Pending',
        quantity   => ($sp->{quantity}*-1),
        type       => 'dec',
        channel_id => $delivery_channel_id,
        current_status_id => $FLOW_STATUS__RTV_TRANSFER_PENDING__STOCK_STATUS,
        next_status_id => $FLOW_STATUS__RTV_TRANSFER_PENDING__STOCK_STATUS,
    });

    ## check if 'RTV Transfer Pending' location now 0 - delete it if it is
    my $old_quantity = get_stock_location_quantity( $dbh, {
        variant_id  => $sp->{variant_id},
        location    => 'RTV Transfer Pending',
        channel_id  => $delivery_channel_id,
        status_id => $FLOW_STATUS__RTV_TRANSFER_PENDING__STOCK_STATUS,
    });
    if ( $updated_quantity_id && $old_quantity == 0 ) {
        delete_quantity( $dbh, {
            variant_id  => $sp->{variant_id},
            location    => 'RTV Transfer Pending',
            channel_id  => $delivery_channel_id,
            status_id => $FLOW_STATUS__RTV_TRANSFER_PENDING__STOCK_STATUS,
        });

        log_location( $dbh, {
            variant_id  => $sp->{variant_id},
            location    => 'RTV Transfer Pending',
            channel_id  => $delivery_channel_id,
            operator_id => $operator_id,
        });
    }

    ## insert rtv log record
    log_rtv_putaway({
        dbh              => $dbh,
        stock_process_id => $sp->{id},
        variant_id       => $sp->{variant_id},
        quantity         => $sp->{quantity},
        operator_id      => $operator_id,
        notes            => $sp->{location},
        channel_id       => $delivery_channel_id,
    });
}

sub _rtv_putaway {
    my ($dbh, $sp, $putaway_type, $delivery_channel_id, $args, $operator_id) = @_;

    my $delivery_item_id = get_delivery_item_id( $dbh, $sp->{id} );

    ## insert rtv_quantity record
    my $rtv_quantity_id = insert_rtv_quantity({
        dbh                     => $dbh,
        location_id             => $sp->{location_id},
        variant_id              => $sp->{variant_id},
        quantity                => $sp->{quantity},
        delivery_item_id        => $delivery_item_id,
        transfer_di_fault_data  => 1,
        origin                  => _rtv_quantity_origin( $sp, $putaway_type),
        channel_id              => $delivery_channel_id,
        initial_status_id       => $args->{status_id},
    });

    ## transfer fault description from rtv_stock_process.notes if item is from Quarantine
    if ( $sp->{stock_process_type_id} == $STOCK_PROCESS_TYPE__RTV ) {
        my $rtv_stock_process_row_ref = get_rtv_stock_process_row({
            dbh              => $dbh,
            stock_process_id => $sp->{id},
        });

        if ( $rtv_stock_process_row_ref->{originating_uri_path} eq '/StockControl/Quarantine/SetQuarantine' ) {
            my %update_fields = ();
            $update_fields{'rtv_quantity'}{$rtv_quantity_id}{fault_description} = $rtv_stock_process_row_ref->{notes};

            update_fields({
                dbh             => $dbh,
                update_fields   => \%update_fields,
            });
        } ## END if
    } ## END if

    if ( $sp->{stock_process_type_id} != $STOCK_PROCESS_TYPE__RTV_NON_DASH_FAULTY ) {
        ## insert rtv log record
        log_rtv_putaway({
            dbh                 => $dbh,
            stock_process_id    => $sp->{id},
            variant_id          => $sp->{variant_id},
            quantity            => $sp->{quantity},
            operator_id         => $operator_id,
            channel_id          => $delivery_channel_id,
        });
    } ## END IF
}

sub _putaway_main_stock {
    my ($schema, $dbh, $stock_manager, $args, $sp, $active_channel_id, $delivery_channel_id) = @_;

    return unless $args->{status_id} eq $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS;

    # update web stock if its a live product
    $stock_manager->stock_update(
        quantity_change =>(defined ($args->{ext_quantity}) ? $args->{ext_quantity} : $sp->{quantity}),
        variant_id      => $sp->{variant_id},
        skip_non_live   => 1,
        full_details    => 1,
        pws_action_id   => $args->{pws_action},
        operator_id     => $args->{operator_id},
        notes           => $args->{pws_log_notes},
    );

    if ( $active_channel_id != $delivery_channel_id ) {
        _automatic_channel_transfer($dbh, $args, $delivery_channel_id);
    }
    else {
        log_stock( $dbh, {
            variant_id  => $args->{variant_id},
            quantity    => $args->{quantity},
            action      => $args->{stock_action},
            operator_id => $args->{operator_id},
            notes       => $args->{stock_log_notes},
            channel_id  => $args->{channel_id},
        });
    }
}


sub _automatic_channel_transfer {
    my ($dbh, $args, $delivery_channel_id) = @_;

    my $quantity = $args->{quantity};
    # log putaway to delivery channel
    log_stock( $dbh, {
        variant_id  => $args->{variant_id},
        quantity    => $quantity,
        action      => $args->{stock_action},
        operator_id => $args->{operator_id},
        notes       => $args->{stock_log_notes},
        channel_id  => $delivery_channel_id,
    });

    # log unit coming off delivery channel
    log_stock( $dbh, {
        variant_id  => $args->{variant_id},
        quantity    => ($quantity * -1),
        action      => $STOCK_ACTION__CHANNEL_TRANSFER_OUT,
        operator_id => $args->{operator_id},
        notes       => 'Automatic channel transfer',
        channel_id  => $delivery_channel_id,
    });

    # log unit going onto active channel
    log_stock( $dbh, {
        variant_id  => $args->{variant_id},
        quantity    => $quantity,
        action      => $STOCK_ACTION__CHANNEL_TRANSFER_IN,
        operator_id => $args->{operator_id},
        notes       => 'Automatic channel transfer',
        channel_id  => $args->{channel_id},
    });
}



1;
