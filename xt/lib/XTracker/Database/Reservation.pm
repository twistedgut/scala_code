package XTracker::Database::Reservation;

use strict;
use warnings;

use Perl6::Export::Attrs;

use XTracker::Database qw{get_schema_using_dbh};
use XTracker::Database::Customer;
use XTracker::Database::Product qw( get_product_id get_fcp_sku get_product_channel_info );
use XTracker::Database::Stock qw(:DEFAULT get_saleable_item_quantity);
use XTracker::Database::Utilities;
use XTracker::Database::Invoice qw( get_invoice_country_info );
use XTracker::EmailFunctions        qw( get_and_parse_correspondence_template );
use XTracker::Database::Operator    qw( get_operator_by_id );
use XTracker::DBEncode qw( decode_db );
use XTracker::Database::Currency  qw( get_currency_glyph_map );

use XTracker::Logfile qw( xt_logger );

use XTracker::Constants::FromDB qw(
    :business
    :country
    :department
    :region
    :reservation_status
    :variant_type
    :pws_action
);

use XTracker::Utilities qw( :string isdates_ok );

use XTracker::Config::Local qw(
    config_var
    customercare_email
    personalshopping_email
    fashionadvisor_email
);

use Data::Dumper;
use Carp;

sub create_reservation :Export(:DEFAULT) {
    my ( $dbh, $stock_manager, $args ) = @_;

    # get ordering info
    my $qry = qq{
        SELECT max(ordering_id)
        FROM reservation
        WHERE channel_id = ?
        AND variant_id = ?
    };
    my $sth = $dbh->prepare($qry);
    $sth->execute($args->{channel_id}, $args->{variant_id});

    my $ordering_id = 1;

    while(my $row = $sth->fetchrow_arrayref){
        $ordering_id = $row->[0] + 1 if $row->[0];
    }

    # create special order
    $qry = qq{
        INSERT INTO reservation (
            ordering_id,
            variant_id,
            customer_id,
            operator_id,
            date_created,
            date_uploaded,
            date_expired,
            status_id,
            notified,
            date_advance_contact,
            customer_note,
            note,
            channel_id,
            reservation_source_id,
            reservation_type_id
        ) VALUES (
            ?,
            ?,
            ?,
            ?,
            current_timestamp(0),
            null,
            null,
            ?,
            false,
            null,
            null,
            null,
            ?,
            ?,
            ?
        )
    };
    $sth = $dbh->prepare($qry);
    $sth->execute(
        $ordering_id,
        $args->{variant_id},
        $args->{customer_id},
        $args->{operator_id},
        $RESERVATION_STATUS__PENDING,
        $args->{channel_id},
        $args->{reservation_source_id},
        $args->{reservation_type_id}
    );

    # get back id
    my $reservation_id = 0;

    $qry = qq{
        SELECT id
        FROM reservation
        WHERE channel_id = ?
        AND variant_id = ?
        AND customer_id = ?
        AND ordering_id = ?
    };
    $sth = $dbh->prepare($qry);
    $sth->execute(
        $args->{channel_id},
        $args->{variant_id},
        $args->{customer_id},
        $ordering_id
    );

    while(my $row = $sth->fetchrow_arrayref){
        $reservation_id = $row->[0];
    }

    # CANDO-1150: update a Pre-Order Item if required to
    if ( $reservation_id && $args->{link_to_pre_order_item} && ref( $args->{link_to_pre_order_item} ) ) {
        my $pre_ord_item    = $args->{link_to_pre_order_item};
        $pre_ord_item->update( { reservation_id => $reservation_id } );
    }

    # check if sku is live on website
    my $product_id = get_product_id(
        $dbh,
        { type => 'variant_id', id => $args->{variant_id} },
    );

    my $live = 0;

    $qry = qq{
        SELECT live
        FROM product_channel
        WHERE channel_id = ?
        AND product_id = ?
    };
    $sth = $dbh->prepare($qry);
    $sth->execute($args->{channel_id}, $product_id);

    while(my $row = $sth->fetchrow_arrayref){
        $live = $row->[0];
    }

    if ($live){

        # check if got stock
        my $free_stock = get_saleable_item_quantity( $dbh, $product_id );

        if ( $free_stock->{ $args->{channel} }{ $args->{variant_id} } > 0 ){

            upload_reservation(
                $dbh,
                $stock_manager,
                {
                    reservation_id  => $reservation_id,
                    variant_id      => $args->{variant_id},
                    operator_id     => $args->{operator_id},
                    customer_id     => $args->{customer_id},
                    customer_nr     => $args->{customer_nr},
                    channel_id      => $args->{channel_id},
                }
            );

        }
        else {
            # leave as pending
        }
    }
    else {
        # leave as pending
    }

    return $reservation_id;
}

sub upload_reservation :Export(:DEFAULT) {
    my ($dbh, $stock_manager, $args) = @_;

    my $schema      = $stock_manager->schema;
    my $reservation = $schema->resultset('Public::Reservation')->find( $args->{reservation_id} );
    my $product_reservation_upload = $args->{product_reservation_upload}//0;

    $stock_manager->reservation_upload({
        customer_nr => $args->{customer_nr},
        variant_id  => $args->{variant_id},
        pre_order_flag => $reservation->is_for_pre_order,
    });

    # log it
    log_reservation(
        $dbh,
        $args->{reservation_id},
        $RESERVATION_STATUS__UPLOADED,
        $args->{operator_id},
        1
    );

    # update status
    update_reservation_status(
        $dbh,
        $args->{reservation_id},
        $RESERVATION_STATUS__UPLOADED
    );

    # update upload date
    update_reservation_upload_date($dbh, $args->{reservation_id});

    my $reservation_expiry_date = $args->{reservation_expiry_date}//"1 day";

    # update expired date
    update_reservation_expiry_date(
        $dbh, $stock_manager, $args->{reservation_id}, $reservation_expiry_date
    );

    # decrement web stock level
    $stock_manager->stock_update(
        product_reservation_upload => $product_reservation_upload,
        quantity_change => -1,
        variant_id      => $args->{variant_id},
        operator_id     => $args->{operator_id},
        log_update      => 0,
    );

    return;
}

sub cancel_reservation :Export(:DEFAULT) {
    my ( $dbh, $stock_manager, $args ) = @_;

    croak "No DBH passed to 'cancel_reservation'" unless $dbh;
    croak "No 'Stock Management' object passed to 'cancel_reservation'" if ( !$stock_manager || ref( $stock_manager ) !~ /WebContent::StockManagement/ );
    croak "No ARGS Hash Ref passed to 'cancel_reservation'"
        if ( !$args || ref( $args ) ne 'HASH' );

    # update XT status
    update_reservation_status(
        $dbh, $args->{reservation_id}, $RESERVATION_STATUS__CANCELLED
    );

    # update XT ordering
    my $info = get_reservation_details($dbh, $args->{reservation_id});
    update_reservation_ordering(
        $dbh,
        $info->{ordering_id},
        0,
        $args->{reservation_id},
        $args->{variant_id},
        $info->{channel_id}
    );

    # update XT expired date
    update_reservation_expiry_date($dbh, $stock_manager, $args->{reservation_id});

    # reservation was live - sort it out
    if ($args->{status_id} == $RESERVATION_STATUS__UPLOADED){
        my $schema      = $stock_manager->schema;
        my $reservation = $schema->resultset('Public::Reservation')->find( $args->{reservation_id} );

        # update reservation commission_cut_off_date
        $reservation->set_commission_cut_off_date();

        # cancel reservation on website
        $stock_manager->reservation_cancel({
            customer_nr => $args->{customer_nr},
            variant_id  => $args->{variant_id},
            pre_order_flag => $reservation->is_for_pre_order,
        });

        # increment web stock level
        $stock_manager->stock_update(
            quantity_change => 1,
            variant_id      => $args->{variant_id},
            operator_id     => $args->{operator_id},
            log_update      => 0,
            (
                exists( $args->{skip_upload_reservations} )
                ? ( skip_upload_reservations => $args->{skip_upload_reservations} )
                : ()
            ),
        );

        # log status change in XT
        log_reservation(
            $dbh,
            $args->{reservation_id},
            $RESERVATION_STATUS__CANCELLED,
            $args->{operator_id},
            -1
        );

    }

    return;
}

