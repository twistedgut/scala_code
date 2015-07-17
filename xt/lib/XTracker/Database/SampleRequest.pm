package XTracker::Database::SampleRequest;

use strict;
use warnings;
use Carp;

use feature ':5.14';
#use Data::Dumper;

use Perl6::Export::Attrs;
use Readonly;
use Spreadsheet::WriteExcel;
use Text::CSV;
use XTracker::Constants::FromDB     qw(:sample_request_det_status :flow_status);
use XTracker::Database              qw(:common);
use XTracker::Database::Address;
use XTracker::Database::Product     qw(get_variant_id get_variant_details get_variant_type get_product_id );
use XTracker::Database::Sample      qw(create_sample_receiver);
use XTracker::Database::Stock       qw(get_located_stock get_stock_location_quantity check_stock_location update_quantity delete_quantity insert_quantity );
use XTracker::Database::Utilities   qw(last_insert_id results_list);
use XTracker::Image                 qw(get_images);
use XTracker::Utilities             qw(trim);
use XTracker::DBEncode              qw(encode_db decode_db);

use vars qw/$FLOW_STATUS__SAMPLE__STOCK_STATUS
            $FLOW_STATUS__CREATIVE__STOCK_STATUS/;

sub get_date :Export() {
    my $args_ref = shift;
    my $offset_days = $args_ref->{offset_days} || 0;

    # convert offset days to epoch seconds
    my $offset_epoch_secs = $offset_days * 24 * 3600;

    my ($day, $month, $year) = ( localtime( time + $offset_epoch_secs ) )[3..5];
    $month++;
    $year += 1900;

    my $date_ref = { day => $day, month => $month, year => $year };
    return $date_ref;
}

#-------------------------------------------------------------------------------
# Sample Cart
#-------------------------------------------------------------------------------

sub select_variant :Export(:SampleCart) {
    my $args_ref        = shift;
    my $dbh             = $args_ref->{dbh};
    my $type            = $args_ref->{type};
    my $id              = $args_ref->{id};
    my $variant_type    = $args_ref->{variant_type} || 'Sample';
    my $schema          = get_schema_using_dbh($dbh, 'xtracker_schema');

    my $where_clause    = '';
    my @exec_args       = ();
    my $product_id      = undef;
    my $size_id         = undef;

    if ( $type eq 'product_id' ) {
        $where_clause = 'v.product_id = ?';
        push @exec_args, $id;
        $product_id = $id;
    }
    elsif ( $type eq 'sku' && $id =~ m{\A(\d+)-(\d+)\z} ) {
        ($product_id, $size_id) = ($1, $2);
        $where_clause = 'v.product_id = ? AND v.size_id = ?';
        push @exec_args, $product_id, $size_id;
    }
    elsif ( $type eq 'sku' ) {
        $where_clause = 'v.legacy_sku = ?';
        push @exec_args, $id;
        $product_id = get_product_id( $dbh, { type => 'legacy_sku', id => $id });
    }

    my $prod_channel_id;
    my $product_row = $schema->resultset('Public::Product')->find($product_id);
    $prod_channel_id = $product_row->get_current_channel_id() if $product_row;

    push @exec_args,$prod_channel_id;

    my $qry
        = qq{SELECT q.variant_id, vt.type, q.quantity, q.channel_id
            FROM quantity q
            INNER JOIN variant v
                ON (q.variant_id = v.id)
            LEFT JOIN variant_type vt
                ON (v.type_id = vt.id)
            INNER JOIN location l
                ON q.location_id = l.id
            WHERE $where_clause
            AND l.location IN ('Sample Room', 'Press Samples')
            AND q.channel_id = ?
            ORDER BY l.location DESC, vt.id DESC
        };

    my $sth = $dbh->prepare($qry);

    $sth->execute(@exec_args);

    my $data_ref    = $sth->fetchall_arrayref();

    my $variant_id  = $data_ref->[0][0];
    return $variant_id;
}

sub list_cart_items :Export(:SampleCart) {
    my $args_ref            = shift;
    my $dbh                 = $args_ref->{dbh};
    my $operator_id         = $args_ref->{operator_id};
    my $suppress_images     = $args_ref->{suppress_images};
    my $suppress_locations  = $args_ref->{suppress_locations};
    my $schema              = get_schema_using_dbh($dbh,'xtracker_schema');

    my $qry = q{
SELECT  src.id,
        src.variant_id,
        src.quantity,
        TO_CHAR(src.date_added, 'DD-Mon-YYYY HH24:MI') AS date_added,
        v.product_id,
        pa.name,
        pa.description,
        sku_padding(v.size_id) as size_id,
        s.size,
        v.legacy_sku,
        d.designer,
        ch.id AS channel_id,
        ch.name AS sales_channel,
        pch.live
FROM    sample_request_cart src
            INNER JOIN variant v
            INNER JOIN product p
            INNER JOIN product_attribute pa
                ON p.id = pa.product_id
                ON v.product_id = pa.product_id
                ON src.variant_id = v.id
            INNER JOIN size s ON v.size_id = s.id
            INNER JOIN designer d ON p.designer_id = d.id,
        channel ch,
        product_channel pch
WHERE   src.operator_id = ?
AND     src.channel_id = ch.id
AND     src.channel_id = pch.channel_id
AND     v.product_id = pch.product_id
ORDER BY src.date_added DESC
        };

    my $sth = $dbh->prepare($qry);
    $sth->execute($operator_id);

    my $sample_cart_items_ref   = results_list( $sth );

    my $first_channel;
    $first_channel          = $sample_cart_items_ref->[0]{sales_channel}        if ( @$sample_cart_items_ref );

    ## add image_name for each item, unless specifically suppressed
    unless ($suppress_images) {
        $_->{image_name}    = get_images( { schema => $schema, 'product_id' => $_->{product_id}, live => $_->{live} } )
            foreach ( @$sample_cart_items_ref );
    }

    ## get location quantities for each item, unless specifically suppressed
    unless ($suppress_locations) {
        $_->{located}       = get_located_stock( $dbh, { type => 'variant_id', id => $_->{variant_id} } )->{$first_channel}{ $_->{variant_id} }     foreach ( @$sample_cart_items_ref );
    }
    return $sample_cart_items_ref;
}

sub _get_cart_quantity {
    my $args_ref    = shift;
    my $dbh         = $args_ref->{dbh};
    my $operator_id = $args_ref->{operator_id};
    my $variant_id  = $args_ref->{variant_id};

    my $qry = q{SELECT quantity FROM sample_request_cart WHERE operator_id = ? AND variant_id = ?};

    my $sth = $dbh->prepare($qry);
    $sth->execute($operator_id, $variant_id);

    my $data_ref = $sth->fetchall_arrayref();

    my $cart_quantity = $data_ref->[0][0];
    return $cart_quantity || 0;
}

sub check_cart_channel_match :Export(:SampleCart) {
    my ($dbh,$operator_id,$variant_id)  = @_;

    my $product_id      = get_product_id( $dbh, { type => 'variant_id', id => $variant_id } );
    return 0        if ( !defined $product_id || !$product_id );

    my $schema          = get_schema_using_dbh($dbh, 'xtracker_schema');
    my $prod_channel;
    my $product_row = $schema->resultset('Public::Product')->find($product_id);
    $prod_channel = $product_row->get_current_channel_id() if $product_row;

    return 0        if ( !defined $prod_channel || !$prod_channel );        # can't get prod sales channel then fail

    my $qry =<<QRY
SELECT  DISTINCT(channel_id) AS channel_id
FROM    sample_request_cart
WHERE   operator_id = ?
QRY
;
    my $sth = $dbh->prepare($qry);
    $sth->execute($operator_id);
    my ($cart_channel)  = $sth->fetchrow_array();

    # if NO cart channel then empty cart so any product can go in
    if ( !defined $cart_channel || !$cart_channel ) {
        return $prod_channel;
    }

    if ( $prod_channel == $cart_channel ) {
        return $prod_channel;
    }
    else {
        return 0;
    }
}

