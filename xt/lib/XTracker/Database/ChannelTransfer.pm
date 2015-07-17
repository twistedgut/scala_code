package XTracker::Database::ChannelTransfer;

use NAP::policy "tt", 'exporter';

use Perl6::Export::Attrs;
use List::MoreUtils qw(uniq);

use XTracker::Database::Utilities;
use XTracker::Database qw(get_database_handle);
use XTracker::Constants::FromDB qw(
                                      :channel_transfer_status
                                      :stock_action
                                      :pws_action
                                      :flow_status
                                      :product_channel_transfer_status
                              );
use XTracker::Config::Local qw(local_timezone get_picking_printer config_var);
use XTracker::Database::Logging qw( log_stock log_location );
use XTracker::Comms::FCP qw( update_web_stock_level );
use XT::JQ::DC;
use XTracker::Database::Product qw( product_present );
use DateTime;
use XTracker::WebContent::StockManagement::Broadcast;
use XTracker::Database::Stock qw( get_allocated_item_quantity get_located_stock );
use XTracker::Database::Product qw( get_variant_list get_product_channel_info );
use XTracker::PrintFunctions;
use XTracker::Barcode;


# Check whether we can perform a given channel transfer. If so, then select the transfer and if we are using
# PRLs then run the complete transfer process.
sub select_transfer :Export() {
    my ( $args ) = @_;

    my $schema = $args->{schema};
    my $dbh = $schema->storage->dbh;

    my $iws_rollout_phase = $args->{iws_rollout_phase};
    my $prl_rollout_phase = $args->{prl_rollout_phase};
    my $msg_factory = $args->{msg_factory};

    my %print_data = ();

    # Get transfer details
    $print_data{transfer} = get_channel_transfer( $dbh, { transfer_id => $args->{transfer_id} } );

    # We use this a lot... save it in its own var
    my $product_id = $print_data{transfer}{product_id};
    $print_data{stock} = get_located_stock( $dbh, { type => 'product_id', id => $product_id }, 'stock_main' );
    $print_data{main_status_id} = $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS;
    $print_data{variants} =
        get_variant_list( $dbh, { type => 'product_id', id => $product_id }, { by => 'size_list'    } );

    # Check product is not still 'visible' on the 'from' channel
    my ($prod_transferred, $prod_channel) = get_product_channel_info( $dbh, $product_id );

    # Keep an array of all the errors for this transfer so we can display them to the user
    my @errors;
    if ( $prod_channel->{ $print_data{transfer}{from_channel} }{visible} == 1 ) {
        push @errors, 'PID '.$product_id.' is still visible on '.$print_data{transfer}{from_channel}.
                      ', please ensure product is invisible before selecting.';
    }

    # Check no allocated stock for PID/channel
    my $allocated_qty   = 0;
    my $allocated_data  = get_allocated_item_quantity( $dbh, $product_id );

    foreach my $variant_id ( keys %{ $allocated_data->{ $print_data{transfer}{from_channel} } } ) {
        $allocated_qty += $allocated_data->{ $print_data{transfer}{from_channel} }{ $variant_id };
    }

    if ( $allocated_qty > 0 ) {
        push @errors, 'PID '.$product_id." still has allocated stock, please resolve before selecting.\n";
    }
    my $product = $schema->resultset('Public::Product')->find( $product_id );
    my $variants = $product->variants;

    foreach my $quantity ( $variants->related_resultset('quantities')->all ) {
        next unless $quantity->quantity;
        next if $quantity->is_in_main_stock || $quantity->is_in_dead_stock;

        my $msg = "PID $product_id has units that are %s and cannot be transferred to another channel.";
        my $where
            = $quantity->is_in_transit_from_iws                                    ? 'in transit'
            : $quantity->is_transfer_pending || $quantity->is_rtv_transfer_pending ? 'transfer pending'
            : $quantity->is_in_quarantine                                          ? 'in Quarantine'
            : $quantity->is_in_sample || $quantity->is_in_creative                 ? 'booked out in sample area'
            :                                                                        'in RTV processing'
        ;
        push @errors, sprintf($msg, $where);
    }

    # Extra check if we're doing an automatic transfer (e.g. using IWS in DC1 or PRLs in DC2)
    if ( $iws_rollout_phase || $prl_rollout_phase ) {
        # Check there are no putaway processes remaining
        my @stock_processes = $schema
            ->resultset('Public::Product')
            ->incomplete_putaway_processes( $product_id );
        if ( @stock_processes ) {
            my @process_group_ids = uniq( map { $_->group_id } @stock_processes );
            push @errors,
                "PID $product_id still has items that need to be putaway before we"
              . " can commence the channel transfer. Process groups are: "
              . ( join ', ', @process_group_ids )
            ;
        }
    }

    my $transfer = $schema->resultset('Public::ChannelTransfer')->find($args->{transfer_id});
    push @errors, "PID $product_id  has already been selected" if $transfer->status_id != $CHANNEL_TRANSFER_STATUS__REQUESTED;

    # Return and avoid further processing if we have errors
    return (undef, \@errors) if ( @errors );

    # We can continue with the transfer
    $schema->txn_do(sub{

        # We have IWS so send it a message to do the work
        if ( $iws_rollout_phase ) {
            begin_auto_channel_transfer($schema,$args->{transfer_id},$args->{operator_id});
            $msg_factory->transform_and_send( 'XT::DC::Messaging::Producer::WMS::StockChange', {
                transfer_id => $args->{transfer_id},
            });
        }

        # We have PRL so send it a message to do the work
        elsif ( $prl_rollout_phase ) {
            begin_auto_channel_transfer( $schema, $args->{transfer_id}, $args->{operator_id} );
            complete_auto_channel_transfer( $schema, $args->{transfer_id}, $args->{operator_id} );
            $product->send_sku_update_to_prls();
        }

        # No IWS or PRL, so do manual process
        else {
            # create barcode if necessary
            my $barcode = create_barcode("channeltransfer".$args->{transfer_id}, $args->{transfer_id}, "small", 3, 1, 65);

            # print picking document
            my $printer_name = get_picking_printer( 'channel_transfer', $prod_channel->{$print_data{transfer}{from_channel} }{config_section} );
            my $printer = get_printer_by_name( $printer_name );
            if (!%{$printer||{}}) {
                die "Could not get printer details for printer '$printer_name'\n";
            }
            my $html    = create_document('channeltransfer-' . $args->{transfer_id}, 'print/channeltransfer.tt', \%print_data );
            my $result  = print_document( 'channeltransfer-' . $args->{transfer_id}, $printer->{lp_name}, 1, '', '' );

            # set status of transfer
            set_channel_transfer_status( $dbh, { transfer_id => $args->{transfer_id}, operator_id => $args->{operator_id}, status_id => $CHANNEL_TRANSFER_STATUS__SELECTED } );
        }
    });

    return ($product_id, \@errors);
}