sub edit_reservation :Export() {
    my ($schema, $stock_manager, $channel_id, $params)  = @_;

    croak "No Schema passed to 'edit_reservation'"                          if ( !$schema );
    croak "Need a Schema Class passed to 'edit_reservation'"                if ( ref( $schema ) !~ m/Schema$/ );
    croak "No 'Stock Management' object passed to 'edit_reservation'"       if ( !$stock_manager || ref( $stock_manager ) !~ /WebContent::StockManagement/ );
    croak "No Channel Id passed to 'edit_reservation'"                      if ( !$channel_id );
    croak "No Params Hash Ref passed to 'edit_reservation'"                 if ( !$params || ref( $params ) ne 'HASH' );

    # Get a DBH handler
    my $dbh = $schema->storage->dbh;

    my $reservation = $schema->resultset('Public::Reservation')->find( $params->{'special_order_id'} );

    # ordering
    if ( defined $params->{'ordering'} && $params->{'ordering'} != $params->{'current_position'}) {
        update_reservation_ordering($dbh, $params->{'current_position'}, $params->{'ordering'}, $params->{'special_order_id'}, $params->{'variant_id'}, $channel_id);
    }

    # notes
    if ($params->{'notes'}){
        update_reservation_note($dbh, $params->{'notes'}, $params->{'special_order_id'});
    }

    # expiry date
    # This validation is slightly insane... no idea why they decide to
    # represent 0 in so many different ways, or for that matter why we have
    # days/months/years of 0 anyway. Not deleting as there may be some other
    # code somewhere relying on this
    if ($params->{'expireDay'} ne "00" && $params->{'expireDay'} ne "0"
     && $params->{'expireMonth'} ne "00" && $params->{'expireMonth'} ne "0"
     && $params->{'expireYear'} ne "00" && $params->{'expireYear'} ne "0000"){

        my $expire_date = join q{-},
            $params->{expireYear}, $params->{expireMonth}, $params->{expireDay};
        update_reservation_expiry_date($dbh, $stock_manager, $params->{'special_order_id'}, $expire_date);
    }

    # size change
    if ( defined $params->{'changeSize'} && $params->{'changeSize'} ne $params->{'variant_id'}){
        update_reservation_variant($dbh, $stock_manager, $params->{'special_order_id'}, $params->{'changeSize'});
    }

    # Operator change.
    if ( $params->{'newOperator'} ) {
        if ( defined $reservation ) {
            $reservation->discard_changes->update_operator( $params->{'operator_id'}, $params->{'newOperator'} );
        }
    }

    # Source change
    if ( ( my $new_source_id = $params->{new_reservation_source_id} ) && $reservation ) {
        # if the current source is NULL or not
        # the same as the new one, change it
        if ( !$reservation->discard_changes->reservation_source_id
           || ( $new_source_id != $reservation->reservation_source_id ) ) {
            $reservation->update( { reservation_source_id => $new_source_id } );
        }
    }

    # Type change
    if ( ( my $new_type_id = $params->{new_reservation_type_id} ) && $reservation ) {
        # if the current type is NULL or not
        # the same as the new one, change it
        if ( !$reservation->discard_changes->reservation_type_id
           || ( $new_type_id != $reservation->reservation_type_id ) ) {
            $reservation->update( { reservation_type_id => $new_type_id } );
        }
    }


    return;
}

sub get_uploaded_reservation_by_sku :Export(:DEFAULT) {
    my ( $dbh, $customer_id, $variant_id ) = @_;

    my $id = 0;

    my $qry = "SELECT id FROM reservation WHERE status_id = $RESERVATION_STATUS__UPLOADED AND customer_id = ? AND variant_id = ? LIMIT 1";
    my $sth = $dbh->prepare($qry);
    $sth->execute($customer_id, $variant_id);

    while ( my $row = $sth->fetchrow_arrayref() ) {
        $id = $row->[0];
    }

    return $id;
}

sub set_reservation_purchased :Export(:DEFAULT) {
    my ( $dbh, $reservation_id, $variant_id ) = @_;

    ### log it
    log_reservation($dbh, $reservation_id, $RESERVATION_STATUS__PURCHASED, 1, -1);

    ## update status
    update_reservation_status($dbh, $reservation_id, $RESERVATION_STATUS__PURCHASED);

    ## update ordering
    my $info = get_reservation_details($dbh, $reservation_id);
    update_reservation_ordering($dbh, $info->{ordering_id}, 0, $reservation_id, $variant_id, $info->{channel_id});
}

sub get_reservation_list :Export(:DEFAULT) {
    my ( $dbh, $args, $limit ) = @_;

    my %res;

    my %qry_type    = (
            'live'      => ' WHERE r.channel_id = ? AND r.status_id = '.$RESERVATION_STATUS__UPLOADED,
            'pending'   => ' WHERE r.channel_id = ? AND r.status_id = '.$RESERVATION_STATUS__PENDING.' AND pc.live = TRUE',
            'waiting'   => ' WHERE r.channel_id = ? AND r.status_id = '.$RESERVATION_STATUS__PENDING.' AND pc.live = FALSE',
        );

    if ( !defined $args ) {
        die "Can't run get_reservation_list without parameters";
    }
    if ( !defined $args->{type} || !exists $qry_type{ $args->{type} } ) {
        die "Can't run get_reservation_list without type to run";
    }
    if ( !defined $args->{channel_id} ) {
        die "Can't run get_reservation_list without channel_id to run";
    }

    # put the channel id into the params array
    # that will be passed into the query
    my @params  = ( $args->{channel_id} );

    my $qry = "SELECT r.id, r.ordering_id, r.variant_id, r.customer_id, r.operator_id, r.date_created, r.date_uploaded, r.date_expired, r.status_id, r.notified, r.date_advance_contact, r.customer_note, r.note, r.channel_id, ch.name as sales_channel, to_char(r.date_advance_contact, 'DD-MM') as date_notified, to_char(r.date_created, 'DD-MM') as creation_date, to_char(r.date_created, 'DD-MM') as creation_ddmmyy, to_char(r.date_expired, 'DD-MM') as expiry_date, to_char(r.date_expired, 'DD-MM-YYYY') as expiry_ddmmyy, to_char(r.date_uploaded, 'DD-MM-YYYY') as uploaded_ddmmyy, v.legacy_sku, v.product_id, v.designer_size_id, pc.live, pa.name as product_name, d.designer, op.name as operator_name, rs.status, c.is_customer_number, c.first_name, c.last_name, v.product_id || '-' || sku_padding(v.size_id) as sku, dept.id as department_id
                FROM reservation r
                LEFT JOIN channel ch ON r.channel_id = ch.id
                LEFT JOIN customer c ON r.customer_id = c.id
                LEFT JOIN reservation_status rs ON r.status_id = rs.id
                LEFT JOIN variant v ON r.variant_id = v.id
                LEFT JOIN product p ON v.product_id = p.id
                LEFT JOIN product_attribute pa ON p.id = pa.product_id
                LEFT JOIN designer d ON p.designer_id = d.id
                LEFT JOIN operator op ON r.operator_id = op.id
                LEFT JOIN department dept ON op.department_id = dept.id
                LEFT JOIN product_channel pc ON ( p.id = pc.product_id AND pc.channel_id = r.channel_id )
                LEFT JOIN pre_order_item poi ON poi.reservation_id = r.id
            ";

    $qry    .= $qry_type{ $args->{type} };
    # exclude Pre-Order Reservations from being returned
    $qry    .= " AND poi.id IS NULL ";

    # if an operator id has been passed then
    # only get records for that operator
    if ( defined $args->{operator_id} ) {
        $qry    .= " AND r.operator_id = ? ";
        # add the operator id to the list of
        # params to be passed into the query
        push @params, $args->{operator_id};
    }

    $qry .= qq{ limit $limit } if $limit;

    my $sth = $dbh->prepare($qry);
    $sth->execute( @params );

    while ( my $row = $sth->fetchrow_hashref() ) {
        $res{ $row->{sales_channel} }{ $row->{id} } = $row;
    }

    return \%res;
}