sub add_cart_item :Export(:SampleCart) {
    my $args_ref    = shift;
    my $dbh         = $args_ref->{dbh};
    my $operator_id = $args_ref->{operator_id};
    my $variant_id  = $args_ref->{variant_id};
    my $channel_id  = $args_ref->{channel_id};

    ## get quantity of specified item already in cart
    my $cart_quantity = _get_cart_quantity( { dbh => $dbh, operator_id => $operator_id, variant_id => $variant_id } );

    ## limit item quantity to 1
    return if $cart_quantity >= 1;

    my $sql = '';

    if ( $cart_quantity ) {
        $sql = q{UPDATE sample_request_cart SET quantity = quantity + 1 WHERE operator_id = ? AND variant_id = ?};
    }
    else {
        $sql = q{INSERT INTO sample_request_cart (operator_id, variant_id, quantity, channel_id) VALUES (?, ?, 1, ?)};
    }

    my $sth = $dbh->prepare($sql);
    $sth->execute($operator_id, $variant_id, $channel_id);
}

sub remove_cart_item :Export(:SampleCart) {
    my $args_ref    = shift;
    my $dbh         = $args_ref->{dbh};
    my $operator_id = $args_ref->{operator_id};
    my $variant_id  = $args_ref->{variant_id};

    my $sql
        = q{DELETE FROM sample_request_cart
            WHERE operator_id = ?
            AND variant_id = ?
        };

    my $sth = $dbh->prepare($sql);
    $sth->execute($operator_id, $variant_id);
    return $sth->rows();
}

sub _clear_cart {
    my $args_ref    = shift;
    my $dbh_trans   = $args_ref->{dbh};
    my $operator_id = $args_ref->{operator_id};

    my $sql = q{DELETE FROM sample_request_cart WHERE operator_id = ?};

    my $sth = $dbh_trans->prepare($sql);
    $sth->execute($operator_id);
}

sub _create_request_from_cart {
    my $args_ref        = shift;
    my $dbh_trans       = $args_ref->{dbh};
    my $request_type    = $args_ref->{request_type};
    my $operator_id     = $args_ref->{operator_id};
    my $receiver_id     = $args_ref->{receiver_id}  || undef;
    my $notes           = $args_ref->{notes}        || '';

    my $sample_request_id;

    ## throw an exception if cart does not contain at least 1 item
    my $cart_items_ref = list_cart_items( { dbh => $dbh_trans, operator_id => $operator_id } );
    croak ('Sample request failed.  There were no items in your cart!') unless ( $cart_items_ref->[0]{variant_id} );

    my $cart_channel        = $cart_items_ref->[0]{sales_channel};
    my $cart_channel_id     = $cart_items_ref->[0]{channel_id};

    if ($request_type eq 'Press') {
        ## check item availability ('Press Samples' & 'Press')
        my $error_msg = '';

        foreach my $item_ref ( @{$cart_items_ref} ) {
            my %location_quantity = ();

            foreach my $location_id ( keys %{ $item_ref->{located} } ) {
                my $located_ref     = $item_ref->{located}{$location_id}{$FLOW_STATUS__SAMPLE__STOCK_STATUS};
                $location_quantity{ $located_ref->{location} }  += $located_ref->{quantity};
            }

            if ( $item_ref->{quantity} > ( $location_quantity{'Press Samples'} + $location_quantity{'Press'} ) ) {
                $error_msg .= q{Cart quantity exceeds the quantity available in 'Press Samples' and 'Press'};
                $error_msg .= qq{ for SKU $item_ref->{product_id}-$item_ref->{size_id}\n};
            }
        }

        die "$error_msg"        if $error_msg;
    }

    ## sample_request_det_status_id
    my $det_status_id   = $SAMPLE_REQUEST_DET_STATUS__AWAITING_APPROVAL;

    ## insert request header
    my $sql_insert_header   = q{
            INSERT INTO sample_request ( sample_request_type_id, requester_id, date_requested, notes, channel_id )
                VALUES ( (SELECT id FROM sample_request_type WHERE type = ?), ?, default, ?, ? )
        };
    my $sth_insert_header = $dbh_trans->prepare( $sql_insert_header );
    $sth_insert_header->execute( $request_type, $operator_id, encode_db($notes), $cart_channel_id );

    ## fetch sample_request_id
    $sample_request_id  = last_insert_id( $dbh_trans, 'sample_request_id_seq' );

    ## insert sample request receiver if required
    if ( $receiver_id ) {
        my $sql_insert_request_receiver = q{
                INSERT INTO sample_request_receiver ( sample_request_id, sample_receiver_id )
                    VALUES ( ?, ? )
            };
        my $sth_insert_request_receiver = $dbh_trans->prepare( $sql_insert_request_receiver );
        $sth_insert_request_receiver->execute( $sample_request_id, $receiver_id );
    }

    ## insert request details from cart
    my $sql_insert_dets  = qq{
            INSERT INTO sample_request_det ( sample_request_id, variant_id, quantity, sample_request_det_status_id )
                SELECT ? AS sample_request_id, variant_id, quantity, ?
                FROM sample_request_cart
                WHERE operator_id = ?
        };

    my $sth_insert_dets = $dbh_trans->prepare( $sql_insert_dets );
    $sth_insert_dets->execute( $sample_request_id, $det_status_id, $operator_id );
    return $sample_request_id;
}

sub create_sample_request_press :Export(:SampleCart) {
    my ($dbh,$args_ref) = @_;

    my $request_type    = $args_ref->{request_type};
    my $operator_id     = $args_ref->{operator_id};
    my $receiver_id     = $args_ref->{receiver_id};
    my $notes           = $args_ref->{notes};
    my $address_ref     = $args_ref->{address_ref};

    my $sample_request_id;

    ## create new sample receiver if none specified

    unless ( $receiver_id ) {
        ## return error if address not specified
        die ('Please select or create a receiver before submitting a Press Request')    unless ( $address_ref->{first_name} && $address_ref->{address_line_1} );

        ## hash address
        my $address_hash    = hash_address( $dbh, $address_ref );

        ## check if address exists in db...
        my $address_id      = check_address( $dbh, $address_hash );

        ## ...if not, insert new address
        if ( $address_id == 0 ) {
            $address_ref->{hash}= $address_hash;

            create_address( $dbh, $address_ref );

            $address_id         = check_address( $dbh, $address_hash );
        }

        ## create receiver
        $receiver_id    = create_sample_receiver( $dbh, trim($address_ref->{first_name}).' '.trim($address_ref->{last_name}), $address_id );
    }

    ## transfer operator's sample cart items to a new request

    ## transfer items from cart
    $sample_request_id  = _create_request_from_cart( { dbh => $dbh, request_type => $request_type, operator_id => $operator_id, receiver_id => $receiver_id, notes => $notes } );

    ## clear cart
    _clear_cart( { dbh => $dbh, operator_id => $operator_id } );
    return $sample_request_id;
}

sub create_sample_request_creative :Export(:SampleCart) {
    my ($dbh,$args_ref) = @_;

    my $request_type    = $args_ref->{request_type};
    my $operator_id     = $args_ref->{operator_id};
    my $notes           = $args_ref->{notes};

    my $sample_request_id;

    ## transfer operator's sample cart items to a new request

    ## transfer items from cart
    $sample_request_id  = _create_request_from_cart( { dbh => $dbh, request_type => $request_type, operator_id => $operator_id, notes => $notes } );

    ## clear cart
    _clear_cart( { dbh => $dbh, operator_id => $operator_id } );
    return $sample_request_id;
}

sub list_sample_receivers :Export(:SampleCart) {
    my $args_ref            = shift;
    my $dbh                 = $args_ref->{dbh};

    my $where_clause = $args_ref->{include_do_not_use} ? '' : 'WHERE NOT do_not_use';
    my $qry_name = qq{};

    my $qry
        = qq{SELECT sr.id, sr.name, a.address_line_1, a.address_line_2, a.address_line_3, a.towncity, a.county, a.country, a.postcode
            FROM sample_receiver sr
            JOIN order_address a ON sr.address_id = a.id
            $where_clause
            ORDER BY sr.name, a.address_line_1
    };

    my %results;

    for my $row ( @{decode_db($dbh->selectall_arrayref($qry, { Slice => {} }))} ) {
        push @{$results{$row->{name}}}, {
            id      => $row->{id},
            address => join( q{, }, @{$row}{qw/name address_line_1 towncity/}),
        };
    }

    return \%results;
}

sub list_sample_requesters :Export(:SampleCart) {
    my $args_ref            = shift;
    my $dbh                 = $args_ref->{dbh};

    my $qry_name = qq{SELECT DISTINCT operator.id, operator.name FROM operator, sample_request WHERE sample_request.requester_id = operator.id ORDER BY operator.name ASC};
    my $sth_name = $dbh->prepare($qry_name);
    $sth_name->execute();
    my $data_name_ref = decode_db($sth_name->fetchall_arrayref);
    return $data_name_ref;
}