### Subroutine : set_product_transfer_status #
# usage        : #
# description  : #
# parameters   : #
# returns      : #

sub set_product_transfer_status :Export() {

    my ( $dbh, $args )  = @_;

    my @params;
    foreach my $field ( qw(status_id product_id channel_id ) ) {
        if (!$args->{$field}) {
            die 'No '.$field.' defined for set_product_transfer_status()';
        }
        push @params, $args->{$field};
    }

    my $transfer_date = '';
    if ($args->{status_id} == $PRODUCT_CHANNEL_TRANSFER_STATUS__TRANSFERRED){
        $transfer_date = 'transfer_date = ?,';
        unshift @params, $args->{transfer_date};
    }
    my $qry = qq{ UPDATE product_channel SET $transfer_date transfer_status_id = ? WHERE product_id = ? AND channel_id = ? };
    my $sth = $dbh->prepare( $qry );
    $sth->execute( @params);


    return;
}


### Subroutine : create_channel_transfer                ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub create_channel_transfer :Export() {

    my ( $dbh, $args ) = @_;

    foreach my $field ( qw(product_id from_channel_id to_channel_id operator_id) ) {
        if (!$args->{$field}) {
            die 'No '.$field.' defined for create_channel_transfer()';
        }
    }

    # create record
    my $qry = qq{ INSERT INTO channel_transfer (product_id, from_channel_id, to_channel_id, status_id ) VALUES (?, ?, ?, ?) };
    my $sth = $dbh->prepare( $qry );
    $sth->execute( $args->{product_id}, $args->{from_channel_id}, $args->{to_channel_id}, $CHANNEL_TRANSFER_STATUS__REQUESTED );

    my $transfer_id = last_insert_id( $dbh, 'channel_transfer_id_seq' );

    # log it
    $qry = qq{ INSERT INTO log_channel_transfer (channel_transfer_id, status_id, operator_id, date ) VALUES (?, ?, ?, current_timestamp) };
    $sth = $dbh->prepare( $qry );
    $sth->execute( $transfer_id, $CHANNEL_TRANSFER_STATUS__REQUESTED, $args->{operator_id} );

    return $transfer_id;
}