sub get_customer_reservation_list :Export(:DEFAULT) {
    my ( $dbh, $channel_id, $customer_id ) = @_;

    my %res;

    my $qry = "SELECT r.*, v.id AS variant_id, v.legacy_sku, v.product_id, v.designer_size_id, pa.name as product_name, d.designer, op.name as operator_name, rs.status, c.is_customer_number, c.first_name, c.last_name, s.size, s2.size as designer_size
                FROM reservation r LEFT JOIN customer c ON r.customer_id = c.id, reservation_status rs, variant v, product p, product_attribute pa, designer d, operator op, size s, size s2
                WHERE r.customer_id = ?
                AND r.channel_id = ?
                AND r.status_id = rs.id
                AND r.variant_id = v.id
                AND v.product_id = p.id
                AND v.size_id = s.id
                AND v.designer_size_id = s2.id
                AND p.id = pa.product_id
                AND p.designer_id = d.id
                AND r.operator_id = op.id";
    my $sth = $dbh->prepare($qry);
    $sth->execute($customer_id, $channel_id);

   while ( my $row = $sth->fetchrow_hashref() ) {
       $res{ $$row{id} } = decode_db($row);
    }

    return \%res;
}

sub get_reservation_details :Export(:DEFAULT) {
    my ( $dbh, $reservation_id ) = @_;

    my $qry = "SELECT r.*, v.legacy_sku, v.product_id, v.designer_size_id, pa.name as product_name, d.designer, op.name as operator_name, rs.status, c.is_customer_number, c.first_name, c.last_name, c.email, ch.name as sales_channel
                FROM reservation r LEFT JOIN customer c ON r.customer_id = c.id, reservation_status rs, variant v, product p, product_attribute pa, designer d, operator op, channel ch
                WHERE r.id = ?
                AND r.status_id = rs.id
                AND r.variant_id = v.id
                AND v.product_id = p.id
                AND p.id = pa.product_id
                AND p.designer_id = d.id
                AND r.operator_id = op.id
                AND r.channel_id = ch.id";
    my $sth = $dbh->prepare($qry);
    $sth->execute($reservation_id);

    my $row = decode_db($sth->fetchrow_hashref());

    return $row;
}

sub update_reservation_status :Export(:DEFAULT) {
    my ( $dbh, $reservation_id, $status_id ) = @_;

    my $qry = "UPDATE reservation SET status_id = ? WHERE id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute($status_id, $reservation_id);
}

sub update_reservation_upload_date :Export(:DEFAULT) {
    my ( $dbh, $reservation_id ) = @_;

    my $qry = "UPDATE reservation SET date_uploaded = current_timestamp WHERE id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute($reservation_id);
}