sub get_operator_request_types :Export(:SampleCart) {
    my $args_ref    = shift;
    my $dbh         = $args_ref->{dbh};
    my $operator_id = $args_ref->{operator_id};

    my $qry
        = q{SELECT code, type
            FROM sample_request_type_operator srto
            INNER JOIN sample_request_type srt
                ON (srto.sample_request_type_id = srt.id)
            WHERE srto.operator_id = ?
    };

    my $sth = $dbh->prepare($qry);
    $sth->execute($operator_id);

    my $operator_request_types_ref = results_list($sth);
    return $operator_request_types_ref;
}

sub list_user_request_type_access :Export(:SampleUsers) {
    my $args_ref    = shift;
    my $dbh         = $args_ref->{dbh};
    my $type        = defined $args_ref->{type} ? $args_ref->{type} : 'CURRENT';
    my $operator_id = $args_ref->{operator_id};

    if ( defined $operator_id && $operator_id !~ m{\A\d+\z}xms ) {
        croak "Invalid operator_id ($operator_id)";
    }

    my $type_filter;
    for ($type) {
        if    ( m{\Aall\z}i )           { $type_filter = '' }
        elsif ( m{\Acurrent\z}i )       { $type_filter = 'AND srto.id IS NOT NULL' }
        elsif ( m{\Anoncurrent\z}i )    { $type_filter = 'AND srto.id IS NULL' }
        else                            { croak "Invalid type ($type)" }
    }

    my $where_clause    = undef;
    my @exec_args       = ();

    my $qry
        = qq{SELECT
                A.operator_id
            ,   A.operator_name
            ,   A.operator_department
            ,   bool_or(A.editorial) AS cre
            ,   bool_or(A.pre_shoot) AS crp
            ,   bool_or(A.press) AS prs
            ,   bool_or(A.styling) AS crs
            ,   bool_or(A.upload) AS cru
            FROM
                (SELECT
                    o.id AS operator_id
                ,   o.name AS operator_name
                ,   d.department AS operator_department
                ,   CASE WHEN srt.type = 'Editorial' THEN True ELSE False END AS editorial
                ,   CASE WHEN srt.type = 'Pre-Shoot' THEN True ELSE False END AS pre_shoot
                ,   CASE WHEN srt.type = 'Press' THEN True ELSE False END AS press
                ,   CASE WHEN srt.type = 'Styling' THEN True ELSE False END AS styling
                ,   CASE WHEN srt.type = 'Upload' THEN True ELSE False END AS upload
                FROM sample_request_type_operator srto
                INNER JOIN sample_request_type srt
                    ON (srto.sample_request_type_id = srt.id)
                RIGHT JOIN operator o
                    ON (srto.operator_id = o.id)
                INNER JOIN department d
                    ON (o.department_id = d.id)
                WHERE o.disabled <> 1 $type_filter) A
    };

    if ( $operator_id =~ m{\A\d+\z}xms ) {
        $where_clause = q{operator_id = ?};
        push @exec_args, $operator_id;
    }

    $qry .= qq{ WHERE $where_clause} if defined $where_clause;
    $qry .= q{ GROUP BY A.operator_id, A.operator_name, A.operator_department};
    $qry .= q{ ORDER BY operator_department, operator_name};

    my $sth = $dbh->prepare($qry);
    $sth->execute(@exec_args);

    my $user_req_type_access_ref = results_list($sth);
    return $user_req_type_access_ref;
}

sub list_users_without_request_types :Export(:SampleUsers) {
    my $args_ref    = shift;
    my $dbh         = $args_ref->{dbh};

    ## Users with 'Sample' authorisation, and without any sample_request_type_operator records
    my $qry
        = q{SELECT DISTINCT
                o.id
            ,   o.name
            ,   d.department
            FROM authorisation_section asec
            INNER JOIN authorisation_sub_section asub
                ON (asub.authorisation_section_id = asec.id)
            INNER JOIN operator_authorisation oa
                ON (asub.id = oa.authorisation_sub_section_id)
            INNER JOIN operator o
                ON (oa.operator_id = o.id)
            LEFT JOIN sample_request_type_operator srto
                ON (o.id = srto.operator_id)
            LEFT JOIN department d
                ON (o.department_id = d.id)
            WHERE o.disabled <> 1
            AND asec.section = 'Sample'
            AND srto.id IS NULL
            ORDER BY o.name
    };

    my $sth = $dbh->prepare($qry);
    $sth->execute();

    my $users_without_request_types_ref = results_list($sth);
    return $users_without_request_types_ref;
}

sub set_user_request_type_access :Export(:SampleUsers) {
    my $dbh_trans                   = shift;
    my $args_ref                    = shift;

    my $operator_id                 = $args_ref->{operator_id};
    my $enabled_request_type_ids    = $args_ref->{enabled_request_type_ids};

    croak "Invalid operator_id ($operator_id)\n" if $operator_id !~ m{\A\d+\z}xms;

    my $sample_request_types_ref        = list_sample_request_types( { dbh => $dbh_trans } );
    my $user_request_type_access_ref    = list_user_request_type_access( { dbh => $dbh_trans, operator_id => $operator_id } );

    REQUEST_TYPE:
    foreach my $request_type_ref ( @{$sample_request_types_ref} ) {
        if ((grep { $_ == $request_type_ref->{id} } @{$enabled_request_type_ids})
             && !$user_request_type_access_ref->[0]{ $request_type_ref->{code} }
           ) {
            _insert_sample_request_type_operator({
                    dbh                     => $dbh_trans,
                    operator_id             => $operator_id,
                    sample_request_type_id  => $request_type_ref->{id},
            });
        }
        elsif ( !(grep { $_ == $request_type_ref->{id} } @{$enabled_request_type_ids})
                && $user_request_type_access_ref->[0]{ $request_type_ref->{code} }
              ) {
            _delete_sample_request_type_operator({
                    dbh                     => $dbh_trans,
                    operator_id             => $operator_id,
                    sample_request_type_id  => $request_type_ref->{id},
            });
        }
    }
    return;
}

sub _insert_sample_request_type_operator {
    my $args_ref                = shift;
    my $dbh                     = $args_ref->{dbh};
    my $operator_id             = $args_ref->{operator_id};
    my $sample_request_type_id  = $args_ref->{sample_request_type_id};

    croak "Invalid operator_id ($operator_id)" if $operator_id !~ m{\A\d+\z}xms;
    croak "Invalid sample_request_type_id ($sample_request_type_id)" if $sample_request_type_id !~ m{\A\d+\z}xms;

    my $sql_insert  = q{INSERT INTO sample_request_type_operator (operator_id, sample_request_type_id) VALUES (?, ?)};
    my @exec_args   = ($operator_id, $sample_request_type_id);
    my $sth_insert  = $dbh->prepare($sql_insert);
    $sth_insert->execute(@exec_args);

    my $sample_request_type_operator_id = last_insert_id($dbh, 'sample_request_type_operator_id_seq');
    return $sample_request_type_operator_id;
}

sub _delete_sample_request_type_operator {
    my $args_ref                = shift;
    my $dbh                     = $args_ref->{dbh};
    my $operator_id             = $args_ref->{operator_id};
    my $sample_request_type_id  = $args_ref->{sample_request_type_id};

    croak "Invalid operator_id ($operator_id)" if $operator_id !~ m{\A\d+\z}xms;
    croak "Invalid sample_request_type_id ($sample_request_type_id)" if $sample_request_type_id !~ m{\A\d+\z}xms;

    my $sql_delete  = q{DELETE FROM sample_request_type_operator WHERE operator_id = ? AND sample_request_type_id = ?};
    my @exec_args   = ($operator_id, $sample_request_type_id);
    my $sth_delete  = $dbh->prepare($sql_delete);
    $sth_delete->execute($operator_id, $sample_request_type_id);
    return;
}

#-------------------------------------------------------------------------------
# Sample Transfer
#-------------------------------------------------------------------------------