### Subroutine : set_channel_transfer_status                ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub set_channel_transfer_status :Export() {

    my ( $dbh, $args ) = @_;

    foreach my $field ( qw(transfer_id status_id operator_id) ) {
        if (!$args->{$field}) {
            die 'No '.$field.' defined for set_channel_transfer_status()';
        }
    }

    # update status
    my $qry = qq{ UPDATE channel_transfer SET status_id = ? WHERE id = ? };
    my $sth = $dbh->prepare( $qry );
    $sth->execute( $args->{status_id}, $args->{transfer_id} );

    # log it
    $qry = qq{ INSERT INTO log_channel_transfer (channel_transfer_id, status_id, operator_id, date ) VALUES (?, ?, ?, current_timestamp) };
    $sth = $dbh->prepare( $qry );
    $sth->execute( $args->{transfer_id}, $args->{status_id}, $args->{operator_id} );

    return;
}


### Subroutine : create_channel_transfer_pick                ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub create_channel_transfer_pick :Export() {

    my ( $dbh, $args ) = @_;

    foreach my $field ( qw(transfer_id variant_id location_id operator_id) ) {
        if (!$args->{$field}) {
            die 'No '.$field.' defined for create_channel_transfer_pick()';
        }
    }

    # create record
    my $qry = qq{ INSERT INTO channel_transfer_pick (channel_transfer_id, variant_id, location_id, expected_quantity, picked_quantity, operator_id, date ) VALUES (?, ?, ?, ?, ?, ?, current_timestamp) };
    my $sth = $dbh->prepare( $qry );
    $sth->execute( $args->{transfer_id}, $args->{variant_id}, $args->{location_id}, $args->{expected_quantity}, $args->{picked_quantity}, $args->{operator_id} );

    my $pick_id = last_insert_id( $dbh, 'channel_transfer_pick_id_seq' );

    return $pick_id;
}


### Subroutine : cancel_channel_transfer_pick                ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub cancel_channel_transfer_pick :Export() {

    my ( $dbh, $args ) = @_;

    foreach my $field ( qw(transfer_id operator_id) ) {
        if (!$args->{$field}) {
            die 'No '.$field.' defined for cancel_channel_transfer_pick()';
        }
    }

    # create record
    my $qry = qq{ DELETE FROM channel_transfer_pick WHERE channel_transfer_id = ? };
    my $sth = $dbh->prepare( $qry );
    $sth->execute( $args->{transfer_id} );

    return;
}


### Subroutine : create_channel_transfer_putaway                ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub create_channel_transfer_putaway :Export() {

    my ( $dbh, $args ) = @_;

    foreach my $field ( qw(transfer_id variant_id location_id quantity operator_id) ) {
        if (!$args->{$field}) {
            die 'No '.$field.' defined for create_channel_transfer_putaway()';
        }
    }

    # create record
    my $qry = qq{ INSERT INTO channel_transfer_putaway (channel_transfer_id, variant_id, location_id, quantity, operator_id, date ) VALUES (?, ?, ?, ?, ?, current_timestamp) };
    my $sth = $dbh->prepare( $qry );
    $sth->execute( $args->{transfer_id}, $args->{variant_id}, $args->{location_id}, $args->{quantity}, $args->{operator_id} );

    my $putaway_id = last_insert_id( $dbh, 'channel_transfer_putaway_id_seq' );

    return $putaway_id;
}


### Subroutine : cancel_channel_transfer_putaway                ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub cancel_channel_transfer_putaway :Export() {

    my ( $dbh, $args ) = @_;

    foreach my $field ( qw(transfer_id operator_id) ) {
        if (!$args->{$field}) {
            die 'No '.$field.' defined for cancel_channel_transfer_putaway()';
        }
    }

    # create record
    my $qry = qq{ DELETE FROM channel_transfer_putaway WHERE channel_transfer_id = ? };
    my $sth = $dbh->prepare( $qry );
    $sth->execute( $args->{transfer_id} );

    return;
}