sub update_reservation_expiry_date :Export(:DEFAULT) {
    my ( $dbh, $stock_manager, $reservation_id, $expire_date ) = @_;

    croak q{invalid reservation id '}.($reservation_id // '').q{'}
        unless is_valid_database_id($reservation_id // '');

    # TODO: This should all live in a transaction
    # FIXME: We're not doing any timezone magic here, so we may find a
    # discrepancy amongst the expiry date for the DC2 box (which lives in the
    # US) and the AM boxes (that live in BST)
    my $qry = "";

    # Perform update in XT
    if ( $expire_date ) {
        if ($expire_date eq "1 day") {
            $qry = "UPDATE reservation SET date_expired = (current_date + interval '1 day' + time '23:59:59') WHERE id = ?";
        }
        elsif ($expire_date eq "10 days") {
            $qry = "UPDATE reservation SET date_expired = (current_date + interval '10 days' + time '23:59:59') WHERE id = ?";
        }
        else {
            # Ensure that $expire_date really is a valid date
            $expire_date = trim($expire_date);
            croak qq{expiry date '$expire_date' is not a valid date}
                unless isdates_ok($expire_date);

            $qry = "UPDATE reservation SET date_expired = ('$expire_date'::timestamp + time '23:59:59') WHERE id = ?";
        }
    }
    # This condition is called when a reservation is cancelled, so expiring
    # 'now'
    else {
        $qry = "UPDATE reservation SET date_expired = (current_timestamp) WHERE id = ?";
    }
    my $sth = $dbh->prepare($qry);
    $sth->execute($reservation_id);

    # Perform update on pws
    my $schema = $stock_manager->schema;
    my $reservation
        = $schema->resultset('Public::Reservation')->find($reservation_id);

    $stock_manager->reservation_update_expiry( $reservation );

    return;
}

sub update_reservation_ordering :Export(:DEFAULT) {
    my ($dbh, $current_position, $new_position, $special_order_id, $variant_id, $channel_id) = @_;

    my $qry = "";

    $qry = "UPDATE reservation SET ordering_id = ? WHERE id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute($new_position, $special_order_id);

    # Pre-Order Reservations start off at ZERO so don't
    # adjust anything if the Current Position is ZERO
    if ( $new_position == 0 && $current_position != 0 ) {
        $qry = "UPDATE reservation SET ordering_id = (ordering_id - 1) WHERE channel_id = ? AND variant_id = ? AND ordering_id > ? AND id != ?";
        $sth = $dbh->prepare($qry);
        $sth->execute($channel_id, $variant_id, $current_position, $special_order_id);
    }
    elsif ($new_position < $current_position) {
        $qry = "UPDATE reservation SET ordering_id = (ordering_id + 1) WHERE channel_id = ? AND variant_id = ? AND ordering_id >= ? AND ordering_id < ? AND id != ?";
        $sth = $dbh->prepare($qry);
        $sth->execute($channel_id, $variant_id, $new_position, $current_position, $special_order_id);
    }
    elsif ($new_position > $current_position) {
        $qry = "UPDATE reservation SET ordering_id = (ordering_id - 1) WHERE channel_id = ? AND variant_id = ? AND ordering_id <= ? AND ordering_id > ? AND id != ?";
        $sth = $dbh->prepare($qry);
        $sth->execute($channel_id, $variant_id, $new_position, $current_position, $special_order_id);
    }

    return;
}

sub update_reservation_note :Export(:DEFAULT) {
    my ($dbh, $note, $id) = @_;

    $note =~ s/\n/ /gi;
    $note =~ s/\r\n/ /gi;
    $note =~ s/\r/ /gi;

    my $qry = "UPDATE reservation SET note = ? WHERE id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute($note, $id);
}

sub update_reservation_variant :Export(:DEFAULT) {
    my ($dbh, $stock_manager, $id, $new_variant_id, $args ) = @_;

    croak "No DBH passed to 'update_reservation_variant'"                           if ( !$dbh );
    croak "No 'Stock Management' object passed to 'update_reservation_variant'"     if ( !$stock_manager
                                                                                         || ref( $stock_manager ) !~ /WebContent::StockManagement/ );
    croak "No Reservation Id passed to 'update_reservation_variant'"                if ( !$id );
    croak "No New Variant Id passed to 'update_reservation_variant'"                if ( !$new_variant_id );

    my $info = get_reservation_details($dbh, $id);

    cancel_reservation(
                        $dbh,
                        $stock_manager,
                        {
                            reservation_id  => $id,
                            status_id       => $info->{status_id},
                            variant_id      => $info->{variant_id},
                            operator_id     => $info->{operator_id},
                            customer_nr     => $info->{is_customer_number}
                        }
    );

    $args   //= {};
    create_reservation(
                        $dbh,
                        $stock_manager,
                        {
                            channel         => $info->{sales_channel},
                            channel_id      => $info->{channel_id},
                            variant_id      => $new_variant_id,
                            operator_id     => $info->{operator_id},
                            customer_id     => $info->{customer_id},
                            customer_nr     => $info->{is_customer_number},
                            reservation_source_id   => $info->{reservation_source_id},
                            reservation_type_id   => $info->{reservation_type_id},
                            ( $args->{link_to_pre_order_item} ? ( link_to_pre_order_item => $args->{link_to_pre_order_item} ) : () ),
                        }
    );
}

sub update_reservation_advance_contact :Export(:DEFAULT) {
    my ($dbh, $id) = @_;

    my $qry = "UPDATE reservation SET date_advance_contact = current_timestamp WHERE id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute($id);
}

sub update_reservation_notified :Export(:DEFAULT) {
    my ($dbh, $id) = @_;

    my $qry = "UPDATE reservation SET notified = true WHERE id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute($id);
}

sub log_reservation :Export(:DEFAULT) {
    my ($dbh, $id, $status_id, $operator_id, $qty) = @_;
    my ($qry, $sth);

    my $balance = 0;

    $qry = "SELECT count(*) FROM reservation WHERE status_id = $RESERVATION_STATUS__UPLOADED AND variant_id = (SELECT variant_id FROM reservation WHERE id = ?)";
    $sth = $dbh->prepare($qry);
    $sth->execute($id);
    my $row = $sth->fetchrow_arrayref();

    $balance = $row->[0];

    $balance = $balance + $qty;

    $qry = "INSERT INTO reservation_log VALUES (default, ?, ?, ?, current_timestamp, ?, ?)";
    $sth = $dbh->prepare($qry);
    $sth->execute($id, $status_id, $operator_id, $qty, $balance);
}

sub get_reservation_log :Export(:DEFAULT) {
    my ( $dbh, $args_ref ) = @_;

    my %res;

    my $type = $args_ref->{type};
    my $id   = $args_ref->{id  };

    my %qry_id = ( 'variant_id' => ' and r.variant_id = ? ',
                   'product_id' => ' and r.variant_id in
                                        ( select id from variant where product_id = ?) ',
                 );


    my $qry = "select rl.id, rl.reservation_id, r.variant_id, v.product_id, sku_padding(v.size_id) as size_id,
                      to_char(rl.date, 'DD-MM-YYYY') as date,
                      to_char(rl.date, 'HH24:MI') as time,
                      rs.status, o.name as operator, rl.quantity, rl.balance, c.first_name, c.last_name, ch.name as sales_channel
               from reservation r, reservation_log rl, reservation_status rs, operator o, variant v, customer c, channel ch
               where rl.reservation_status_id = rs.id
               and r.variant_id = v.id
               and rl.operator_id = o.id
               and rl.reservation_id = r.id
               and r.customer_id = c.id
               and r.channel_id = ch.id
               $qry_id{$type}
               order by rl.date";

    my $sth = $dbh->prepare( $qry );
    $sth->execute( $id );

    while ( my $row = $sth->fetchrow_hashref() ) {
        $res{ $$row{sales_channel} }{ $$row{id} } = $row;

        if ($$row{status} eq "Purchased"){
            ($res{ $$row{sales_channel} }{ $$row{id} }{orders_id}, $res{ $$row{sales_channel} }{ $$row{id} }{shipment_id}) = get_reservation_order($dbh, $$row{reservation_id});
        }
    }
    return \%res;
}

sub get_reservation_order :Export(:DEFAULT) {
    my ( $dbh, $id ) = @_;

    my $qry = "SELECT los.orders_id, los.shipment_id
                FROM reservation r, orders o, shipment_item si, link_orders__shipment los
                WHERE r.id = ?
                AND r.variant_id = si.variant_id
                AND si.special_order_flag is true
                AND si.shipment_id = los.shipment_id
                AND los.orders_id = o.id
                AND o.customer_id = r.customer_id
                LIMIT 1";
    my $sth = $dbh->prepare( $qry );
    $sth->execute( $id );

    my $row = $sth->fetchrow_hashref();

    return $$row{orders_id}, $$row{shipment_id};
}

sub get_reservation_overview :Export(:DEFAULT) {
    my ( $dbh, $args )  = @_;

    # check parameters have been passed as argument hash
    if ( ref( $args ) ne "HASH" ) {
        die "Must Pass a HASH of Arguments to 'get_reservation_overview'";
    }
    # check required parameters have been passed in the arguments
    foreach my $arg ( qw( channel_id type ) ) {
        die "Argument '$arg' not passed to 'get_reservation_overview'"              if ( !defined $args->{ $arg } );
    }

    my $channel_id      = $args->{channel_id};
    my $type            = $args->{type};
    my $limit           = $args->{limit} || "";
    my $upload_date     = $args->{upload_date};

    # check Type passed is one that's acceptable
    if ( $type !~ m/^(Pending|Waiting|Upload)$/ ) {
        die "'type' argument not recongnised: '$type' for 'get_reservation_overview'";
    }

    # by default get the Stock Order Quantities
    my $get_so_ord_qty  = ( defined $args->{get_so_ord_qty} ? $args->{get_so_ord_qty} : 1 );

    # hashes to hold results
    my %res = ();
    my %ordered = ();

    # just in case no upload date is provided - we'll get an error
    if (!$upload_date) {
        $upload_date = '01-01-2007';
    }

    my %qry = (
        "Pending" =>  "SELECT p.id, p.legacy_sku, pa.name as product_name, pa.description, d.designer, 0 as upload_date, count(r.*) as reserved, 0 as preordered, s.season
                                FROM reservation r
                                        LEFT JOIN pre_order_item poi ON poi.reservation_id = r.id,
                                     variant v, product p, product_channel pc, product_attribute pa, designer d, season s
                                WHERE r.status_id = $RESERVATION_STATUS__PENDING
                                AND r.channel_id = ?
                                AND r.variant_id = v.id
                                AND v.product_id = p.id
                                AND p.id = pa.product_id
                                AND p.designer_id = d.id
                                AND p.season_id = s.id
                                AND p.id = pc.product_id
                                AND pc.channel_id = $channel_id
                                AND pc.live = true
                                AND poi.id IS NULL  -- Exclude Reservations for Pre-Orders
                                GROUP BY p.id, p.legacy_sku, pa.name, pa.description, d.designer, s.season
                                ORDER BY reserved DESC $limit",
        "Upload" =>  "SELECT p.id, p.legacy_sku, pa.name as product_name, pa.description, d.designer, 0 as upload_date, sum(case when poi.id is null then 1 else 0 end) as reserved, sum(case when poi.id is not null then 1 else 0 end) as preordered, s.season
                                FROM reservation r
                                        LEFT JOIN pre_order_item poi ON poi.reservation_id = r.id,
                                     variant v, product p, product_channel pc, product_attribute pa, designer d, season s
                                WHERE r.status_id = $RESERVATION_STATUS__PENDING
                                AND r.channel_id = ?
                                AND r.variant_id = v.id
                                AND v.product_id = p.id
                                AND p.id = pa.product_id
                                AND p.designer_id = d.id
                                AND p.season_id = s.id
                                AND p.id = pc.product_id
                                AND r.channel_id = pc.channel_id
                                AND to_char(pc.upload_date, 'DD-MM-YYYY') = '$upload_date'
                                GROUP BY p.id, p.legacy_sku, pa.name, pa.description, d.designer, s.season
                                ORDER BY reserved DESC $limit",
        "Waiting" =>  "SELECT p.id, p.legacy_sku, pa.name as product_name, pa.description, d.designer, to_char(pc.upload_date, 'DD-MM') as upload_date, count(r.*) as reserved, 0 as preordered, s.season
                                FROM reservation r
                                        LEFT JOIN pre_order_item poi ON poi.reservation_id = r.id,
                                     variant v, product p, product_channel pc, product_attribute pa, designer d, season s
                                WHERE r.status_id = $RESERVATION_STATUS__PENDING
                                AND r.channel_id = ?
                                AND r.variant_id = v.id
                                AND v.product_id = p.id
                                AND p.id = pa.product_id
                                AND p.designer_id = d.id
                                AND p.season_id = s.id
                                AND p.id = pc.product_id
                                AND pc.channel_id = r.channel_id
                                AND pc.live = false
                                AND poi.id IS NULL  -- Exclude Reservations for Pre-Orders
                                GROUP BY p.id, p.legacy_sku, pa.name, pa.description, d.designer, pc.upload_date, s.season
                                ORDER BY reserved DESC $limit",
    );

    my $sth = $dbh->prepare( $qry{$type} );
    $sth->execute($channel_id);

    # go through list first, to get list of
    # PIDs to get stock quantities for
    my @rows;
    my %pids;

    my $key = 1;

    while ( my $row = $sth->fetchrow_hashref() ) {
        # build the HASH up
        $res{ $row->{season} }{ $key }  = $row;
        $key++;

        push @rows, $row;           # save row info for later
        $pids{ $row->{id} } = 1;    # get a unique list of PIDs
    }

    # get the Stock Order Quantities for the PIDs but
    # only if there are any PIDs and we have been
    # asked to do so (by default it gets the quantities)
    if ( @rows && $get_so_ord_qty ) {
        # get list of PIDs to put in SQL query.
        # doing it this way was significantly faster
        # than using '?' placeholders and passing
        # them in through the 'execute' method call.
        my $pid_list    = join( ",", keys %pids );

        # now get the stock order quantities info but for only
        # those PIDs that we need them for rather than EVERY PID
        my $ord_qry =<<SQLQRY
SELECT  CASE
            WHEN so.product_id IS NOT NULL
                THEN so.product_id
            ELSE so.voucher_product_id
        END AS product_id,
        SUM(soi.quantity) AS ordered
FROM    stock_order so
        JOIN stock_order_item soi ON so.id = soi.stock_order_id
        JOIN variant v ON v.id = soi.variant_id
                        AND v.type_id != $VARIANT_TYPE__SAMPLE
WHERE   ( so.product_id IN ( $pid_list )
          OR so.voucher_product_id IN ( $pid_list ) )
GROUP BY    so.product_id,
            so.voucher_product_id
SQLQRY
;

        $sth    = $dbh->prepare($ord_qry);
        $sth->execute();
        while ( my $row = $sth->fetchrow_hashref() ) {
            $ordered{ $row->{product_id} } = $row->{ordered};
        }

        # reset the key
        $key    = 1;

        # finally, go through the rows from the original query
        # and include the stock order quantities for the products
        foreach my $row ( @rows ) {
            $res{ $row->{season} }{ $key }{ordered} = $ordered{ $row->{id} };
            $key++;
        }
    }

    return \%res;
}

sub get_upload_reservations :Export(:DEFAULT) {
    my ( $dbh, $channel_id, $upload_date, $args )   = @_;

    my $logger = xt_logger();

    $logger->info('In get_upload_reservations');

    # hash to hold results
    my %data = ();

    # just in case no upload date is provided - we'll get an error
    if (!$upload_date) {
        $upload_date = '01-01-2007';
    }

    # get XT instance from config
    my $instance = config_var('XTracker', 'instance');

    # get UK VAT Rate
    my $uk_tax  = get_invoice_country_info( $dbh, 'United Kingdom' );
    my $vat     = 1 + $uk_tax->{rate};      # add 1 to whatever so 0.xyz becomes 1.xyz

    # to hold various options to filter the
    # results on, such as excluding Designer Id's
    my %filter  = (
            exclude_designer_ids=> q{ AND p.designer_id NOT IN (%s) },
            exclude_pids        => q{ AND pch.product_id NOT IN (%s) },
        );

    # UK and US queries
    my %qry = (
        "INTL" =>  "select p.id, pa.name, d.designer, case when pc.price is not null then pc.price else round(pd.price * $vat, 2) end as price
                    from product_channel pch, product p
                                    left join price_country pc on p.id = pc.product_id and pc.country_id = $COUNTRY__UNITED_KINGDOM,
                    designer d, product_attribute pa, price_default pd
                    where pch.channel_id = ?
                    and to_char(pch.upload_date, 'DD-MM-YYYY') = ?
                    and pch.product_id = p.id
                    and p.id = pa.product_id
                    and p.designer_id = d.id
                    and p.id = pd.product_id",
        "AM" =>  "select p.id, pa.name, d.designer, case when pr.price is not null then pr.price else pd.price end as price
                    from product_channel pch, product p
                                    left join price_region pr on p.id = pr.product_id and pr.region_id = $REGION__AMERICAS,
                    designer d, product_attribute pa, price_default pd
                    where pch.channel_id = ?
                    and to_char(pch.upload_date, 'DD-MM-YYYY') = ?
                    and pch.product_id = p.id
                    and p.id = pa.product_id
                    and p.designer_id = d.id
                    and p.id = pd.product_id",
        "APAC" => "select p.id, pa.name, d.designer, case when pc.price is not null then pc.price else pd.price end as price
                    from product_channel pch, product p
                                    left join price_country pc on p.id = pc.product_id and pc.country_id = $COUNTRY__HONG_KONG,
                    designer d, product_attribute pa, price_default pd
                    where pch.channel_id = ?
                    and to_char(pch.upload_date, 'DD-MM-YYYY') = ?
                    and pch.product_id = p.id
                    and p.id = pa.product_id
                    and p.designer_id = d.id
                    and p.id = pd.product_id",
    );
    my $order_by    = ' ORDER BY price DESC ';

    if ($qry{ $instance }) {

        my @params      = ( $channel_id, $upload_date );
        my $filter_sql  = '';

        # apply any Filter options
        if ( $args->{filter} ) {
            foreach my $option ( keys %{ $args->{filter} } ) {
                if ( my $sql = $filter{ $option } ) {
                    my $value   = $args->{filter}{ $option };
                    $filter_sql .= sprintf( $sql, join( ',', ( '?' ) x scalar( @{ $value } ) ) );
                    push @params, @{ $value };
                }
            }
        }

        my $sth = $dbh->prepare( $qry{ $instance } . $filter_sql . $order_by );
        $sth->execute( @params );

        my $key= 1;

        # get all the currency symbols
        my $currency_glyph  = get_currency_glyph_map( $dbh );

        while ( my $row = decode_db($sth->fetchrow_hashref()) ) {
            $row->{price} = $currency_glyph->{config_var('Currency','local_currency_code')} ." ". $row->{price};

            $data{ $key } = $row;

            $key++;
        }
    }
    return \%data;
}

sub get_reservation_products :Export() {
    my ($dbh, $designer, $season, $type) = @_;

    my %list = ();

    my $qry = "SELECT p.id, pa.name, d.designer, pt.product_type, s.season, pc.live, pc.channel_id
                FROM product p, product_attribute pa, designer d, product_type pt, season s, product_channel pc
                WHERE p.designer_id = d.id
                AND p.id = pa.product_id
                AND p.product_type_id = pt.id
                AND p.season_id = s.id
                AND p.id = pc.product_id
                ";

    if ($designer){
        $qry .= " AND d.id = $designer";
    }

    if ($season){
        $qry .= " AND s.id = $season";
    }

    if ($type){
        $qry .= " AND pt.id = $type";
    }

    my $sth = $dbh->prepare($qry);
    $sth->execute();

    while ( my $row = $sth->fetchrow_hashref() ) {
        $list{ $row->{id} } = $row;
        if ( $row->{live} == 1 ){
            $list{ $row->{id} }{live} = 1;
        }
    }
    return \%list;
}

sub get_reservation_variants :Export() {
    my ($dbh, $product_id) = @_;

    my %list = ();

    # CANDO- 860
    # Updating query to exclude pre-order reservations from count,
    # when counting number of reservations for a product
    # Also the count of reservation was wrong so updated to count distinct not null rows.
    my $qry = "SELECT v.id, v.legacy_sku, v.product_id || '-' || sku_padding(v.size_id) as sku, s.size, s2.size as designer_size, pc.channel_id, ch.name as sales_channel, sum(q.quantity) as onhand, ( count(distinct r.*)-count(distinct pre.id) ) as reservation, count(distinct pre.id) as preorder_count ,sum(soi.quantity) as ordered
                FROM size s, size s2, channel ch, product_channel pc, variant v
                    LEFT JOIN reservation r ON v.id = r.variant_id AND r.status_id < $RESERVATION_STATUS__PURCHASED
                    LEFT JOIN pre_order_item pre ON r.id = pre.reservation_id
                    LEFT JOIN quantity q ON v.id = q.variant_id
                    LEFT JOIN stock_order_item soi ON q.variant_id = soi.variant_id
                WHERE v.product_id = ?
                AND v.type_id = $VARIANT_TYPE__STOCK
                AND v.size_id = s.id
                AND v.designer_size_id = s2.id
                AND v.product_id = pc.product_id
                AND pc.channel_id = ch.id
                GROUP BY v.id, v.legacy_sku, v.product_id, v.size_id, s.size, s2.size, pc.channel_id, ch.name
                ";

    my $sth = $dbh->prepare($qry);
    $sth->execute($product_id);

    while ( my $row = $sth->fetchrow_hashref() ) {

        $list{ $row->{sales_channel} }{ $row->{id} } = $row;

    }
    return \%list;
}

sub list_product_reservations :Export() {
    my ($dbh, $product_id) = @_;

    my %list = ();

    my $qry = "SELECT   r.*,
                        TO_CHAR(r.date_created,  'DD-MM') AS date_created,
                        TO_CHAR(r.date_uploaded, 'DD-MM') AS date_uploaded,
                        TO_CHAR(r.date_expired,  'DD-MM') AS date_expired,
                        TO_CHAR(r.date_expired,  'DD-MM-YYYY') AS date_expired_long,
                        op.name AS operator_name,
                        c.is_customer_number,
                        c.first_name,
                        c.last_name,
                        rs.status,
                        ch.name AS sales_channel,
                        rsrv.source AS reservation_source,
                        rsrt.type AS reservation_type,
                        pre.id as preorder,
                        cust_cat.customer_class_id,
                        cust_cat.category as customer_category,
                        dept.id as department_id
                FROM    reservation r
                            LEFT JOIN pre_order_item pre ON r.id = pre.reservation_id
                            JOIN customer c ON c.id = r.customer_id
                            JOIN customer_category cust_cat ON cust_cat.id = c.category_id
                            JOIN operator op ON op.id = r.operator_id
                            LEFT JOIN department dept ON op.department_id = dept.id
                            JOIN reservation_status rs ON rs.id = r.status_id
                            JOIN channel ch ON ch.id = r.channel_id
                            LEFT JOIN reservation_source rsrv ON rsrv.id = r.reservation_source_id
                            LEFT JOIN reservation_type rsrt ON rsrt.id = r.reservation_type_id
                WHERE   r.variant_id IN (SELECT id FROM variant WHERE product_id = ?)
                AND     r.status_id IN (
                                $RESERVATION_STATUS__PENDING,
                                $RESERVATION_STATUS__UPLOADED,
                                $RESERVATION_STATUS__PURCHASED
                            )
                ";

    my $sth = $dbh->prepare($qry);
    $sth->execute($product_id);

    while ( my $row = $sth->fetchrow_hashref() ) {

        $list{ $row->{sales_channel} }{ $row->{id} } = $row;

        if ($row->{date_expired_long}){
            ($list{ $row->{sales_channel} }{ $row->{id} }{ expire_day }, $list{ $row->{sales_channel} }{ $row->{id} }{ expire_month }, $list{ $row->{sales_channel} }{ $row->{id} }{ expire_year } ) = split /-/, $row->{date_expired_long};
        }
        else {
            $list{ $row->{sales_channel} }{ $row->{id} }{ expire_day } = "00";
            $list{ $row->{sales_channel} }{ $row->{id} }{ expire_month } = "00";
            $list{ $row->{sales_channel} }{ $row->{id} }{ expire_year } = "00";
        }
    }
    return \%list;
}

sub get_notification_reservations :Export() {
    my ($dbh, $operator_id) = @_;

    my %res;

    my $qry = "
        SELECT r.*, ch.name AS sales_channel,
               to_char(r.date_uploaded, 'YYYYMMDD') AS date,
               to_char(r.date_uploaded, 'DD-MM') AS display_date,
               v.product_id || '-' || sku_padding(v.size_id) AS sku,
               v.legacy_sku,
               pa.name AS product_name,
               d.designer,
               c.is_customer_number,
               c.title,
               c.first_name,
               c.last_name,
               c.email
        FROM reservation r
        LEFT JOIN customer c ON r.customer_id = c.id, channel ch, variant v, product p, product_attribute pa, designer d
        WHERE r.operator_id = ?
        AND r.channel_id = ch.id
        AND r.status_id = $RESERVATION_STATUS__UPLOADED
        AND r.variant_id = v.id
        AND v.product_id = p.id
        AND p.id = pa.product_id
        AND p.designer_id = d.id
        AND r.date_uploaded > current_timestamp - interval '2 days'
        UNION
        SELECT r.*,
               ch.name AS sales_channel,
               to_char(o.date, 'YYYYMMDD') AS date,
               to_char(o.date, 'DD-MM') AS display_date,
               v.product_id || '-' || sku_padding(v.size_id) AS sku,
               v.legacy_sku,
               pa.name AS product_name,
               d.designer,
               c.is_customer_number,
               c.title,
               c.first_name,
               c.last_name,
               c.email
        FROM reservation r LEFT JOIN customer c ON r.customer_id = c.id, channel ch, variant v, product p, product_attribute pa, designer d, orders o, link_orders__shipment los, shipment_item si
        WHERE r.operator_id = ?
        AND r.channel_id = ch.id
        AND r.status_id = $RESERVATION_STATUS__PURCHASED
        AND r.variant_id = v.id
        AND v.product_id = p.id
        AND p.id = pa.product_id
        AND p.designer_id = d.id
        AND c.id = o.customer_id
        AND o.id = los.orders_id
        AND los.shipment_id = si.shipment_id
        AND si.variant_id = r.variant_id
        AND o.date > current_timestamp - interval '2 days'
    ";
    my $sth = $dbh->prepare($qry);
    $sth->execute($operator_id, $operator_id);

    while ( my $row = $sth->fetchrow_hashref() ) {
        $res{ $row->{sales_channel} }{ $row->{id} } = $row;
    }

    return \%res;
}

sub get_variant_upload_dates :Export() {
    my ($dbh) = @_;

    my $qry = "SELECT v.id, ch.name as sales_channel, to_char(pc.upload_date, 'DD-MM') as upload_date
                FROM variant v
                LEFT JOIN product_channel pc ON v.product_id = pc.product_id
                LEFT JOIN channel ch ON pc.channel_id = ch.id
                WHERE pc.upload_date > (current_timestamp - interval '1 day')";

    my $sth = $dbh->prepare($qry);
    $sth->execute();

    my %upload;

    while ( my $row = $sth->fetchrow_hashref() ) {
        $upload{ $row->{sales_channel} }{ $row->{id} } = $row->{upload_date};
    }
    return \%upload;
}

sub get_next_upload_variants :Export() {
    my ($dbh) = @_;

    my %data;

    # get next upload date per channel
    my $qry = "SELECT ch.id AS channel_id, ch.name AS sales_channel, MIN(pc.upload_date) as upload_date
            FROM product_channel pc
            JOIN channel ch ON pc.channel_id = ch.id
            WHERE pc.upload_date > current_timestamp - interval '1 day'
            GROUP BY ch.id, ch.name";
    my $sth = $dbh->prepare($qry);
    $sth->execute();

    while ( my $row = $sth->fetchrow_hashref() ) {

        my $sub_qry = "SELECT v.id
                        FROM variant v, product_channel pc
                        WHERE v.product_id = pc.product_id
                        AND pc.upload_date = ?
                        AND pc.channel_id = ?";
        my $sub_sth = $dbh->prepare($sub_qry);
        $sub_sth->execute( $row->{upload_date}, $row->{channel_id} );

        while ( my $sub_row = $sub_sth->fetchrow_hashref() ) {
            $data{ $row->{sales_channel} }{ $sub_row->{id} } = 1;
        }
    }
    return \%data;
}


=head2 get_from_email_address

    my $from_address = get_from_email_address( { channel_config => 'NAP' || 'MRP' etc, department_id => $department_id } );
            or
    # to get a localised Email From address for a Locale call this way:
    my $from_address = get_from_email_address( {
        channel_config  => 'NAP' || 'MRP' etc,
        department_id   => $department_id,
        schema          => $dbic_schema,
        locale          => 'fr_FR',
    } );

This returns the 'From Email Address' that will be used for Customer Notification emails based on the Sales Channel and the Department Id.

If a Schema and a Locale are passed as well then a Localised version of the Email Address will be returned if available.

=cut

sub get_from_email_address :Export(:email) {
    my $args        = shift;

    if ( !defined $args || ref( $args ) ne 'HASH' ) {
        die "'get_from_email_address' function requires a HASH Ref to be passed to it.";
    }
    # check the correct stuff has been passed in
    foreach ( qw( channel_config department_id ) ) {
        if ( !defined $args->{ $_ } ) {
            die "'get_from_email_address' function requires '$_' option to be passed to it.";
        }
    }

    my $channel_config  = $args->{channel_config};
    my $department_id   = $args->{department_id};

    my $email_address   = "";

    # args to pass to the email functions to
    # get localised versions of the addresses
    my $locale_args;
    if ( $args->{schema} && $args->{locale} ) {
        $locale_args    = {
            schema  => $args->{schema},
            locale  => $args->{locale},
        };
    }

    CASE: {
        if ( $department_id == $DEPARTMENT__FASHION_ADVISOR ) {
            $email_address  = fashionadvisor_email( $channel_config, $locale_args );
            last CASE;
        }
        if ( $department_id == $DEPARTMENT__PERSONAL_SHOPPING ) {
            $email_address  = personalshopping_email( $channel_config, $locale_args );
            last CASE;
        }

        # by default set the email address to be for 'Customer Care'
        $email_address  = customercare_email( $channel_config, $locale_args );
    };

    return $email_address;
}


=head2 get_email_signoff

    my $from_address = get_email_signoff( {
                                business_id     => $business_id,
                                department_id   => $department_id,
                                operator_name   => $operator_human_name,
                            } );

This returns the 'Sign Off' that will appear at the bottom of the Customer Notification emails based on the Sales Channel's Business Id and the Department Id.

This function is required for backward compatibilty for the Templates held in xTracker which are used as a fallback. The
function below called 'get_email_signoff_parts' are for the Templates held in the CMS.

=cut

sub get_email_signoff :Export(:email) {
    my $args        = shift;

    if ( !defined $args || ref( $args ) ne 'HASH' ) {
        die "'get_email_signoff' function requires a HASH Ref to be passed to it.";
    }
    # check the correct stuff has been passed in
    foreach ( qw( business_id department_id operator_name ) ) {
        if ( !defined $args->{ $_ } ) {
            die "'get_email_signoff' function requires '$_' option to be passed to it.";
        }
    }

    my $sign_off_parts  = get_email_signoff_parts( $args );
    my $business_id     = $args->{business_id};

    my $sign_off    = "";

    # All Mr. Porter Sign-Offs are the same
    if ( $business_id == $BUSINESS__MRP ) {
        $sign_off   = $sign_off_parts->{name}{full};
    }
    else {
        $sign_off   = $sign_off_parts->{name}{first} .
                      '<br/>' .
                      $sign_off_parts->{role}{name};
    }

    return $sign_off;
}

=head2 get_email_signoff_parts

    my $hash_ref = get_email_signoff_parts( {
                                department_id   => $department_id,
                                operator_name   => $operator_human_name,
                            } );

This returns the 'Sign Off' parts that will appear at the bottom of the Customer Notification emails based on the Department Id. It will return the following in a Hash Ref:

    {
        name    => {
            full    => 'Name of the Operator',
            first   => 'First Name of the Operator',
            last    => 'Last Name of the Operator',
        },
        role    => {
            name    => 'Role/Department for the Operator',
            id      => 'Department Id for the Operator',
        },
    }

Please note: The Department/Role will either be 'Personal Shopping', 'Fashion Advisor' or for an Operator in any
other Department it will be 'Customer Care' regardless of what the actual Operator's Department actually is.

This function is required to pass the correct Sign Off details for the Templates that are held in the CMS. The
above function 'get_email_signoff' is required for backward compatibilty for the Templates held in xTracker which
are used as a fallback.

=cut

sub get_email_signoff_parts :Export(:email) {
    my $args        = shift;

    if ( !defined $args || ref( $args ) ne 'HASH' ) {
        die "'get_email_signoff_parts' function requires a HASH Ref to be passed to it.";
    }
    # check the correct stuff has been passed in
    foreach ( qw( department_id operator_name ) ) {
        if ( !defined $args->{ $_ } ) {
            die "'get_email_signoff_parts' function requires '$_' option to be passed to it.";
        }
    }

    my $department_id   = $args->{department_id};
    my $operator_name   = $args->{operator_name};

    my ( $first_name, $last_name )  = split( / /, $operator_name );
    my %parts   = (
        name    => {
            full    => $operator_name,
            first   => $first_name,
            last    => $last_name,
        },
    );

    # get the Operator's Role
    CASE: {
        if ( $department_id == $DEPARTMENT__FASHION_ADVISOR ) {
            $parts{role}    = {
                name    => 'Fashion Consultant',
                id      => $DEPARTMENT__FASHION_ADVISOR,
            };
            last CASE;
        }
        if ( $department_id == $DEPARTMENT__PERSONAL_SHOPPING ) {
            $parts{role}    = {
                name    => 'Personal Shopper',
                id      => $DEPARTMENT__PERSONAL_SHOPPING,
            };
            last CASE;
        }

        # by default use 'Customer Care'
        $parts{role}    = {
            name    => 'Customer Care',
            id      => $DEPARTMENT__CUSTOMER_CARE,
        };
    };

    return \%parts;
}


=head2 build_reservation_notification_email

    $email_info = build_reservation_notification_email( $dbh, $args );

This will build the email used by 'XTracker::Stock::Actions::SendReservationEmail' & 'XTracker::Schema::Result::Public::Reservation' to send the Customer an email telling them when their Reservation is available on the web-site. The $args passed can take a 'XTracker::Handler' object or it can take a set of arguments laid out like they would be in a 'Handler' object like this:

    $args = {
            schema  => $schema,
            dbh     => $schema->storage->dbh,
            data    => {
                operator_id     => $APPLICATION_OPERATOR_ID,
                department_id   => $dept_id,
                channel         => $channel,        # DBIC Public::Channel
            },
            param_of=> {
                operator_id => $APPLICATION_OPERATOR_ID,
                from_email  => 'from.test@test.test',
                to_email    => 'to.test@test.test',
                addressee   => 'Test Name',
                channel_id  => $channel->id,
                customer_id => $customer_id,
                inc-1212112 => 1,               # this is the format: inc-reservation_id
            },
    }

This returns the same structure as you get from the 'XTracker::EmailFunctions::get_and_parse_correspondence_template()' function.

PLEASE NOTE:

If you edit this function then don't use the available methods on the Handler object such as:
* $args->schema
* $args->dbh
* $args->operator_id
etc.

please access them via the data structure route:
* $args->{schema}
* $args->{dbh}
* $args->{data}{operator_id}
etc.

this is beacuse this function is used by 'XTracker::Schema::Result::Public::Reservation->notify_of_auto_upload()' and this passes in a HASH data stucture and not a Handler object and so it would fall over if you used the methods when that function was called.

=cut

sub build_reservation_notification_email :Export(:email) {
    my ($dbh, $args)    = @_;

    # template name of the 'Special Order Upload Notification'
    my $TPL_SPECIAL_ORDER_UPLOAD_NOTIFICATION   = 'Special Order Upload Notification';
    my $TPL_SPECIAL_ORDER_PURCHASE_NOTIFICATION = 'Special Order Purchase Notification';

    my %email_data;
    my %inc_items;

    # var to keep track of product count
    my $count = 0;
    my $schema = $args->{schema};
    my $channel = $args->{data}{channel};

    # Customer care uses different templates
    my $tpl_names = {
        order_upload => $TPL_SPECIAL_ORDER_UPLOAD_NOTIFICATION
            . ( ( grep { $args->{data}{department_id} == $_ }
                    $DEPARTMENT__CUSTOMER_CARE,
                    $DEPARTMENT__CUSTOMER_CARE_MANAGER )
                ? ' - CC-'
                : '-' )
            . $channel->short_name,
        order_purchase => $TPL_SPECIAL_ORDER_PURCHASE_NOTIFICATION .'-'
            . $channel->short_name,
    };

    # try find these template names and store the ids
    my $tpl_ids;
    foreach my $key (keys %{$tpl_names}) {
        my $tpl = $schema->resultset('Public::CorrespondenceTemplate')
            ->find_by_name( $tpl_names->{$key} )
            or die "Failed to find template for '$tpl_names->{$key}'";

        $tpl_ids->{ $key } = $tpl->id;
    }

    # loop through form data to get items selected for email
    foreach my $form_key ( keys %{ $args->{param_of} } ) {
        if ( $form_key =~ m/-/ && $args->{param_of}{$form_key} == 1 ) {
            my ($empty, $res_id) = split /-/, $form_key;
            $inc_items{ $res_id } = 1;
        }
    }

    # get all reservations for given customer
    my $reservations = get_customer_reservation_list( $args->{dbh}, $args->{param_of}{channel_id}, $args->{param_of}{customer_id} );

    # loop over them and add to template if included
    my $template_id = $tpl_ids->{order_upload};
    foreach my $res_id ( keys %{$reservations} ){

        if ($inc_items{ $res_id }){

            my $master_sku = $reservations->{$res_id}{product_id};
            $master_sku =~ s/_.*//;

            # html block for product - this is required for backward compatibility
            $email_data{items}{$res_id} = {
                prod_detail => "<table cellpadding='0' cellspacing='0' border='0' align='left'><tr><td><a href=\"http://www.net-a-porter.com?np_mid=38&np_eid=294\"><img src=\"http://www.net-a-porter.com/images/products/".$master_sku."/".$master_sku."_in_m.jpg\" border=\"0\" vspace=\"0\" hspace=\"3\" /></a></td><td>&nbsp;&nbsp;&nbsp;</td></tr><tr><td><font size='1'><strong>".$reservations->{$res_id}{designer}."</strong><br/>".$reservations->{$res_id}{product_name}."</font></td><td></td></tr></table>",

                master_sku => $master_sku,
                designer => $reservations->{$res_id}{designer},
                product_name => $reservations->{$res_id}{product_name},
            };
            # this supercedes the above and will be used by the Templates in the CMS to build the above HTML,
            # but because the products are in the 'product_items' hash the product names will get translated
            $email_data{product_items}{$res_id} = $reservations->{$res_id};

            $count++;

            update_reservation_notified($args->{dbh}, $res_id);

            # switch email template to purchase notification if reservation has been purchased
            if ($reservations->{$res_id}{status_id} == $RESERVATION_STATUS__PURCHASED){
                $template_id = $tpl_ids->{order_purchase};
            }
        }
    }


    # get operator name for email sign off
    my $operator = get_operator_by_id( $args->{dbh}, $args->{param_of}{operator_id} );

    # get the appropriate Sign-Off for the email - required for backward compatibility
    $email_data{sign_off}   = get_email_signoff( {
        business_id     => $channel->business_id,
        department_id   => $args->{data}{department_id},
        operator_name   => $operator->{name},
    } );

    # this supercedes the above and will be used by the Templates in the CMS
    $email_data{sign_off_parts} = get_email_signoff_parts( {
        department_id   => $args->{data}{department_id},
        operator_name   => $operator->{name},
    } );

    # pass customers name and product count into email data hash
    $email_data{addressee} = $args->{param_of}{addressee};
    # 'first_name' is what is in the Email Template and so needs to be set to the 'addressee'
    # setting both allows us to change over to 'addressee' whilst still having backward compatibilty
    $email_data{first_name}= $args->{param_of}{addressee};
    $email_data{count}     = $count;

    # process email template
    my $email_info = get_and_parse_correspondence_template( $schema, $template_id, {
        channel => $channel,
        data    => \%email_data,
        base_rec => $schema->resultset('Public::Customer')->find( $args->{param_of}{customer_id} ),
    } );

    return $email_info;
}

=head2 can_reserve

    my $boolean = can_reserve( $department_id );

Determines if a Department ID can reserve products.

=cut

sub can_reserve :Export() {
    my ( $dbh, $department_id, $product_id ) = @_;

    my $result = {};
    my (undef, $channel_info) = get_product_channel_info( $dbh, $product_id );

    foreach my $channel ( keys %$channel_info )  {

        $result->{$channel} = $channel_info->{$channel}->{live}
            || grep { $_ == $department_id } ( $DEPARTMENT__PERSONAL_SHOPPING, $DEPARTMENT__FASHION_ADVISOR, $DEPARTMENT__CUSTOMER_CARE_MANAGER );

    }

    return $result;

}

=head2 queue_upload_pdf_generation

    $message    = queue_upload_pdf_generation( $handler, $channel_id, $channel_name );

This will send a Job to the Schwartz Job Queue to prepare an Upload PDF.

It will return a Message which can be displayed to the user to tell them that their PDF
is being generated.

=cut

sub queue_upload_pdf_generation :Export() {
    my ($handler, $channel_id, $channel) = @_;
    my $channel_name = $handler->{data}{channels}{$channel_id}{name};

    my $absolute_filename =
          config_var('SystemPaths','include_dir')
        . '/'
        . 'upload_'
        . $channel_id . '_'                                     # Channel Id
        . $handler->{data}{upload_date}{$channel_name} . '_'    # Upload Date
        . $handler->operator_id                                 # Operator Id
        . '.pdf'
    ;

    my $job_payload     = {
       channel_name    => $channel_name,
       channel_id      => $channel_id,
       output_filename => $absolute_filename,
       upload_date     => $handler->{data}{upload_date}{$channel_name},
       current_user    => $handler->operator_id,
    };

    # if there is some Filtering then
    # include that in the Payload
    if ( $handler->{data}{pdf_filter} ) {
        $job_payload->{filter}  = $handler->{data}{pdf_filter};
    }

    # TODO: move this as a condition of the function call
    if ($channel eq $channel_name){
        $handler->create_job('Receive::StockControl::Reservation::PreparePDF', $job_payload);
    }

    return 'PDF for the '
        .  $job_payload->{upload_date}
        . ' upload for '
        .  $channel_name
            . ' is being generated.'
        . '<br>'
        . 'Your document will be emailed to you once it has been created.';
}


1;
