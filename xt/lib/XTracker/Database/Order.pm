package XTracker::Database::Order;
use strict;
use warnings;
use Perl6::Export::Attrs;
use Digest::MD5;

use XTracker::Constants::FromDB qw( :business :renumeration_type);
use XTracker::Database::Address;
use XTracker::Database::Customer;
use XTracker::Database::Shipment qw( get_order_shipment_info get_shipment_item_info is_standard_or_active_shipment is_cancelled_item );
use XTracker::Database::Utilities qw(results_list);
use XTracker::Database qw/ get_schema_using_dbh /;
use XTracker::DBEncode qw( decode_db );
use Data::Dump 'pp';

## FIXME _store_tenders and create_order should be deleted on jimmychoo completion
sub create_order :Export(:DEFAULT) {
    my ( $dbh, $data_ref, $addr_ref ) = @_;

    my $orders_id   = 0;
    my $address_id  = 0;
    my $data = {};

    ### hash address
    $$addr_ref{hash} = hash_address( $dbh, $addr_ref );

    ### check if address exists in db
    $address_id = check_address( $dbh, $$addr_ref{hash} );

    ### if not insert new address
    if ( $address_id == 0 ) {
        create_address( $dbh, $addr_ref );
        $address_id = check_address( $dbh, $$addr_ref{hash} );
    }

    my $schema = get_schema_using_dbh( $dbh, 'xtracker_schema' );
    my $order  = $schema->resultset('Public::Orders')->create({
                    session_id => '',
                    order_nr => $data_ref->{order_nr},
                    basket_nr => $data_ref->{basket_id},
                    invoice_nr => '',
                    session_id => $data_ref->{session_id},
                    cookie_id => $data_ref->{cookie_id},
                    date => $data_ref->{order_date},
                    total_value => $data_ref->{gross_total},
                    gift_credit => $data_ref->{gift_credit},
                    store_credit => $data_ref->{store_credit},
                    customer_id => $data_ref->{customer_id},
                    invoice_address_id => $address_id,
                    credit_rating => $data_ref->{credit_rating},
                    card_issuer => $data_ref->{card_issuer},
                    card_scheme => $data_ref->{card_scheme},
                    card_country => $data_ref->{card_country},
                    card_hash => $data_ref->{card_number},
                    cv2_response => $data_ref->{cv2_response},
                    order_status_id => $data_ref->{order_status_id},
                    email => $data_ref->{email},
                    telephone => $data_ref->{telephone},
                    mobile_telephone => $data_ref->{mobile_telephone},
                    comment => '',
                    currency_id => $data_ref->{currency_id},
                    use_external_tax_rate => $data_ref->{use_external_tax_rate},
                    used_stored_card => $data_ref->{used_stored_card},
                    channel_id => $data_ref->{channel_id},
                    ip_address =>  $data_ref->{ip_address},
                    placed_by => $data_ref->{placed_by},
                   });

    $order->discard_changes;
    _store_tenders($schema, $order, $data_ref->{tenders});

    return $order->id;
}

sub _store_tenders {
    my ($schema, $order, $tenders) = @_;

    my $i = scalar(@$tenders) + 1;
    for my $tender (@{$tenders}) {
        $tender->{rank} = $i-- unless length $tender->{rank};

        my $type = delete $tender->{type};
        $tender->{type_id} = $schema->resultset('Public::RenumerationType')
                                    ->search({ type => $type })
                                    ->first
                                    ->id;

        die "couldn't look up tender type" unless $tender->{type_id};

        if (my $c = delete $tender->{voucher_code} ) {
            my $vi = $schema->resultset('Voucher::Code')->search({code => $c})->first;

            die "couldn't find voucher with code '$c' on the system"
                unless defined $vi;

            $tender->{voucher_code_id} = $vi->id;
        }

        $order->add_to_tenders($tender);
    }
}