### Subroutine : get_channel_transfers          ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_channel_transfers :Export() {

    my ( $dbh, $args ) = @_;

    foreach my $field ( qw(status_id) ) {
        if (!$args->{$field}) {
            die 'No '.$field.' defined for get_channel_transfers()';
        }
    }

    my %data = ();

    my $qry = qq{ SELECT ct.id, ct.product_id, ct.from_channel_id, ct.to_channel_id, ct.status_id, cts.status, to_char(lct.date, 'DD-MM-YYYY') as last_action_date, fc.name AS from_channel, tc.name AS to_channel, CASE WHEN pc.upload_date IS NULL THEN '99999999' || LPAD(CAST(ct.id as varchar), 8, '0') ELSE to_char(pc.upload_date, 'YYYYMMDD') || LPAD(CAST(ct.id as varchar), 8, '0') END AS sortkey, to_char(pc.upload_date, 'DD-MM-YYYY') AS uploaddate
                    FROM channel_transfer ct, channel_transfer_status cts, log_channel_transfer lct, channel fc, channel tc, product_channel pc
                    WHERE ct.status_id = ?
                    AND ct.status_id = cts.id
                    AND ct.from_channel_id = fc.id
                    AND ct.to_channel_id = tc.id
                    AND ct.to_channel_id = pc.channel_id
                    AND ct.product_id = pc.product_id
                    AND ct.id = lct.channel_transfer_id
                    AND lct.status_id = ? };

    my $sth = $dbh->prepare( $qry );
    $sth->execute( $args->{status_id}, $args->{status_id} );

    while ( my $row = $sth->fetchrow_hashref ) {
        $data{ $row->{from_channel} }{ $row->{sortkey} } = $row;
    }

    return \%data;
}

sub get_product_channel_transfers :Export() {

    my ( $dbh, $args ) = @_;

    die "No product defined" unless $args->{product_id};

    my %data = ();

    my $qry = qq{ SELECT ct.id, ct.product_id, ct.from_channel_id, ct.to_channel_id, ct.status_id, cts.status, to_char(lct.date, 'DD-MM-YYYY') as last_action_date, fc.name AS from_channel, tc.name AS to_channel, CASE WHEN pc.upload_date IS NULL THEN '99999999' || LPAD(CAST(ct.id as varchar), 8, '0') ELSE to_char(pc.upload_date, 'YYYYMMDD') || LPAD(CAST(ct.id as varchar), 8, '0') END AS sortkey, to_char(pc.upload_date, 'DD-MM-YYYY') AS uploaddate
                    FROM channel_transfer ct, channel_transfer_status cts, log_channel_transfer lct, channel fc, channel tc, product_channel pc
                    WHERE ct.status_id = cts.id
                    AND ct.from_channel_id = fc.id
                    AND ct.to_channel_id = tc.id
                    AND ct.to_channel_id = pc.channel_id
                    AND ct.product_id = pc.product_id
                    AND ct.id = lct.channel_transfer_id
                    AND ct.product_id = ?
                    };

    my $sth = $dbh->prepare( $qry );
    $sth->execute( $args->{product_id} );

    while ( my $row = $sth->fetchrow_hashref ) {
        $data{ $row->{from_channel} }{ $row->{sortkey} } = $row;
    }

    return \%data;
}
### Subroutine : get_channel_transfer          ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_channel_transfer :Export() {

    my ( $dbh, $args ) = @_;

    foreach my $field ( qw(transfer_id) ) {
        if (!$args->{$field}) {
            die 'No '.$field.' defined for get_channel_transfer()';
        }
    }

    my $qry = qq{ SELECT ct.id, ct.product_id, ct.from_channel_id, ct.to_channel_id, ct.status_id, cts.status, fc.name AS from_channel, tc.name AS to_channel
                    FROM channel_transfer ct, channel_transfer_status cts, channel fc, channel tc
                    WHERE ct.id = ?
                    AND ct.status_id = cts.id
                    AND ct.from_channel_id = fc.id
                    AND ct.to_channel_id = tc.id};
    my $sth = $dbh->prepare( $qry );
    $sth->execute( $args->{transfer_id} );

    return $sth->fetchrow_hashref;
}