sub transfer_press_sample :Export(:SampleTransfer) {
    my $args_ref        = shift;
    my $dbh_trans       = $args_ref->{dbh};
    my $variant_id      = $args_ref->{variant_id};
    my $quantity        = $args_ref->{quantity};
    my $loc_from        = $args_ref->{loc_from};
    my $channel_id      = $args_ref->{channel_id};

    croak "Invalid variant_id ($variant_id)"    unless $variant_id  =~ m{\A\d+\z}xms;
    croak "Invalid quantity ($quantity)"        unless $quantity    =~ m{\A[1..9]\z}xms;
    croak "Invalid channel ($channel_id)"       unless $channel_id  =~ m{\A\d+\z}xms;

    my $loc_to;

    if ( $loc_from eq 'Press Samples' ) {
        $loc_to = 'Sample Room';
    }
    elsif ( $loc_from eq 'Sample Room' ) {
        $loc_to = 'Press Samples';
    }
    else {
        croak "Invalid 'from' location ('$loc_from')";
    }

    ## transfer item from 'loc_from' to 'loc_to'
    _transfer_item({
        dbh         => $dbh_trans,
        variant_id  => $variant_id,
        quantity    => $quantity,
        old_loc     => $loc_from,
        new_loc     => $loc_to,
        channel_id  => $channel_id,
        current_status_id   => $FLOW_STATUS__SAMPLE__STOCK_STATUS,
        new_status_id   => $FLOW_STATUS__SAMPLE__STOCK_STATUS,
    });
    return $loc_to;
}

sub transfer_sample :Export(:SampleTransfer) {
    my $args_ref        = shift;
    my $dbh_trans       = $args_ref->{dbh};
    my $request_det_id  = $args_ref->{sample_request_det_id};
    my $variant_id      = $args_ref->{variant_id};
    my $quantity        = $args_ref->{quantity};
    my $loc_from        = $args_ref->{loc_from};
    my $loc_to          = $args_ref->{loc_to};
    my $operator_id     = $args_ref->{operator_id};

    ## get info about sample_request to get the channel id
    my $request_type_ref  = get_request_type( { dbh => $dbh_trans, select_by => { fname => 'sample_request_det_id', value => $request_det_id } } );
    my $channel_id        = $request_type_ref->{channel_id};

    ## transfer item from 'loc_from' to 'loc_to'
    _transfer_item({
        dbh         => $dbh_trans,
        variant_id  => $variant_id,
        quantity    => $quantity,
        old_loc     => $loc_from,
        new_loc     => $loc_to,
        channel_id  => $channel_id,
        # WHY?
        # this function is only called from ProcessSampleRequest,
        # which is only invoked (in "non Press" mode) from the form
        # generated by SampleTransfer, which only handles requests in
        # the "upload locations", so the stuff will always be in
        # "sample" status
        # If this ever changes, we'll have *much* work to do
        current_status_id   => $FLOW_STATUS__SAMPLE__STOCK_STATUS,
        new_status_id   => $FLOW_STATUS__SAMPLE__STOCK_STATUS
    });

    ## set det_status and write det_status_log entry
    change_det_status({
        dbh                     => $dbh_trans,
        sample_request_det_id   => $request_det_id,
        det_status_id           => $SAMPLE_REQUEST_DET_STATUS__TRANSFERRED,
        loc_from                => $loc_from,
        loc_to                  => $loc_to,
        operator_id             => $operator_id,
    });
}

#-------------------------------------------------------------------------------
# Manage Requests
#-------------------------------------------------------------------------------

sub get_sample_request_det_status_counts :Export(:ManageRequests) {
    my $args_ref            = shift;
    my $dbh                 = $args_ref->{dbh};
    my $sample_request_id   = $args_ref->{sample_request_id};

    my $qry
        = q{SELECT srds.status, COUNT(srds.status) AS count_det_lines
            FROM sample_request_det srd INNER JOIN sample_request_det_status srds
                ON srd.sample_request_det_status_id = srds.id
            WHERE srd.sample_request_id = ?
            GROUP BY srd.sample_request_id, srds.status
            ORDER BY srd.sample_request_id, srds.status
        };

    my $sth = $dbh->prepare( $qry );
    $sth->execute( $sample_request_id );
    return results_list( $sth );
}

sub get_sample_receiver_dets :Export(:ManageRequests) {
    my $args_ref    = shift;
    my $dbh         = $args_ref->{dbh};
    my $receiver_id = $args_ref->{receiver_id};

    my $qry
        = q{SELECT * FROM sample_receiver sr INNER JOIN order_address a
            ON sr.address_id = a.id
            WHERE sr.id = ?
        };

    my $sth = $dbh->prepare($qry);
    $sth->execute($receiver_id);

    return results_list($sth);
}

=head2 list_sample_requests($args) : \@results

Performs a sample request search for the given arguments.

=cut