sub get_order_info :Export(:DEFAULT) {
    my ( $dbh, $order_id ) = @_;

    my $qry = "
        SELECT o.*,
               ch.business_id,
               ch.name as sales_channel,
               os.status,
               c.currency,
               oa.source_app_name as app_name,
               oa.source_app_version as app_version,
               to_char(o.date, 'DD-MM-YYYY HH24:MI') as live_order_taken_date,
               to_char(o.order_created_in_xt_date, 'DD-MM-YYYY HH24:MI') as order_created_in_xt_date
        FROM orders o
        JOIN channel ch ON o.channel_id = ch.id
        JOIN order_status os ON o.order_status_id = os.id
        JOIN currency c ON o.currency_id = c.id
        LEFT JOIN order_attribute oa ON oa.orders_id = o.id
        WHERE o.id = ?
    ";

    my $sth = $dbh->prepare($qry);
    $sth->execute($order_id);

    my $order = $sth->fetchrow_hashref();

    return $order;
}


sub get_order_notes :Export(:DEFAULT) {
    my ( $dbh, $order_id ) = @_;

    my $qry = "SELECT ono.id, to_char(ono.date, 'DD-MM-YY HH24:MI') as date, extract(epoch from ono.date) as date_sort,
                      ono.note, ono.operator_id, nt.description, op.name, d.department
               FROM order_note ono, note_type nt, operator op LEFT JOIN department d ON op.department_id = d.id
               WHERE ono.orders_id = ?
               AND ono.note_type_id = nt.id
               AND ono.operator_id = op.id";

    my $sth = $dbh->prepare($qry);
    $sth->execute($order_id);

    my %notes;

    while ( my $note = $sth->fetchrow_hashref() ) {
        $note->{$_} = decode_db( $note->{$_} ) for (qw( note ));
        $notes{ $$note{id} } = $note;
    }

    return \%notes;
}

sub get_order_log :Export(:DEFAULT) {
    my ( $dbh, $order_id ) = @_;

    my $qry = "SELECT osl.id,
                      to_char(osl.date, 'DD-MM-YY HH24:MI') as date,
                      osl.operator_id,
                      osl.bulk_order_action_log_id,
                      os.status,
                      op.name,
                      d.department
                 FROM order_status_log osl,
                      order_status os,
                      operator op LEFT JOIN department d ON op.department_id = d.id
                WHERE osl.orders_id = ?
                  AND osl.order_status_id = os.id
                  AND osl.operator_id = op.id";

    my $sth = $dbh->prepare($qry);
    $sth->execute($order_id);

    my %log;

    while ( my $row = $sth->fetchrow_hashref() ) {
        $log{ $$row{id} } = $row;
    }

    return \%log;
}

sub get_order_emails :Export(:DEFAULT) {
    my ( $dbh, $shipment_id ) = @_;

    my $qry
        = "SELECT oe.id, op.name as operator, to_char(date, 'DD-MM-YYYY  HH24:MI') as date, ct.name as template FROM order_email_log oe, operator op, correspondence_templates ct WHERE oe.orders_id = ? AND oe.operator_id = op.id and oe.correspondence_templates_id = ct.id";

    my $sth = $dbh->prepare($qry);
    $sth->execute($shipment_id);

    my %shipments;

    while ( my $shipment = $sth->fetchrow_hashref() ) {
        $shipments{ $$shipment{id} } = $shipment;
    }

    return \%shipments;

}

sub get_customer_orders :Export(:DEFAULT) {

    my ( $dbh, $customer_id ) = @_;

    my $qry = "
    SELECT o.*,
           ch.name as sales_channel,
           to_char(o.date,
           'DD-MM-YYYY  HH24:MI') as order_date,
           os.status, c.currency,
           oa.source_app_name as app_name,
           oa.source_app_version as app_version
    FROM orders o
    JOIN order_status os ON o.order_status_id = os.id
    JOIN channel ch ON o.channel_id = ch.id
    JOIN currency c ON o.currency_id = c.id
    LEFT JOIN order_attribute oa ON oa.orders_id = o.id
    WHERE o.customer_id = ?
    ";

    my $sth = $dbh->prepare($qry);
    $sth->execute($customer_id);

    my %data;

    while ( my $row = $sth->fetchrow_hashref() ) {
        $data{ $row->{id} } = $row;
    }

    return \%data;

}

sub update_order_status :Export(:DEFAULT) {
    my ( $dbh, $id, $status ) = @_;

    my $qry = "UPDATE orders SET order_status_id = ? WHERE id = ?";

    my $sth = $dbh->prepare($qry);

    $sth->execute( $status, $id );
}