### Subroutine : get_channel_transfer_log          ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_channel_transfer_log :Export() {

    my ( $dbh, $args ) = @_;

    foreach my $field ( qw(transfer_id) ) {
        if (!$args->{$field}) {
            die 'No '.$field.' defined for get_channel_transfer()';
        }
    }

    my %data = ();

    my $qry = qq{ SELECT l.id, cts.status, op.name as operator, to_char(l.date, 'DD-MM-YYYY HH24:MI') as date
                    FROM log_channel_transfer l, channel_transfer_status cts, operator op
                    WHERE l.channel_transfer_id = ?
                    AND l.status_id = cts.id
                    AND l.operator_id = op.id};
    my $sth = $dbh->prepare( $qry );
    $sth->execute( $args->{transfer_id} );

    while ( my $row = $sth->fetchrow_hashref ) {
        $data{ $row->{id} } = $row;
    }

    return \%data;
}


### Subroutine : get_channel_transfer_pick          ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_channel_transfer_pick :Export() {

    my ( $dbh, $args ) = @_;

    foreach my $field ( qw(transfer_id) ) {
        if (!$args->{$field}) {
            die 'No '.$field.' defined for get_channel_transfer()';
        }
    }

    my %data = ();

    my $qry = qq{ SELECT p.id, p.variant_id, p.location_id, v.product_id || '-' || sku_padding(v.size_id) as sku, l.location, op.name as operator, to_char(p.date, 'DD-MM-YYYY HH24:MI') as date, p.expected_quantity, p.picked_quantity
                    FROM channel_transfer_pick p, variant v, location l, operator op
                    WHERE p.channel_transfer_id = ?
                    AND p.variant_id = v.id
                    AND p.location_id = l.id
                    AND p.operator_id = op.id};
    my $sth = $dbh->prepare( $qry );
    $sth->execute( $args->{transfer_id} );

    while ( my $row = $sth->fetchrow_hashref ) {
        $data{ $row->{id} } = $row;
    }

    return \%data;
}


### Subroutine : get_channel_transfer_putaway          ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_channel_transfer_putaway :Export() {

    my ( $dbh, $args ) = @_;

    foreach my $field ( qw(transfer_id) ) {
        if (!$args->{$field}) {
            die 'No '.$field.' defined for get_channel_transfer()';
        }
    }

    my %data = ();

    my $qry = qq{ SELECT p.id, p.variant_id, p.location_id, v.product_id || '-' || sku_padding(v.size_id) as sku, l.location, op.name as operator, to_char(p.date, 'DD-MM-YYYY HH24:MI') as date, p.quantity
                    FROM channel_transfer_putaway p, variant v, location l, operator op
                    WHERE p.channel_transfer_id = ?
                    AND p.variant_id = v.id
                    AND p.location_id = l.id
                    AND p.operator_id = op.id};
    my $sth = $dbh->prepare( $qry );
    $sth->execute( $args->{transfer_id} );

    while ( my $row = $sth->fetchrow_hashref ) {
        $data{ $row->{id} } = $row;
    }

    return \%data;
}


sub begin_auto_channel_transfer :Export() {
    my ($schema, $transfer_id, $operator_id) = @_;

    # setup
    my $transfer = $schema->resultset('Public::ChannelTransfer')
        ->find({id => $transfer_id});

    # selection
    $transfer->set_status($CHANNEL_TRANSFER_STATUS__SELECTED,$operator_id);

}

sub _log_all_stocks {
    my ($schema,$args) = @_;
    my $dbh = $schema->storage->dbh;

    log_stock( $dbh, {
        variant_id  => $args->{variant_id},
        action      => $args->{action},
        quantity    => $args->{quantity_present},
        operator_id => $args->{operator_id},
        notes       => 'Channel Transfer '.ucfirst($args->{which_way}),
        channel_id  => $args->{channel_id},
    });
    if (product_present($dbh,{
            type => 'variant_id',
            id => $args->{variant_id},
            channel_id => $args->{channel_id},
        })
    ) {
        update_web_stock_level(
            $dbh,
            $args->{dbh_web},
            {
                quantity_change => $args->{quantity_present},
                variant_id      => $args->{variant_id},
            }
        );

        $schema->resultset('Public::LogPwsStock')->log_stock_change(
            variant_id      => $args->{variant_id},
            channel_id      => $args->{channel_id},
            pws_action_id   => $args->{pws_action},
            quantity        => $args->{quantity_present},
            notes           => 'Channel Transfer '.ucfirst($args->{which_way}),
            operator_id     => $args->{operator_id},
        );
    }
}