sub list_sample_requests :Export(:ManageRequests) {
    my ($dbh,$args_ref)     = @_;

    my %args           = %{$args_ref->{args}||{}};
    my $columnsort_ref = $args_ref->{columnsort};

    my $order_by = $columnsort_ref->{order_by} // 'date_requested';
    my $asc_desc = $columnsort_ref->{asc_desc} // 'DESC';

    my %where_clause = (
        sample_request_id      => 'srq.id = ?',
        sample_request_type_id => 'srq.sample_request_type_id = ?',
        requester_id           => 'srq.requester_id = ?',
        sample_receiver_id     => 'srr.sample_receiver_id = ?',
        channel_id             => 'srq.channel_id = ?',
        SKU                    => <<EOQ
srq.id IN (
  SELECT srd.sample_request_id
  FROM sample_request_det srd
  JOIN variant v ON srd.variant_id = v.id
  WHERE v.product_id = ?
  AND v.size_id = ?
)
EOQ
    );

    my @wheres = map { $where_clause{$_}//() } keys %args;
    # We special case the is_completed check as we don't pass args for it
    if (exists $args{is_completed}) {
        if ($args{is_completed} == 0) {
            push @wheres, 'srq.date_completed IS NULL';
        } elsif ($args{is_completed} == 1) {
            push @wheres, 'srq.date_completed IS NOT NULL';
        }
        delete $args{is_completed};
    }

    my $where_clause = @wheres ? ('WHERE ' . join q{ AND }, @wheres) : q{};

    my %sort_clause = (
        id             => 'srq.id',
        type           => 'srt.type',
        requester_name => 'op.name',
        receiver_name  => 'src.name',
        date_requested => 'srq.date_requested',
        sales_channel  => 'ch.name',
    );
    my $sort_clause = "ORDER BY $sort_clause{$order_by} $asc_desc";

    my $qry = <<EOQ
SELECT srq.id,
LPAD(srq.id::text, 5, '0') AS request_ref,
TO_CHAR(srq.date_requested, 'DD-Mon-YYYY HH24:MI'::text) AS date_requested,
TO_CHAR(srq.date_completed, 'DD-Mon-YYYY HH24:MI'::text) AS date_completed,
srq.notes,
srt.type,
op.name AS requester_name,
src.name AS receiver_name,
COALESCE(oic.overdue_item_count, 0) AS overdue_item_count,
srq.channel_id AS channel_id,
ch.name AS sales_channel
FROM sample_request srq
JOIN channel ch ON ch.id = srq.channel_id
JOIN sample_request_type srt ON srq.sample_request_type_id = srt.id
JOIN operator op ON srq.requester_id = op.id
LEFT JOIN sample_request_receiver srr ON srq.id = srr.sample_request_id
LEFT JOIN sample_receiver src ON srr.sample_receiver_id = src.id
LEFT JOIN (
    SELECT sample_request_det.sample_request_id,
    COUNT(*) AS overdue_item_count
    FROM sample_request_det
    WHERE sample_request_det.date_returned IS NULL
    AND sample_request_det.date_return_due <= 'now'::timestamp
    GROUP BY sample_request_det.sample_request_id
) oic ON srq.id = oic.sample_request_id
$where_clause
$sort_clause
EOQ
    ;
    my $sth = $dbh->prepare( $qry );
    # We need to flatten out the args, as in the case of SKU we pass two params
    $sth->execute(map { ref $_ ? @$_ : $_ } values %args);

    my $sample_requests_ref = results_list($sth);
    return [] unless @$sample_requests_ref;

    # Let's limit the following query to a given number of ids if we have, say,
    # 100 or less- as we have no limit, in theory we could pass thousands of
    # ids, and we don't want to do that.
    my $status_count = get_sample_request_status_count( $dbh,
        @$sample_requests_ref <= 100 ? (map { $_->{id} } @$sample_requests_ref) : ()
    );
    for my $row (@{$sample_requests_ref}) {
        ## get detail status counts
        $row->{det_status_counts} = $status_count->{$row->{id}};
    }

    return $sample_requests_ref
}

=head2 get_sample_request_status_count($dbh, @ids?) : \%status_ids

Returns a hashref with the following format:

    { $sample_request_id => [{ status => $status_name, count => $count }] }

You don't have to pass C<@ids>, but if you don't you will return the full
resultset, so if you pass them your query will be significantly faster.

=cut

sub get_sample_request_status_count {
    my ( $dbh, @ids ) = @_;

    my %status_map = map { $_->{id} => $_->{status} }
        @{$dbh->selectall_arrayref(
            'SELECT * FROM sample_request_det_status', { Slice => {} }
        )};

    my $where = @ids
        ? 'WHERE sample_request_id IN (' . join(q{, }, ('?') x @ids) . ')'
        : q{};
    my $qry = <<EOQ
SELECT sample_request_id,
sample_request_det_status_id status_id,
COUNT(*) count
FROM sample_request_det
$where
GROUP BY sample_request_id, sample_request_det_status_id
ORDER BY sample_request_id, sample_request_det_status_id
EOQ
    ;

    my %status_count;
    for my $row ( @{$dbh->selectall_arrayref($qry, { Slice => {} }, @ids)} ) {
        push @{$status_count{$row->{sample_request_id}}}, {
            status => $status_map{$row->{status_id}}, count => $row->{count},
        };
    }
    return \%status_count;

}

sub get_sample_request_header :Export(:ManageRequests) {
    my $args_ref            = shift;
    my $dbh                 = $args_ref->{dbh};
    my $type                = $args_ref->{type};
    my $id                  = $args_ref->{id};

    my %where_clause = (
        sample_request_id   => 'sample_request_id = ?'
    );
    my $where_clause = $where_clause{$type};

    my $qry = qq{SELECT * FROM vw_sample_request_header WHERE $where_clause};

    my $sth = $dbh->prepare($qry);
    $sth->execute($id);

    my $sample_request_header_ref = results_list($sth);
    return $sample_request_header_ref;
}

=head1 list_sample_request_dets({$dbh!, $type, $id, \@filter_locations, $order_by, $get_status_log=0}) : \@results

Execute a pretty large SQL query to return sample request details matching the
given parameters.

=cut

sub list_sample_request_dets :Export(:ManageRequests) {
    my $args_ref            = shift;
    my $dbh                 = $args_ref->{dbh};
    my $type                = $args_ref->{type};
    my $id                  = $args_ref->{id};
    my @filter_locations    = @{$args_ref->{filter_locations}||[]};
    my $order_by            = $args_ref->{order_by}//q{};
    my $get_status_log      = $args_ref->{get_status_log};
    my $schema              = get_schema_using_dbh($dbh,'xtracker_schema');

    # Create our where clauses using type/id
    my ($wheres, $args)
        = @{_list_sample_request_dets_binds($schema, $type, $id)}{qw/wheres args/};

    # Our where clauses still need some tweaking: the first two where clauses
    # have a hard-coded element - we do this here instead of in the query as we
    # need all the relevant where clauses passed to _build_where_statement to
    # build the where string correctly
    $wheres = [map { [$_] } @$wheres];
    push @{$wheres->[0]}, join q{ },
        'srdsl.id IN (',
            'SELECT max(sample_request_det_status_log.id) AS max',
            'FROM sample_request_det_status_log',
            'GROUP BY sample_request_det_status_log.sample_request_det_id',
        ')';
    push @{$wheres->[1]},
        "srd.sample_request_det_status_id = $SAMPLE_REQUEST_DET_STATUS__AWAITING_APPROVAL";

    # The final clause is conditional depending on other args
    push @{$wheres->[2]}, sprintf(
        'loc_to IN (%s)', join q{, }, map { qq{'$_'} } @filter_locations
    ) if @filter_locations;

    $wheres = [map { _build_where_statement($_) } @$wheres];

    ## build 'order by' clause
    my $sort_clause
        = $order_by =~ m{\Adesigner\z}xmsi ? 'designer, product_id, size_id'
        : $order_by =~ m{\Asku\z}xmsi      ? 'product_id, size_id'
        :                                    'sample_request_id, sample_request_det_id';

    # Build our query passing it our clauses
    my $qry = _list_sample_request_dets_query({
        where_union_a => $wheres->[0]//q{},
        where_union_b => $wheres->[1]//q{},
        where_global  => $wheres->[2]//q{},
        sort_clause   => $sort_clause,
    });
    my $sth = $dbh->prepare($qry);
    $sth->execute(@$args);

    my $sample_request_dets_ref = results_list($sth);

    # ... it seems we need to get *more* data for each row...
    foreach my $row ( @$sample_request_dets_ref ) {
        ## add image_name for each item
        $row->{image_name} = get_images({
            schema     => $schema,
            product_id => $row->{product_id},
            live       => $row->{live}
        });

        ## get location quantities for each item
        $row->{located} = get_located_stock(
            $dbh, { type => 'variant_id', id => $row->{variant_id} }
        )->{$row->{sales_channel}}{$row->{variant_id}};


        # if requested get the Status Logs for each line - note that this is
        # *very* slow, but we currently don't call this sub with no sql filters
        # (i.e.  return a massive resultset) - if we do start doing that then
        # we need to optimise this bit too
        next unless $get_status_log;
        $row->{status_log} = list_det_status_log({
            dbh => $dbh,
            sample_request_det_id => $row->{sample_request_det_id}
        });
    }
    return $sample_request_dets_ref;
}

sub _list_sample_request_dets_query {
    my ( $args ) = @_;

    return <<EOQ
SELECT srd.sample_request_id,
    lpad(srd.sample_request_id::text, 5, 0::text) AS sample_request_ref,
    srd.id AS sample_request_det_id,
    srd.variant_id,
    srd.quantity,
    srd.sample_request_det_status_id,
    vsrdcs.status,
    vsrdcs.status_date,
    vsrdcs.status_operator,
    vsrdcs.loc_from,
    vsrdcs.loc_to,
    to_char(srd.date_return_due, 'DD-Mon-YYYY') AS date_return_due,
    CASE
        WHEN srd.date_return_due < 'now'::timestamp without time zone
        THEN true
        ELSE false
    END AS return_overdue,
    to_char(srd.date_returned, 'DD-Mon-YYYY HH24:MI') AS date_returned,
    v.product_id,
    pa.name,
    pa.description,
    sku_padding(v.size_id)::text AS size_id,
    sz.size,
    v.product_id || '-' || sku_padding(v.size_id) AS sku,
    d.designer,
    sr.channel_id,
    ch.name AS sales_channel,
    pch.live
FROM sample_request_det srd
JOIN variant v ON srd.variant_id = v.id
JOIN product_attribute pa ON v.product_id = pa.product_id
JOIN product p ON p.id = pa.product_id
JOIN size sz ON v.size_id = sz.id
JOIN designer d ON p.designer_id = d.id
JOIN sample_request sr ON srd.sample_request_id = sr.id
JOIN channel ch ON sr.channel_id = ch.id
JOIN product_channel pch ON ( sr.channel_id = pch.channel_id AND v.product_id = pch.product_id )
LEFT JOIN (

    SELECT srdsl.sample_request_det_id,
        srds.status,
        to_char(srdsl.date, 'DD-Mon-YYYY HH24:MI') AS status_date,
        op_status.name AS status_operator,
        loc_from.location AS loc_from,
        loc_to.location AS loc_to
    FROM sample_request_det srd
    JOIN sample_request_det_status_log srdsl ON srd.id = srdsl.sample_request_det_id
    JOIN sample_request_det_status srds ON srdsl.sample_request_det_status_id = srds.id
    JOIN operator op_status ON srdsl.operator_id = op_status.id
    LEFT JOIN location loc_from ON srdsl.location_id_from = loc_from.id
    LEFT JOIN location loc_to ON srdsl.location_id_to = loc_to.id
    $args->{where_union_a}

    -- Requests that are in status 0 don't have entries in the status log, so
    -- we don't need to dedupe - gives us a performance improvement
    UNION ALL

    SELECT srd.id AS sample_request_det_id,
        srds.status,
        NULL AS status_date,
        NULL AS status_operator,
        NULL AS loc_from,
        NULL AS loc_to
    FROM sample_request_det srd
    JOIN sample_request_det_status srds ON srd.sample_request_det_status_id = srds.id
    $args->{where_union_b}

) vsrdcs ON srd.id = vsrdcs.sample_request_det_id
$args->{where_global}
ORDER BY $args->{sort_clause}
EOQ
;
}

# Returns a hashref with values for where/args for each type
sub _list_sample_request_dets_binds {
    my ($schema, $type, $arg ) = @_;

    my $variant_rs = $schema->resultset('Public::Variant');
    my $variant_wheres_sub = sub {
        my $arg_count = shift;
        return [
            (sprintf 'srd.variant_id IN (%s)', join q{, }, (q{?}) x $arg_count) x 3
        ];
    };
    my %binds = (
        sample_request_id => sub {
            my $sample_request_id = shift;
            return {
                wheres => [ ('srd.sample_request_id = ?') x 3 ],
                args => [ ($sample_request_id) x 3 ],
            };
        },
        sample_request_det_id => sub {
            my $sample_request_det_id = shift;
            return {
                wheres => [ ('srd.id = ?') x 3 ],
                args => [ ($sample_request_det_id) x 3 ],
            };
        },
        # It makes our query easier to deal with variant ids instead of skus,
        # even though this means we can have more than one id as skus don't map
        # one-to-one with variant ids
        SKU =>  sub {
            my $sku = shift;
            my @variant_ids = $variant_rs->search_by_sku($sku)
                ->get_column('id')
                ->all or die "Couldn't find SKU $sku\n";
            return {
                wheres => $variant_wheres_sub->(scalar @variant_ids),
                args => [(@variant_ids) x 3],
            };
        },
        PID => sub {
            my $product_id = shift;
            my @variant_ids = $variant_rs->search({product_id => $product_id})
                ->get_column('id')
                ->all or die "No variants found for PID $product_id\n";
            # We reuse the same first two where clauses as we use when we
            # pass a SKU, but we want to pass a product_id as the third
            # element
            my @wheres = (
                @{$variant_wheres_sub->(scalar @variant_ids)}[0..1],
                'v.product_id = ?'
            );
            return {
                wheres => \@wheres,
                args => [(@variant_ids) x 2, $product_id],
            };
        },
    );
    return $type && $binds{$type} ? $binds{$type}($arg) : { wheres => [], args => [] };
}

sub _build_where_statement {
    my $clause = shift;
    my @clauses = $clause && ref $clause ? @$clause : $clause;
    # Return an empty string if @clauses is empty or its values evaluate to
    # false
    return q{} unless grep { $_ } @clauses;
    # Create our where clauses skipping over false values
    return 'WHERE ' . join q{ AND }, grep { $_ } @clauses;
}

sub list_det_status_log :Export(:ManageRequests) {
    my $args_ref        = shift;
    my $dbh             = $args_ref->{dbh};
    my $request_det_id  = $args_ref->{sample_request_det_id};
    my $status_id       = $args_ref->{status_id};

    my @exec_args       = ();
    my $where_clause    = q{WHERE srdsl.sample_request_det_id = ?};
    push @exec_args, $request_det_id;

    my $qry
        = q{SELECT srdsl.id, srds.id AS status_id, srds.status, TO_CHAR(srdsl.date, 'DD-Mon-YYYY HH24:MI') AS date, op.name, loc_from.location AS location_from, loc_to.location AS location_to
            FROM sample_request_det_status_log srdsl INNER JOIN sample_request_det_status srds
                ON srdsl.sample_request_det_status_id = srds.id LEFT JOIN location loc_from
                ON srdsl.location_id_from = loc_from.id LEFT JOIN location loc_to
                ON srdsl.location_id_to = loc_to.id INNER JOIN operator op
                ON srdsl.operator_id = op.id
        };
    $qry .= qq{ $where_clause} if defined $where_clause;

    if ( defined $status_id ) {
        $qry .= q{ AND srds.id = ?};
        push @exec_args, $status_id;
    }

    $qry .= q{ ORDER BY srdsl.id};

    my $sth = $dbh->prepare($qry);
    $sth->execute(@exec_args);
    return results_list($sth);
}

sub complete_sample_request :Export(:ManageRequests) {
    my $args_ref        = shift;
    my $dbh             = $args_ref->{dbh};
    my $request_id      = $args_ref->{sample_request_id};

    my $qry_det_status
        = qq{SELECT COUNT(srds.status) AS count_det_lines
            FROM sample_request_det srd INNER JOIN sample_request_det_status srds
                ON srd.sample_request_det_status_id = srds.id
            WHERE srd.sample_request_id = ?
            AND srds.id NOT IN ($SAMPLE_REQUEST_DET_STATUS__DECLINED, $SAMPLE_REQUEST_DET_STATUS__RETURNED)
    };

    my $sth_det_status = $dbh->prepare($qry_det_status);
    $sth_det_status->execute($request_id);

    my $det_status_ref = $sth_det_status->fetchall_arrayref;

    if ($det_status_ref->[0][0]) {
            croak "Cannot close request $request_id.  There are $det_status_ref->[0][0] lines with status other than 'Returned' or 'Declined'.";
    }
    else {
        my $sql_update  = q{UPDATE sample_request SET date_completed = LOCALTIMESTAMP WHERE id = ? AND date_completed IS NULL};
        my $sth_update = $dbh->prepare($sql_update);
        $sth_update->execute($request_id);
    }
}

sub list_sample_request_types :Export(:ManageRequests) {
    my $args_ref    = shift;
    my $dbh         = $args_ref->{dbh};

    my $qry = q{SELECT id, code, type FROM sample_request_type ORDER BY type};

    my $sth = $dbh->prepare($qry);
    $sth->execute();
    return results_list($sth);
}

#-------------------------------------------------------------------------------
# Sample Booking
#-------------------------------------------------------------------------------

sub change_det_status :Export() {
    my $args_ref        = shift;
    my $dbh_trans       = $args_ref->{dbh};
    my $request_det_id  = $args_ref->{sample_request_det_id};
    my $det_status_id   = $args_ref->{det_status_id};
    my $loc_from        = $args_ref->{loc_from};
    my $loc_to          = $args_ref->{loc_to};
    my $operator_id     = $args_ref->{operator_id};

#    my $current_status_ref  = get_current_det_status( { dbh => $dbh_trans, sample_request_det_id => $request_det_id } );
#    my $current_status      = $current_status_ref->{status};

    my $sql_update_status = q{UPDATE sample_request_det SET sample_request_det_status_id = ? WHERE id = ?};

    my $sql_insert_log_entry
        = q{INSERT INTO sample_request_det_status_log (sample_request_det_id, sample_request_det_status_id, location_id_from, location_id_to, operator_id, date)
                VALUES(?, ?, (SELECT id FROM location WHERE location = ?), (SELECT id FROM location WHERE location = ?), ?, default)
        };

    my $sth_update_status = $dbh_trans->prepare($sql_update_status);
    $sth_update_status->execute($det_status_id, $request_det_id);

    my $sth_insert_log_entry = $dbh_trans->prepare($sql_insert_log_entry);
    $sth_insert_log_entry->execute($request_det_id, $det_status_id, $loc_from, $loc_to, $operator_id);
}

sub get_request_type :Export(:SampleBooking) {
    my $args_ref        = shift;
    my $dbh             = $args_ref->{dbh};
    my $select_by       = $args_ref->{select_by};

    if ( $select_by->{value} !~ m{\A\d+\z}xms ) {
        croak "Invalid 'select_by' value ($select_by->{value}) specified for field '$select_by->{fname}'";
    }

    ## build 'where' clause
    my $where_clause    = undef;
    my @exec_args       = ();
    for ($select_by->{fname}) {
        m{\Asample_request_id\z}xms     && do { $where_clause = 'srq.id = ?'; push @exec_args, $select_by->{value}; last; };
        m{\Asample_request_det_id\z}xms && do {
                                                $where_clause = 'srq.id = (SELECT sample_request_id FROM sample_request_det WHERE id = ?)';
                                                push @exec_args, $select_by->{value}; last;
                                           };
        croak "Invalid field name ($_)";
    }

    my $qry
        = q{SELECT
                srt.type
            ,   loc_src.id AS source_location_id
            ,   loc_src.location AS source_location
            ,   loc_dest.id AS bookout_location_id
            ,   loc_dest.location AS bookout_location
        ,   srq.channel_id AS channel_id
            ,   srt.code
            FROM sample_request srq
            INNER JOIN sample_request_type srt
                ON (srq.sample_request_type_id = srt.id)
            INNER JOIN location loc_src
                ON (srt.source_location_id = loc_src.id)
            INNER JOIN location loc_dest
                ON (srt.bookout_location_id = loc_dest.id)
        };
    $qry .= qq{ WHERE $where_clause} if defined $where_clause;

    my $sth = $dbh->prepare($qry);
    $sth->execute(@exec_args);

    my $request_type_ref = $sth->fetchrow_hashref();
    $sth->finish();
    return $request_type_ref;
}

sub get_current_det_status :Export(:SampleBooking) {
    my $args_ref                = shift;
    my $dbh                     = $args_ref->{dbh};
    my $sample_request_det_id   = $args_ref->{sample_request_det_id};

    my $qry
        = q{SELECT srds.status, op.name, TO_CHAR(srdsl.date, 'DD-Mon-YYYY HH24:MI') AS date, srdsl.location_id_to, l.location
            FROM sample_request_det srd INNER JOIN sample_request_det_status srds
                ON srd.sample_request_det_status_id = srds.id LEFT JOIN sample_request_det_status_log srdsl INNER JOIN location l
                ON srdsl.location_id_to = l.id INNER JOIN operator op
                ON srdsl.operator_id = op.id
                ON srd.sample_request_det_status_id = srdsl.sample_request_det_status_id AND srd.id = srdsl.sample_request_det_id
            WHERE srd.id = ?
            ORDER BY srdsl.date DESC LIMIT 1
        };

    my $sth = $dbh->prepare($qry);
    $sth->execute($sample_request_det_id);

    my $data_ref = $sth->fetchrow_hashref();
    $sth->finish();
    return $data_ref;
}

sub _transfer_item :Export(:justfortest) {
    my $args_ref                = shift;
    my $dbh_trans               = $args_ref->{dbh};
    my $variant_id              = $args_ref->{variant_id};
    my $quantity                = $args_ref->{quantity};
    my $old_loc                 = $args_ref->{old_loc};
    my $new_loc                 = $args_ref->{new_loc};
    my $channel_id              = $args_ref->{channel_id};
    my $current_status_id       = $args_ref->{current_status_id};
    my $new_status_id           = $args_ref->{new_status_id};

    ## fail if requested quantity is <= 0
    croak 'Transfer quantity must be greater than zero!' unless ( $quantity > 0 );

    ## fail if no channel_id passed
    if ( !defined $args_ref->{channel_id} || !$channel_id ) {
        die 'No channel_id passed to _transfer_item()';
    }

    ## get quantity of the specified variant in old_loc
    my $old_loc_qty = get_stock_location_quantity( $dbh_trans, {
        variant_id => $variant_id,
        location => $old_loc,
        channel_id => $channel_id,
        status_id => $current_status_id,
    } );

    ## fail if old_loc quantity is insufficient to fulfil request
    if ( ($old_loc_qty <= 0) || ($old_loc_qty < $quantity) ) {
        my $variant_details_ref = get_variant_details($dbh_trans, $variant_id);
        croak "Transfer failed! Requested quantity of item $variant_details_ref->{sku} ($quantity), exceeds quantity in location $old_loc ($old_loc_qty)";
    }

    ## decrement old_loc quantity and delete if this takes it to zero
    update_quantity( $dbh_trans, {
        variant_id => $variant_id,
        location => $old_loc,
        quantity => ($quantity*-1),
        type => 'dec',
        channel_id => $channel_id,
        current_status_id => $current_status_id,
    } );
    $old_loc_qty = get_stock_location_quantity( $dbh_trans, {
        variant_id => $variant_id,
        location => $old_loc,
        channel_id => $channel_id,
        status_id => $current_status_id,
    } );
    delete_quantity($dbh_trans, {
        variant_id => $variant_id,
        location => $old_loc,
        channel_id => $channel_id,
        status_id => $current_status_id,
    } ) if ( $old_loc_qty <= 0 );

    ## increment new_loc
    if ( check_stock_location( $dbh_trans, {
        variant_id => $variant_id,
        location => $new_loc,
        channel_id => $channel_id,
        status_id => $new_status_id,
    } ) > 0 ) {
        update_quantity( $dbh_trans, {
            variant_id => $variant_id,
            location => $new_loc,
            quantity => $quantity,
            type => 'inc',
            channel_id => $channel_id,
            current_status_id => $new_status_id,
        } );
    }
    else {
        insert_quantity( $dbh_trans, {
            variant_id => $variant_id,
            location => $new_loc,
            quantity => $quantity,
            channel_id => $channel_id,
            initial_status_id => $new_status_id,
        } );
    }
}

sub bookout_sample :Export(:SampleBooking) {
    my $args_ref                = shift;
    my $dbh_trans               = $args_ref->{dbh};
    my $request_det_id          = $args_ref->{sample_request_det_id};
    my $variant_id              = $args_ref->{variant_id};
    my $quantity_to_book        = $args_ref->{quantity_to_book};
    my $date_return_due         = $args_ref->{date_return_due};
    my $operator_id             = $args_ref->{operator_id};

    my $request_type_ref    = get_request_type( { dbh => $dbh_trans, select_by => { fname => 'sample_request_det_id', value => $request_det_id } } );

    my $source_loc      = $request_type_ref->{source_location};
    my $destination_loc = $request_type_ref->{bookout_location};
    my $channel_id      = $request_type_ref->{channel_id};

    ## transfer item
    _transfer_item({
        dbh         => $dbh_trans,
        variant_id  => $variant_id,
        quantity    => $quantity_to_book,
        old_loc     => $source_loc,
        new_loc     => $destination_loc,
        channel_id  => $channel_id,
        current_status_id => $FLOW_STATUS__SAMPLE__STOCK_STATUS,
        new_status_id   => ($request_type_ref->{code} eq 'prs' ? $FLOW_STATUS__SAMPLE__STOCK_STATUS : $FLOW_STATUS__CREATIVE__STOCK_STATUS ),
    });

    ## update sample_request_det 'return date'
    my $sql_update_request_det = q{UPDATE sample_request_det SET date_return_due = CAST(? AS timestamp without time zone) WHERE id = ?};

    my $sth_update_request_det = $dbh_trans->prepare( $sql_update_request_det );
    $sth_update_request_det->execute( $date_return_due, $request_det_id );

    ## set det_status and write det_status_log entry
    change_det_status({
        dbh                     => $dbh_trans,
        sample_request_det_id   => $request_det_id,
        det_status_id           => $SAMPLE_REQUEST_DET_STATUS__APPROVED,
        loc_from                => $source_loc,
        loc_to                  => $destination_loc,
        operator_id             => $operator_id,
    });
}

sub _get_bookin_location {
    my $args_ref        = shift;
    my $dbh             = $args_ref->{dbh};
    my $request_det_id  = $args_ref->{sample_request_det_id};

    my $det_status_log_ref
        = list_det_status_log({
                dbh                     => $dbh,
                sample_request_det_id   => $request_det_id,
                status_id               => $SAMPLE_REQUEST_DET_STATUS__APPROVED,
        });

    my $bookin_location = $det_status_log_ref->[0]{location_from};
    return $bookin_location;
}

sub bookin_sample :Export(:SampleBooking) {
    my $args_ref                = shift;
    my $dbh_trans               = $args_ref->{dbh};
    my $request_det_id          = $args_ref->{sample_request_det_id};
    my $variant_id              = $args_ref->{variant_id};
    my $quantity_to_book        = $args_ref->{quantity_to_book};
    my $old_loc                 = $args_ref->{old_loc};
    my $operator_id             = $args_ref->{operator_id};

    ## get location from which item was approved (in order to bookin from the original source location)
    my $bookin_loc          = _get_bookin_location( { dbh => $dbh_trans, sample_request_det_id => $request_det_id } );
    croak "Invalid bookin location" unless $bookin_loc;

    ## get info about sample_request to get the channel id
    my $request_type_ref = get_request_type( { dbh => $dbh_trans, select_by => { fname => 'sample_request_det_id', value => $request_det_id } } );
    my $channel_id       = $request_type_ref->{channel_id};

    ## transfer item from 'old_loc' to 'bookin_loc'
    _transfer_item({
        dbh         => $dbh_trans,
        variant_id  => $variant_id,
        quantity    => $quantity_to_book,
        old_loc     => $old_loc,
        new_loc     => $bookin_loc,
        channel_id  => $channel_id,
        current_status_id   => ($request_type_ref->{code} eq 'prs' ? $FLOW_STATUS__SAMPLE__STOCK_STATUS : $FLOW_STATUS__CREATIVE__STOCK_STATUS ),
        new_status_id   => $FLOW_STATUS__SAMPLE__STOCK_STATUS,
    });

    ## update request_det returned date
    my $sql_update_request_det
        = q{UPDATE sample_request_det SET date_returned = LOCALTIMESTAMP
            WHERE id = ?
        };

    my $sth_update_request_det = $dbh_trans->prepare($sql_update_request_det);
    $sth_update_request_det->execute($request_det_id);

    ## set det_status and write det_status_log entry
    change_det_status({
        dbh                     => $dbh_trans,
        sample_request_det_id   => $request_det_id,
        det_status_id           => $SAMPLE_REQUEST_DET_STATUS__RETURNED,
        loc_from                => $old_loc,
        loc_to                  => $bookin_loc,
        operator_id             => $operator_id,
    });
}

sub bookout_request :Export(:SampleBooking) {
    my ($dbh,$args_ref) = @_;

    my $request_id      = $args_ref->{sample_request_id};
    my $date_return_due = $args_ref->{date_return_due};
    my $operator_id     = $args_ref->{operator_id};

    croak 'Invalid sample_request_id' unless $request_id =~ m{\A\d+\z}xms;

    my $request_type_ref    = get_request_type( { dbh => $dbh, select_by => { fname => 'sample_request_id', value => $request_id } } );

    my $destionation_loc    = $request_type_ref->{bookout_location};

    my $qry_list_dets   = q{
            SELECT  srd.id AS sample_request_det_id, srd.variant_id, srd.quantity, srds.status, srds.id AS status_id
            FROM    sample_request_det srd
                    INNER JOIN sample_request_det_status srds ON srd.sample_request_det_status_id = srds.id
            WHERE   srd.sample_request_id = ?
            ORDER BY srd.id
        };

    my $sth_list_dets   = $dbh->prepare($qry_list_dets);
    $sth_list_dets->execute($request_id);

    my $request_dets_ref    = results_list($sth_list_dets);

    foreach my $det_ref (@$request_dets_ref) {
        next        unless ( $det_ref->{status_id} eq $SAMPLE_REQUEST_DET_STATUS__AWAITING_APPROVAL );

        my $request_det_id      = $det_ref->{sample_request_det_id};
        my $variant_id          = $det_ref->{variant_id};
        my $quantity_to_book    = $det_ref->{quantity};

        bookout_sample({
            dbh                     => $dbh,
            sample_request_det_id   => $request_det_id,
            variant_id              => $variant_id,
            quantity_to_book        => $quantity_to_book,
            new_loc                 => $destionation_loc,
            date_return_due         => $date_return_due,
            operator_id             => $operator_id,
        });
    }
}

sub write_request_conf_header :Export(:SampleBooking) {
    my $args_ref                = shift;
    my $dbh_trans               = $args_ref->{dbh};
    my $request_id              = $args_ref->{sample_request_id};
    my $date_confirmed          = $args_ref->{date_confirmed};
    my $date_return_due         = $args_ref->{date_return_due};
    my $operator_id             = $args_ref->{operator_id};

    my $values_list = '?, Default, ?, ?';
    my @bind_list   = ();

    push @bind_list, $request_id;

    if ($date_confirmed) {
        $values_list = '?, ?, ?, ?';
        push @bind_list, $date_confirmed
    }

    push @bind_list, $date_return_due, $operator_id;

    my $sql = qq{INSERT INTO sample_request_conf (sample_request_id, date_confirmed, date_return_due, operator_id) VALUES ($values_list)};

    my $sth = $dbh_trans->prepare($sql);
    $sth->execute(@bind_list);

    ## fetch sample_request_conf
    my $sample_request_conf_id  = last_insert_id( $dbh_trans, 'sample_request_conf_id_seq' );
    return $sample_request_conf_id;
}

sub write_request_conf_dets :Export(:SampleBooking) {
    my $args_ref                = shift;
    my $dbh_trans               = $args_ref->{dbh};
    my $sample_request_conf_id  = $args_ref->{sample_request_conf_id};
    my $request_det_id          = $args_ref->{sample_request_det_id};
    my $variant_id              = $args_ref->{variant_id};
    my $quantity                = $args_ref->{quantity};

    my $sql
        = q{INSERT INTO sample_request_conf_det (sample_request_conf_id, sample_request_det_id, variant_id, quantity)
            VALUES (?, ?, ?, ?)
        };

    my $sth = $dbh_trans->prepare($sql);
    $sth->execute($sample_request_conf_id, $request_det_id, $variant_id, $quantity);

    ## update sample_request_conf_det table with additional details
    update_request_conf_dets( { dbh => $dbh_trans, sample_request_conf_id => $sample_request_conf_id } );
}

sub update_request_conf_dets :Export(:SampleBooking) {
    my $args_ref            = shift;
    my $dbh_trans           = $args_ref->{dbh};
    my $request_conf_id     = $args_ref->{sample_request_conf_id};

    my $sql
        = q{UPDATE sample_request_conf_det SET
                sku = v.product_id || '-' || sku_padding(v.size_id),
                legacy_sku = v.legacy_sku,
                name = pa.name,
                description = pa.description,
                size = sz.size,
                designer = d.designer
            FROM variant v INNER JOIN product p INNER JOIN product_attribute pa
                ON p.id = pa.product_id
                ON v.product_id = pa.product_id INNER JOIN size sz
                ON v.size_id = sz.id INNER JOIN designer d
                ON p.designer_id = d.id
            WHERE sample_request_conf_det.variant_id = v.id
            AND sample_request_conf_det.sample_request_conf_id = ?};

    my $sth = $dbh_trans->prepare($sql);
    $sth->execute($request_conf_id);
}

sub list_request_conf_dets :Export(:SampleBooking) {
    my $args_ref        = shift;
    my $dbh             = $args_ref->{dbh};
    my $type            = $args_ref->{type};
    my $id              = $args_ref->{id};

    my %where_clause = (
        sample_request_id       => 'src.sample_request_id = ?',
        sample_request_conf_id  => 'srcd.sample_request_conf_id = ?',
    );
    my $where_clause = $where_clause{$type};

    my $qry_header
        = qq{SELECT DISTINCT src.id as sample_request_conf_id, src.sample_request_id, lpad(CAST(src.sample_request_id AS varchar), 5, '0') AS sample_request_ref,
                TO_CHAR(src.date_confirmed, 'DD-Mon-YYYY') AS date_confirmed, TO_CHAR(src.date_return_due, 'DD-Mon-YYYY') AS date_return_due,
                src.operator_id, srr.sample_receiver_id, op.name as operator_name,
                ch.id AS channel_id, ch.name AS sales_channel
            FROM sample_request_conf src
                INNER JOIN sample_request_conf_det srcd
                    ON src.id = srcd.sample_request_conf_id
                LEFT JOIN sample_request_receiver srr
                    ON src.sample_request_id = srr.sample_request_id
                INNER JOIN operator op
                    ON src.operator_id = op.id
                INNER JOIN sample_request sr
                    ON src.sample_request_id = sr.id
                INNER JOIN channel ch
                    ON sr.channel_id = ch.id
            WHERE $where_clause
            ORDER BY src.id
    };

    my $sth_header = $dbh->prepare($qry_header);
    $sth_header->execute($id);
    my $data_header_ref = results_list($sth_header);

    my $qry_dets = qq{SELECT * FROM sample_request_conf_det WHERE sample_request_conf_id = ? ORDER BY id};
    my $sth_dets = $dbh->prepare($qry_dets);

    my @conf_list;

    foreach (@$data_header_ref) {
        my $record_ref = $_;

        my $receiver_dets_ref = get_sample_receiver_dets( { dbh => $dbh, receiver_id => $_->{sample_receiver_id} } );
        my @receiver_dets;
        push ( @receiver_dets, $receiver_dets_ref->[0]{$_} ) foreach ( qw(name address_line_1 address_line_2 address_line_3 towncity county postcode country) );
        @receiver_dets = grep { /\S/ } @receiver_dets;

        $record_ref->{receiver_dets} = \@receiver_dets;

        $sth_dets->execute($_->{sample_request_conf_id});
        my $data_dets_ref = results_list($sth_dets);

        $record_ref->{items} = $data_dets_ref;

        push @conf_list, $record_ref
    }
    return \@conf_list;
}

1;