sub log_order_status :Export(:DEFAULT) {
    my ( $dbh, $id, $status, $operator_id, $bulk_order_action_log_id) = @_;

    my $qry
        = "INSERT INTO order_status_log (
            id, orders_id, order_status_id, operator_id, date, bulk_order_action_log_id
           ) VALUES (default, ?, ?, ?, current_timestamp, ?)";

    my $sth = $dbh->prepare($qry);

    $sth->execute( $id, $status, $operator_id, $bulk_order_action_log_id );
}

sub update_order_details :Export(:DEFAULT) {
    my ( $dbh, $id, $email, $telephone, $mobile_telephone ) = @_;

    my $qry = "UPDATE orders
                SET email = ?,
                 telephone = ?,
                 mobile_telephone = ?
                    WHERE id = ?";

    my $sth = $dbh->prepare($qry);

    $sth->execute( $email, $telephone, $mobile_telephone, $id );

}

sub update_order_address :Export(:DEFAULT) {
    my ( $dbh, $id, $invoice_address_id ) = @_;

    my $qry = "UPDATE orders SET invoice_address_id = ? WHERE id = ?";

    my $sth = $dbh->prepare($qry);

    $sth->execute( $invoice_address_id, $id );
}

sub log_order_address_change :Export(:DEFAULT) {
    my ( $dbh, $order_id, $change_from, $change_to, $operator_id ) = @_;

    my $qry
        = "INSERT INTO order_address_log (
            id, orders_id, changed_from, changed_to, operator_id, date
        ) VALUES (default, ?, ?, ?, ?, current_timestamp)";

    my $sth = $dbh->prepare($qry);

    $sth->execute( $order_id, $change_from, $change_to, $operator_id );
}

sub get_order_address_log :Export(:DEFAULT) {
    my ( $dbh, $order_id ) = @_;

    my $qry
        = "SELECT oal.*, to_char(oal.date, 'DD-MM-YYYY  HH24:MI') as date, op.name FROM order_address_log oal, operator op WHERE oal.orders_id = ? AND oal.operator_id = op.id";

    my $sth = $dbh->prepare($qry);
    $sth->execute($order_id);

    my %docs;

    while ( my $row = $sth->fetchrow_hashref() ) {
        $docs{ $$row{id} } = $row;
    }

    return \%docs;
}

sub set_order_flag :Export(:DEFAULT) {
    my ( $dbh, $id, $flag_id ) = @_;

    my $qry = "INSERT INTO order_flag (flag_id, orders_id) VALUES (?, ?)";

    my $sth = $dbh->prepare($qry);

    $sth->execute( $flag_id, $id );
}

sub delete_order_flag :Export(:DEFAULT) {
    my ( $dbh, $id, $flag_id ) = @_;

    my $qry = "DELETE FROM order_flag WHERE orders_id = ? AND flag_id = ?";

    my $sth = $dbh->prepare($qry);

    $sth->execute( $id, $flag_id );
}

### Subroutine : check_order_payment                                            ###
# usage        :                                                                #
# description  :  returns 0 by default or 1 if card payment found and has been fulfilled  #
#                 if order uses store credit only will always return 0          #
# parameters   :                                                                #
# returns      :                                                                #

sub check_order_payment :Export(:DEFAULT) {
    my ( $dbh, $orders_id ) = @_;

    my $payment = 0;

    my $qry = "SELECT fulfilled FROM orders.payment WHERE orders_id = ?";

    my $sth = $dbh->prepare($qry);
    $sth->execute($orders_id);

    while ( my $row = $sth->fetchrow_hashref() ) {
        $payment = $$row{fulfilled};
    }

    return $payment;

}

sub create_order_promotion :Export(:DEFAULT) {
    my ( $dbh, $id, $type_id, $value, $code ) = @_;

    my $qry = "INSERT INTO order_promotion (
            id, orders_id, promotion_type_id, value, code
        ) VALUES (default, ?, ?, ?, ?)";

    # FIXME: some error checking please
    my $sth = $dbh->prepare($qry);

    $sth->execute( $id, $type_id, $value, $code );

}