=head2 _get_auto_locations_for_main_and_dead_stock($schema, $transfer_row): \%location_map

For provided transfer object returns hash ref where keys are
stock statuses (main and dead) and values location rows where
stock from transfer should go depending of its status.

=cut

sub _get_auto_locations_for_main_and_dead_stock {
    my ($schema, $transfer_row) = @_;

    my %location_by_stock_status;

    foreach my $stock_status (
        $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS , $FLOW_STATUS__DEAD_STOCK__STOCK_STATUS
    ) {
        if ( config_var('PRL', 'rollout_phase') ) {
            my $storage_type_row = $transfer_row->product->storage_type;

            die "Cannot proceed with transfer since storage type is not set for product\n"
                unless $storage_type_row;

            my $stock_status_row = $schema->resultset('Flow::Status')
                ->find($stock_status);

            my $prl_config_part = XT::Domain::PRLs::get_prls_for_storage_type_and_stock_status({
                storage_type => $storage_type_row->name,
                stock_status => $stock_status_row->name,
            });

            my $prl_name = (keys %$prl_config_part)[0];
            $location_by_stock_status{ $stock_status } =
                XT::Domain::PRLs::get_location_from_prl_name({
                    prl_name => $prl_name,
            });
        } else {
            $location_by_stock_status{ $stock_status } //=
                $schema->resultset('Public::Location')->get_iws_location;
        }
    }

    return \%location_by_stock_status;
}