sub get_order_promotions :Export(:DEFAULT) {
    my ( $dbh, $order_id ) = @_;

    my $qry = "SELECT op.id, op.value, op.code, pt.name, pt.product_type, pt.weight, pt.fabric, pt.origin, pt.hs_code, pt.promotion_class_id, pc.class
                FROM order_promotion op, promotion_type pt, promotion_class pc
                WHERE op.orders_id = ?
                AND op.promotion_type_id = pt.id
                AND pt.promotion_class_id = pc.id";

    my $sth = $dbh->prepare($qry);
    $sth->execute($order_id);

    my %data;

    while ( my $row = $sth->fetchrow_hashref() ) {
        $data{ $$row{id} } = $row;
    }

    return \%data;

}

sub get_order_flags :Export() {
    my ($dbh,$orders_id) = @_;

    my %flags;

    my $qry = "SELECT
        ofl.id,
        f.flag_type_id,
        f.description
    FROM
        flag f, order_flag ofl
    WHERE
        ofl.orders_id = ?
        AND ofl.flag_id = f.id";

    my $sth = $dbh->prepare($qry);
    $sth->execute($orders_id);

    while ( my $row = $sth->fetchrow_hashref ) {
        $flags{ $row->{id} } = $row;
    }

    return \%flags;

}


sub search_by_order_nr :Export( :DEFAULT ) {
    my ($dbh, $order_nr) = @_;

    my %list = ();

    my $qry = "SELECT o.id as order_id, o.order_nr, s.id, to_char(s.date, 'DD-MM-YYYY HH24:MI') as date, ss.status, sc.class, c.first_name, c.last_name
                        FROM orders o, customer c, link_orders__shipment los, shipment s, shipment_status ss, shipment_class sc
                        WHERE o.order_nr = ?
                        AND o.customer_id = c.id
                        AND o.id = los.orders_id
                        AND los.shipment_id = s.id
                        AND s.shipment_status_id = ss.id
                        AND s.shipment_class_id = sc.id
                        ";

    my $sth = $dbh->prepare($qry);
    $sth->execute($order_nr);

    while ( my $row = $sth->fetchrow_hashref() ) {

        $list{ $$row{order_id}.$$row{id} } = $row;

    }

    return \%list;
}

sub get_order_id :Export() {
    my($dbh,$order_nr) = @_;

    my $sql = "SELECT id FROM orders WHERE order_nr = ?";

    my $sth = $dbh->prepare($sql);
    $sth->execute($order_nr) or die $dbh->errstr;

    my $row = $sth->fetchrow_hashref();

    return $row->{id}
        if (defined $row->{id});

    return undef;
}

sub log_order_access :Export() {
    my ( $dbh, $orders_id, $operator_id ) = @_;

    my $qry = "INSERT INTO log_order_access ( orders_id, operator_id, date ) VALUES (?, ?, current_timestamp)";
    my $sth = $dbh->prepare($qry);

    $sth->execute( $orders_id, $operator_id );

    return;
}


sub get_order_access_log :Export() {
    my ( $dbh, $order_id ) = @_;

    my $qry = "SELECT log.id, to_char(log.date, 'DD-MM-YYYY') as date, to_char(log.date, 'HH24:MI') as time, log.operator_id, op.name, d.department
               FROM log_order_access log, operator op LEFT JOIN department d ON op.department_id = d.id
               WHERE log.orders_id = ?
               AND log.operator_id = op.id";

    my $sth = $dbh->prepare($qry);
    $sth->execute($order_id);

    my %data;

    while ( my $row = $sth->fetchrow_hashref() ) {
        $data{ $row->{id} } = $row;
    }

    return \%data;
}

### Subroutine : get_order_total_charge                       ###
# usage        : get_order_total_charge($dbh, $order_id)        #
# description  : calculates the total charge for a given order  #
# parameters   : $dbh, $order_id                                #
# returns      : integer                                        #