sub complete_auto_channel_transfer :Export() {
    my ($schema, $transfer_id, $operator_id) = @_;
    # setup
    my $dbh = $schema->storage->dbh;
    my $transfer = $schema->resultset('Public::ChannelTransfer')
        ->find({id => $transfer_id});

    # Get location for variant, which will either be a PRL or IWS.
    my $auto_locations = _get_auto_locations_for_main_and_dead_stock($schema, $transfer)
        or die 'Cannot determine location for product';

    my @statuses = ($FLOW_STATUS__MAIN_STOCK__STOCK_STATUS , $FLOW_STATUS__DEAD_STOCK__STOCK_STATUS);
    my $quantity_rs = $schema->resultset('Public::Quantity')->search({
        status_id   => { -in => \@statuses },
        location_id => { -in => [map {$_->id} values %$auto_locations] },
    });

    my @variants = $schema->resultset('Public::Variant')->search({
        product_id => $transfer->product_id,
    })->all;

    my $total_quantity = 0;

    my %quant_by_variant;
    my $from_config_section  = $transfer->from_channel->business->config_section;
    my $to_config_section  = $transfer->to_channel->business->config_section;
    my $dbh_web_pick = get_database_handle( { name => 'Web_Live_'.$from_config_section, type => 'transaction' } );

    # Begin our XT transaction here
    my $guard = $schema->txn_scope_guard;

    # picking
    for my $variant (@variants) {
        my $quantity = $quantity_rs->search({
            channel_id => $transfer->from_channel_id,
            variant_id => $variant->id,
        });
        #we can have dead and main
        for my $status_id ( @statuses ) {
            if ($quantity->search({status_id => $status_id})->count() > 1 ) {
                die "Cannot channel transfer $transfer_id unique index violation for main or dead stock quantities!";
            }
        }
        my @return_quantities;
        while ( my $this_quantity = $quantity->next){

            my $quantity_present =  $this_quantity->quantity || 0; # sometimes we get 'undef'

            next if $quantity_present == 0;
            $total_quantity += $quantity_present;

            $transfer->add_to_channel_transfer_picks({
                variant_id        => $variant->id,
                location_id       => $auto_locations->{ $this_quantity->status_id }->id,
                expected_quantity => $quantity_present,
                picked_quantity   => $quantity_present,
                operator_id       => $operator_id,
            });

            $this_quantity->update({ quantity => 0});
            log_location( $dbh, {
                variant_id  => $variant->id,
                location_id => $auto_locations->{ $this_quantity->status_id }->id,
                channel_id  => $transfer->from_channel_id,
                operator_id => $operator_id,
            });
            push (@return_quantities, {quant => $quantity_present, status_id => $this_quantity->status_id} );
            _log_all_stocks($schema,{
                variant_id  => $variant->id,
                channel_id  => $transfer->from_channel_id,
                action      => $STOCK_ACTION__CHANNEL_TRANSFER_OUT,
                pws_action  => $PWS_ACTION__CHANNEL_TRANSFER_OUT,
                quantity_present => -$quantity_present,
                operator_id      => $operator_id,
                transfer_id      => $transfer_id,
                dbh_web          => $dbh_web_pick,
                which_way        => 'pick'
            });

        }

        $quant_by_variant{$variant->id} = \@return_quantities;
    }

    $transfer->set_status($CHANNEL_TRANSFER_STATUS__PICKED,$operator_id);
    my $dbh_web_putaway = get_database_handle( { name => 'Web_Live_'.$to_config_section, type => 'transaction' } );

    # putaway
    for my $variant (@variants) {
        foreach my $quantity (@{$quant_by_variant{$variant->id}}){
            my $quantity_present = $quantity->{quant} || 0; # sometimes we get 'undef'
            next if $quantity_present == 0;

            my $this_quantity = $quantity_rs->search({
                channel_id => $transfer->from_channel_id,
                variant_id => $variant->id,
                status_id  => $quantity->{status_id},
            });

            $transfer->add_to_channel_transfer_putaways({
                variant_id  => $variant->id,
                location_id => $auto_locations->{ $quantity->{status_id} }->id,
                quantity    => $quantity_present,
                operator_id => $operator_id,
            });

            $this_quantity->update({
                channel_id => $transfer->to_channel_id,
                quantity => $quantity_present,

            });
            _log_all_stocks($schema,{
                variant_id  => $variant->id,
                channel_id  => $transfer->to_channel_id,
                action      => $STOCK_ACTION__CHANNEL_TRANSFER_IN,
                pws_action  => $PWS_ACTION__CHANNEL_TRANSFER_IN,
                quantity_present => $quantity_present,
                operator_id      => $operator_id,
                transfer_id      => $transfer_id,
                dbh_web          => $dbh_web_putaway,
                which_way        => 'putaway'
            });

        }
    }
    my $dt = DateTime->now(time_zone => local_timezone());

    $transfer->set_status($CHANNEL_TRANSFER_STATUS__COMPLETE,$operator_id);
    $transfer->product->search_related('product_channel',{
        channel_id => $transfer->from_channel_id,
    })->update({transfer_status_id => $PRODUCT_CHANNEL_TRANSFER_STATUS__TRANSFERRED,
                transfer_date => $dt->date});

    # tell Product Service
    my @broadcasts;
    for my $channel_id ( $transfer->from_channel_id, $transfer->to_channel_id ) {
        my $broadcast = XTracker::WebContent::StockManagement::Broadcast->new({
            schema => $schema,
            channel_id => $channel_id,
        });
        $broadcast->stock_update(
            quantity_change => 0,
            product => $transfer->product,
        );
        push @broadcasts, $broadcast;
    }

    # tell Fulcrum
    my %fulcrum_payload = (
        source_channel  => $transfer->from_channel_id,
        dest_channel    => $transfer->to_channel_id,
        transfer_date   => $dt->date,
        product_id      => $transfer->product_id,
        quantity        => $total_quantity,
    );

    my $job = XT::JQ::DC->new({ funcname => 'Send::Product::Transfered' });
    $job->set_payload( \%fulcrum_payload );
    $job->send_job();

    # Commit *EVERYTHING*!
    # $dbhs die when a commit fails, broadcasts don't. Unfortunately we can't
    # do inter-dbh commits (and job-queue sends) atomically, so we can still
    # potentially have bugs here. Broadcast objects' commits don't die... this
    # is probably ok because the product service is essentially just a cache.
    $_->commit for $dbh_web_pick, $dbh_web_putaway, $guard, @broadcasts;

    return;
}