sub get_order_total_charge :Export() {
    my ($dbh, $order_id)    = @_;

    my $total_charge        = 0;    # start with nothing to charge

    # if we haven't been passed an order id - warn and fail
    if (!$order_id) {
        Carp::carp( q{No order id provided for get_order total_charge} );
        return;
    }

    # get shipments on order
    my $shipments = get_order_shipment_info($dbh, $order_id);

    if ($shipments) {
        my $schema  = get_schema_using_dbh( $dbh, 'xtracker_schema' );
        my $order   = $schema->resultset('Public::Orders')->find( $order_id );

        # calculate total gift voucher charge
        my $count               = 0;
        my $total_gift_voucher  = 0;
        my $tenders = $order->tenders->search( { type_id => $RENUMERATION_TYPE__VOUCHER_CREDIT } );
        while ( my $tender = $tenders->next ) {
            $total_gift_voucher += $tender->value;
        }
        $total_gift_voucher *= -1;      # make it negative

        # There should only ever be 1 shipment (outgoing, standard) per order
        # loop through all the shipments
        foreach my $shipment_id (keys %{$shipments}){

            # only standard and active shipments
            if ( is_standard_or_active_shipment($shipments->{$shipment_id}) ) {
                $count++;
                if ( $count == 1 ) {
                    # if going through this the first time
                    $total_charge   += $total_gift_voucher;
                }

                $total_charge +=
                                  sprintf( "%.2f", $shipments->{$shipment_id}{shipping_charge} )
                                + sprintf( "%.2f", $shipments->{$shipment_id}{gift_credit} )
                                + sprintf( "%.2f", $shipments->{$shipment_id}{store_credit} )
                ;

                # get items in shipment
                my $items = get_shipment_item_info($dbh, $shipment_id);

                foreach my $item_id (keys %{$items}){
                    # ignore cancelled items
                    if (not is_cancelled_item($items->{$item_id})) {
                        $total_charge +=
                                          sprintf( "%.2f", $items->{$item_id}{unit_price} )
                                        + sprintf( "%.2f", $items->{$item_id}{tax} )
                                        + sprintf( "%.2f", $items->{$item_id}{duty} )
                        ;
                    }
                }
            }
        }

    }

    return sprintf( "%.2f", $total_charge);

}

### Subroutine : get_cancellation_reasons            ###
# usage        : get_cancellation_reasons($dbh);    #
# description  : returns a list of cancellation reasons #
# parameters   :  db handle                                #
# returns      :  hash ref                                #

sub get_cancellation_reasons :Export() {
    my ( $dbh ) = @_;

    my %reasons;

    my $qry = "select id, description from customer_issue_type where group_id = 8";
    my $sth = $dbh->prepare($qry);
    $sth->execute();

    while ( my $reason = $sth->fetchrow_hashref() ) {
        $reasons{ $$reason{id} } = $$reason{description};
    }

    return \%reasons;

}

### Subroutine : get_cancellation_reason             ###
# usage        : get_cancellation_reason($dbh, $reason_id) #
# description  : returns the description for a given id         #
# parameters   : dbh, id                                       #
# returns      : string                                #

sub get_cancellation_reason :Export() {
    my ( $dbh, $id ) = @_;

    my %reasons;

    my $qry = "select description from customer_issue_type where id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute($id);

    my $reason = $sth->fetchrow_hashref();

    return $$reason{description};

}


sub get_orders_by_date :Export() {
    my ($dbh, $date, $sales_channel) = @_;

    my %list = ();

    my $qry = "SELECT o.id as order_id, o.order_nr, to_char(o.date, 'HH24:MI') AS time, (o.total_value + o.store_credit) AS value, c.first_name, c.last_name, oa.postcode, oa.towncity, oa.country, cur.currency, ch.name as sales_channel
                FROM orders o, customer c, link_orders__shipment los, shipment s, order_address oa, currency cur, channel ch
                WHERE DATE_TRUNC('day', o.date)= ?
                AND o.id = los.orders_id
                AND los.shipment_id = s.id
                AND o.customer_id = c.id
                AND s.shipment_address_id = oa.id
                AND o.currency_id = cur.id
                AND o.channel_id = ch.id
    ";

    if ($sales_channel) {
        $qry .= " AND ch.name = '$sales_channel'";
    }

    my $sth = $dbh->prepare($qry);
    $sth->execute($date);

    while ( my $row = $sth->fetchrow_hashref() ) {
        $row->{$_} = decode_db( $row->{$_} ) for (qw(
            first_name
            last_name
            towncity
        ));
        $list{ $row->{order_id} } = $row;
    }

    return \%list;

}

1;
