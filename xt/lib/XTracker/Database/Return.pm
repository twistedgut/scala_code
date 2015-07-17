package XTracker::Database::Return;

use strict;
use warnings;

use Perl6::Export::Attrs;
use Data::Dump qw/pp/;
use Scalar::Util qw/ blessed /;

use XTracker::Database::Invoice;
use XTracker::Database::Product;
use XTracker::Database::Address     qw( get_dbic_country );
use XTracker::Config::Local qw( config_var );
use XTracker::DBEncode qw( decode_db );
use XTracker::Constants qw( :application );
use XTracker::Constants::FromDB qw(
    :customer_issue_type
    :delivery_item_type
    :refund_charge_type
    :renumeration_class
    :renumeration_status
    :renumeration_type
    :return_item_status
    :return_status
    :return_type
    :shipment_item_status
    :shipment_type
    :stock_process_status
    :stock_process_type
    :note_type
);
use XT::Rules::Solve;

use Carp;
use DateTime;

sub generate_RMA :Export(:DEFAULT) {

    my ( $dbh, $shipment_id ) = @_;

    my $rma_nr = "";
    my $dc_country = config_var('DistributionCentre', 'country');

    my $qry = "SELECT nextval('rma_nr')";
    my $sth = $dbh->prepare($qry);
    $sth->execute();
    my $row = $sth->fetchrow_arrayref();

    if ($dc_country eq 'United States') {
        $rma_nr = "U" . $shipment_id . "-" . $row->[0];
    }
    else {
        $rma_nr = "R" . $shipment_id . "-" . $row->[0];
    }

    return $rma_nr;

}

### Subroutine : create_return                  ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub create_return :Export(:DEFAULT) {

    my ( $dbh, $shipment_id, $rma_number, $return_status_id, $comment, $pickup ) = @_;

    my $return_id = 0;

    my $insqry = "INSERT INTO return (id, shipment_id, rma_number, return_status_id, comment, exchange_shipment_id, pickup) VALUES (default, ?, ?, ?, ?, null, ?)";
    my $inssth = $dbh->prepare($insqry);
    $inssth->execute( $shipment_id, $rma_number, $return_status_id, $comment, $pickup );

    my $selqry = "SELECT id FROM return WHERE rma_number = ?";
    my $selsth = $dbh->prepare($selqry);
    $selsth->execute($rma_number);
    while ( my $rows = $selsth->fetchrow_arrayref ) {
        $return_id = $rows->[0];
    }

    return $return_id;

}

### Subroutine : find_return                    ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub find_return :Export(:DEFAULT) {

    my ( $dbh, $search ) = @_;

    my $qry = "";

    ### RMA
    if ( $search =~ m/^R/ || $search =~ m/^U/ ) {
        $qry = "SELECT id FROM return WHERE rma_number = ?";
    }
    ### Airway Bill
    elsif ( $search =~ /^\d{10}$/ ) {
        $qry
            = "SELECT r.id FROM return r, shipment s WHERE s.return_airway_bill = ? AND s.id = r.shipment_id";
    }
    ### Order Number
    elsif ( $search =~ /\w{6}-\w+/ ) {
        $qry
            = "SELECT r.id FROM return r, shipment s, link_orders__shipment los, orders o WHERE o.order_nr = ? AND o.id = los.orders_id AND los.shipment_id = s.id AND s.id = r.shipment_id";
    }
    ### Shipment Number ?
    elsif ( $search =~ /\d+/ ) {
        $qry
            = "SELECT r.id FROM return r, shipment s WHERE s.id = ? AND s.id = r.shipment_id";
    }
    else {

    }

    my %returns;

    if ( $qry ne "" ) {

        my $sth = $dbh->prepare($qry);
        $sth->execute($search);
        while ( my $ret = $sth->fetchrow_hashref() ) {
            $returns{ $$ret{id} } = $ret;
        }
    }

    return \%returns;

}

### Subroutine : get_return_id_by_delivery      ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_return_id_by_delivery :Export(:DEFAULT) {

    my ( $dbh, $delivery_id ) = @_;

    my $qry = "SELECT return_id FROM link_delivery__return WHERE delivery_id = ?";

    my $sth = $dbh->prepare($qry);
    $sth->execute($delivery_id);

    my $return_id = 0;

    while ( my $row = $sth->fetchrow_arrayref() ) {
        $return_id = $row->[0];
    }

    return $return_id;

}

### Subroutine : get_return_id_by_process_group ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_return_id_by_process_group :Export(:DEFAULT) {

    my ( $dbh, $group_id ) = @_;

    $group_id =~ s/^p-//i;

    my $qry = "SELECT ri.return_id
                FROM stock_process sp, link_delivery_item__return_item ldiri, return_item ri
                WHERE sp.group_id = ?
                AND sp.delivery_item_id = ldiri.delivery_item_id
                AND ldiri.return_item_id = ri.id";

    my $sth = $dbh->prepare($qry);
    $sth->execute($group_id);

    my $return_id = 0;

    while ( my $row = $sth->fetchrow_arrayref() ) {
        $return_id = $row->[0];
    }

    return $return_id;

}

### Subroutine : get_process_group_by_rma       ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_process_group_by_rma :Export(:DEFAULT) {

    my ( $dbh, $rma ) = @_;

    my $qry = "select sp.group_id
                from stock_process sp, delivery_item di, link_delivery__return ldr, return r
                where r.rma_number= ?
                and r.id = ldr.return_id
                and ldr.delivery_id = di.delivery_id
                and di.id = sp.delivery_item_id
                and sp.complete = false";

    my $sth = $dbh->prepare($qry);
    $sth->execute($rma);

    my $group_id = 0;

    while ( my $row = $sth->fetchrow_arrayref() ) {
        $group_id = $row->[0];
    }

    return $group_id;

}

### Subroutine : get_delivery_id_by_rma         ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_delivery_id_by_rma :Export(:DEFAULT) {

    my ( $dbh, $rma ) = @_;

    my $qry = "select ldr.delivery_id
                from link_delivery__return ldr, return r
                where r.rma_number= ?
                and r.id = ldr.return_id
                and ldr.delivery_id IN (
                select di.delivery_id from delivery_item di, stock_process sp
                where sp.status_id = $STOCK_PROCESS_STATUS__NEW and sp.type_id = $STOCK_PROCESS_TYPE__MAIN
                and sp.delivery_item_id = di.id
                and di.type_id IN ($DELIVERY_ITEM_TYPE__CUSTOMER_RETURN, $DELIVERY_ITEM_TYPE__SAMPLE_RETURN))";

    my $sth = $dbh->prepare($qry);
    $sth->execute($rma);

    my $delivery_id = 0;

    while ( my $row = $sth->fetchrow_arrayref() ) {
        $delivery_id = $row->[0];
    }

    return $delivery_id;

}

### Subroutine : get_shipment_returns           ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_shipment_returns :Export(:DEFAULT) {

    my ( $dbh, $shipment_id ) = @_;

    my $qry
        = "SELECT r.*, rs.status, to_char(rsl.date, 'DD-MM-YYYY  HH24:MI') as date_created, ch.name as sales_channel
            FROM return r, shipment s LEFT JOIN link_orders__shipment los ON s.id = los.shipment_id LEFT JOIN orders o ON los.orders_id = o.id LEFT JOIN channel ch ON o.channel_id = ch.id, return_status rs, return_status_log rsl
            WHERE r.shipment_id = ?
            AND r.shipment_id = s.id
            AND r.return_status_id = rs.id
            AND r.id = rsl.return_id
            AND rsl.return_status_id = 1";

    my $sth = $dbh->prepare($qry);
    $sth->execute($shipment_id);

    my %returns;

    while ( my $ret = $sth->fetchrow_hashref() ) {
        $returns{ $$ret{id} } = $ret;
    }

    return \%returns;

}

### Subroutine : get_return_info                ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_return_info :Export(:DEFAULT) {

    my ( $dbh, $return_id ) = @_;

    my $qry
        = q{SELECT r.*,
                   rs.status,
                   to_char(rsl.date, 'DD-MM-YYYY  HH24:MI') as date_created,
                   to_char(r.expiry_date, 'DD-MM-YYYY') as expiry_date,
                   to_char(r.cancellation_date, 'DD-MM-YYYY') as cancellation_date
            FROM   return r,
                   return_status rs,
                   return_status_log rsl
            WHERE  r.id = ?
            AND    r.return_status_id = rs.id
            AND    r.id = rsl.return_id
            AND    rsl.return_status_id = 1
    };

    my $sth = $dbh->prepare($qry);
    $sth->execute($return_id);

    my $ret = $sth->fetchrow_hashref();

    return $ret;

}

### Subroutine : get_return_log                 ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_return_log :Export(:DEFAULT) {

    my ( $dbh, $return_id ) = @_;

    my $qry
        = "SELECT rsl.id, rs.status, o.name, to_char(rsl.date, 'DD-MM-YYYY  HH24:MI') as date FROM return_status_log rsl, return_status rs, operator o WHERE rsl.return_id = ? AND rsl.return_status_id = rs.id AND rsl.operator_id = o.id";

    my $sth = $dbh->prepare($qry);
    $sth->execute($return_id);

    my %items;

    while ( my $item = $sth->fetchrow_hashref() ) {
        $items{ $$item{id} } = $item;
    }

    return \%items;

}

### Subroutine : get_return_item_info           ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_return_item_info :Export(:DEFAULT) {

    my ( $dbh, $return_id, $no_canceled ) = @_;

    $no_canceled = $no_canceled
                 ? "AND ri.return_item_status_id != $RETURN_ITEM_STATUS__CANCELLED"
                 : '';

    my $qry
        =qq{SELECT    ri.*,
                      ris.status,
                      cit.description as reason,
                      rt.type,
                      to_char(risl.date, 'DD-MM-YYYY  HH24:MI') as date_received,
                      v.product_id,
                      v.size_id,
                      v.designer_size_id,
                      v.legacy_sku,
                      sku_padding(v.size_id) as sku_size,
                      v.product_id || '-' || sku_padding(v.size_id) as sku,
                      pst.name as storage_type
            FROM      return_item ri
            LEFT JOIN return_item_status_log risl ON ri.id = risl.return_item_id
            AND       risl.return_item_status_id = 2,
                      return_item_status ris,
                      customer_issue_type cit,
                      return_type rt,
                      shipment_item si,
                      variant v,
                      product p
            LEFT JOIN product.storage_type pst ON pst.id = p.storage_type_id
            WHERE     ri.return_id = ?
            AND       ri.return_item_status_id = ris.id
            AND       ri.customer_issue_type_id = cit.id
            AND       ri.return_type_id = rt.id
            AND       ri.shipment_item_id = si.id
            AND       si.variant_id = v.id
            AND       v.product_id = p.id
            $no_canceled
    };

    my $sth = $dbh->prepare($qry);
    $sth->execute($return_id);

    my %items;

    while ( my $item = $sth->fetchrow_hashref() ) {
        $items{ $$item{id} } = $item;
    }

    return \%items;

}

### Subroutine : get_return_items_log           ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_return_items_log :Export(:DEFAULT) {

    my ( $dbh, $return_id ) = @_;

    my $qry
        = "SELECT risl.id, risl.return_item_id, ris.status, o.name, to_char(risl.date, 'DD-MM-YYYY  HH24:MI') as date FROM return_item ri, return_item_status_log risl, return_item_status ris, operator o WHERE ri.return_id = ? AND ri.id = risl.return_item_id AND risl.return_item_status_id = ris.id AND risl.operator_id = o.id";

    my $sth = $dbh->prepare($qry);
    $sth->execute($return_id);

    my %items;

    while ( my $item = $sth->fetchrow_hashref() ) {
        $items{ $$item{id} } = $item;
    }

    return \%items;

}

### Subroutine : get_return_arrivals           ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_return_arrivals :Export(:DEFAULT) {

    my ( $dbh, $awb ) = @_;

    my $qry = "SELECT ra.id, ra.return_airway_bill, to_char(ra.date, 'DD-MM-YYYY  HH24:MI') as date_arrived, op.name as operator
                FROM return_arrival ra, operator op
                WHERE ra.return_airway_bill = ?
                AND ra.operator_id = op.id";

    my $sth = $dbh->prepare($qry);
    $sth->execute($awb);

    my %data;

    while ( my $row = $sth->fetchrow_hashref() ) {
        $data{ $row->{id} } = $row;
    }

    return \%data;

}

### Subroutine : get_return_reason              ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_return_reason :Export(:DEFAULT) {

    my ( $dbh, $issue_id ) = @_;

    my $qry = "SELECT description FROM customer_issue_type WHERE id = ?";

    my $sth = $dbh->prepare($qry);
    $sth->execute($issue_id);

    my $reason = $sth->fetchrow_hashref();

    return $$reason{description};

}

### Subroutine : get_return_invoice             ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_return_invoice :Export(:DEFAULT) {

    my ( $dbh, $return_id ) = @_;

    my %renum = ();

    my $qry
        = "SELECT r.id, r.invoice_nr, r.renumeration_type_id, r.renumeration_class_id, r.renumeration_status_id, r.shipping, r.misc_refund, rt.type, rc.class, rs.status, ri.unit_price, ri.tax, ri.duty
                FROM link_return_renumeration lrr, renumeration r LEFT JOIN renumeration_item ri ON r.id = ri.renumeration_id, renumeration_type rt, renumeration_class rc, renumeration_status rs
                WHERE lrr.return_id = ?
                AND lrr.renumeration_id = r.id
                AND r.renumeration_type_id = rt.id
                AND r.renumeration_class_id = rc.id
                AND r.renumeration_status_id = rs.id";

    my $sth = $dbh->prepare($qry);
    $sth->execute($return_id);

    while ( my $row = $sth->fetchrow_arrayref() ) {

        if ( $renum{ $row->[0] } ) {
            $renum{ $row->[0] }{total}
                += $row->[10] + $row->[11] + $row->[12];
        }
        else {

            $renum{ $row->[0] }{invoice_nr}             = $row->[1];
            $renum{ $row->[0] }{renumeration_type_id}   = $row->[2];
            $renum{ $row->[0] }{renumeration_class_id}  = $row->[3];
            $renum{ $row->[0] }{renumeration_status_id} = $row->[4];
            $renum{ $row->[0] }{shipping}               = $row->[5];
            $renum{ $row->[0] }{misc_refund}            = $row->[6];
            $renum{ $row->[0] }{type}                   = $row->[7];
            $renum{ $row->[0] }{class}                  = $row->[8];
            $renum{ $row->[0] }{status}                 = $row->[9];

            $renum{ $row->[0] }{total}
                = $row->[5] + $row->[6] + $row->[10] + $row->[11]
                + $row->[12];

        }

    }

    return \%renum;

}

### Subroutine : update_return_status           ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub update_return_status :Export(:DEFAULT) {

    my ( $dbh, $id, $status ) = @_;

    my $qry = "UPDATE return SET return_status_id = ? WHERE id = ?";

    my $sth = $dbh->prepare($qry);

    $sth->execute( $status, $id );

}

### Subroutine : update_return_arrival_AWB                        ###
# usage        : update_return_arrival_AWB (                        #
#                    Database Handle,                               #
#                    Airway Bill                                    #
#                 );                                                #
# description  : This searches the return_arrival table for an AWB  #
#                where the goods_in_processed field is false, then  #
#                it sets it to true for all occurences.             #
# parameters   : A Database Handle, An AWB.                         #
# returns      : Nothing.                                           #

sub update_return_arrival_AWB :Export(:DEFAULT) {

    my ( $dbh, $awb) = @_;

    my $qry = "";
    my $upd_sql = "";


    # set-up the update cursor
    $upd_sql =<<SQL
UPDATE return_arrival
SET goods_in_processed = TRUE
WHERE id = ?
SQL
        ;
    my $upd_sth = $dbh->prepare( $upd_sql );

    $qry =<<SQL
SELECT ra.id
FROM return_arrival ra
JOIN return_delivery rd ON rd.id = ra.return_delivery_id
WHERE ra.return_airway_bill ILIKE ?
AND ra.goods_in_processed = FALSE
AND ra.removed = FALSE
AND rd.confirmed = TRUE
SQL
        ;
    my $sth = $dbh->prepare( $qry );
    $sth->execute( $awb );

    foreach ( my $row = $sth->fetchrow_hashref() ) {
        # update each row
        $upd_sth->execute( $row->{id} );
    }
}

### Subroutine : update_return_exchange_id      ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub update_return_exchange_id :Export(:DEFAULT) {

    my ( $dbh, $id, $exchange_shipment_id ) = @_;

    my $qry = "UPDATE return SET exchange_shipment_id = ? WHERE id = ?";

    my $sth = $dbh->prepare($qry);

    $sth->execute( $exchange_shipment_id, $id );

}

### Subroutine : log_return_status              ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub log_return_status :Export(:DEFAULT) {

    my ( $dbh, $id, $status, $operator_id ) = @_;

    my $qry = "INSERT INTO return_status_log (id, return_id, return_status_id, operator_id, date) VALUES (default, ?, ?, ?, current_timestamp)";

    my $sth = $dbh->prepare($qry);

    $sth->execute( $id, $status, $operator_id );
}

### Subroutine : update_return_item_status      ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub update_return_item_status :Export(:DEFAULT) {

    my ( $dbh, $id, $status ) = @_;

    my $qry = "UPDATE return_item SET return_item_status_id = ? WHERE id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $status, $id );

}

### Subroutine : log_return_item_status         ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub log_return_item_status :Export(:DEFAULT) {

    my ( $dbh, $id, $status, $operator_id ) = @_;

    my $qry = "INSERT INTO return_item_status_log (id, return_item_id, return_item_status_id, operator_id, date) VALUES (default, ?, ?, ?, current_timestamp)";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $id, $status, $operator_id );

}

### Subroutine : update_return_item_received    ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub update_return_item_received :Export(:DEFAULT) {

    my ( $dbh, $id, $airwaybill, $correct_variant ) = @_;

    my $qry = "UPDATE return_item SET return_airway_bill = ? WHERE id = ?";
    my $qry2
        = "UPDATE return_item SET return_airway_bill = ?, variant_id = ? WHERE id = ?";
    my $sth;

    if ($correct_variant) {
        $sth = $dbh->prepare($qry2);
        $sth->execute( $airwaybill, $correct_variant, $id );
    }
    else {
        $sth = $dbh->prepare($qry);
        $sth->execute( $airwaybill, $id );
    }
}

### Subroutine : check_return_complete          ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub check_return_complete :Export(:DEFAULT) {

    my ( $dbh, $return_id ) = @_;

    my $qry = "SELECT return_item_status_id, return_type_id FROM return_item WHERE return_id = ?";

    my $sth = $dbh->prepare($qry);
    $sth->execute($return_id);

    my $complete = 1;
    my $exchange_complete = 1;

    while ( my $row = $sth->fetchrow_hashref() ) {
        if ($$row{return_item_status_id} < 4){
            $complete = 0;

            if ($$row{return_type_id} == 2){
                $exchange_complete = 0;
            }
        }
    }

    return $complete, $exchange_complete;

}

### Subroutine : get_return_notes               ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_return_notes :Export(:DEFAULT) {

    my ( $dbh, $return_id ) = @_;

    my $qry
        = "SELECT rn.id, to_char(rn.date, 'DD-MM-YY HH24:MI') as date, extract(epoch from rn.date) as date_sort, rn.note, rn.operator_id, nt.description, op.name, d.department
            FROM return_note rn, note_type nt, operator op LEFT JOIN department d ON op.department_id = d.id
            WHERE rn.return_id = ?
            AND rn.note_type_id = nt.id
            AND rn.operator_id = op.id";

    my $sth = $dbh->prepare($qry);
    $sth->execute($return_id);

    my %notes;

    while ( my $note = $sth->fetchrow_hashref() ) {
        $note->{$_} = decode_db( $note->{$_} ) for (qw( note ));
        $notes{ $$note{id} } = $note;
    }

    return \%notes;

}

### Subroutine : set_return_note                ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub set_return_note :Export(:DEFAULT) {

    my ( $dbh, $return_id, $note, $operator_id ) = @_;

    my $qry = "INSERT INTO return_note (id, return_id, note, note_type_id, operator_id, date) VALUES (default, ?, ?, 2, ?, current_timestamp)";

    my $sth = $dbh->prepare($qry);
    $sth->execute($return_id, $note, $operator_id);

}

### Subroutine : get_returns_pending           ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_returns_pending :Export() {

    my ($dbh, $view_type) = @_;

    # something to hold results
    my %returns = ();

    # get list of partial and defective returns
    my $partial     = get_partial_return_id($dbh);
    my $defective   = get_defective_return_id($dbh);

    my $qry;

    # list of exchanges awaiting authorisation requested
    if ($view_type eq 'Awaiting_Authorisation') {

        $qry = "SELECT
                    o.id as orders_id,
                    o.order_nr,
                    o.customer_id,
                    oa.first_name,
                    oa.last_name,
                    r.id as return_id,
                    r.rma_number,
                    age(date_trunc('day',r.creation_date)) as agereturn,
                    to_char(r.creation_date, 'DD-MM-YYYY') as datecreated,
                    r.exchange_shipment_id,
                    s.id as shipment_id,
                    ch.name as sales_channel,
                    order_cnt.count as customer_order_count
                FROM
                    return r,
                    shipment s,
                    link_orders__shipment los,
                    orders o
                JOIN (select customer_id, count(*) as count from orders group by customer_id) order_cnt
                        on (order_cnt.customer_id = o.customer_id),
                    order_address oa,
                    link_return_renumeration link,
                    renumeration ren,
                    channel ch
                WHERE
                    r.id = link.return_id
                AND link.renumeration_id = ren.id
                AND ren.renumeration_status_id = $RENUMERATION_STATUS__AWAITING_AUTHORISATION
                AND r.shipment_id = s.id
                AND s.id = los.shipment_id
                AND los.orders_id = o.id
                AND s.shipment_address_id = oa.id
                AND o.channel_id = ch.id";

    } else {

        # basic query to get list of returns
        $qry = "SELECT
                    o.id as orders_id,
                    o.order_nr,
                    o.customer_id,
                    oa.first_name,
                    oa.last_name,
                    r.id as return_id,
                    r.rma_number,
                    age(date_trunc('day',r.creation_date)) as agereturn,
                    to_char(r.creation_date, 'DD-MM-YYYY') as datecreated,
                    r.exchange_shipment_id,
                    s.id as shipment_id,
                    ch.name as sales_channel,
                    order_cnt.count as customer_order_count
                FROM
                    return r,
                    shipment s,
                    link_orders__shipment los,
                    orders o
                JOIN (select customer_id, count(*) as count from orders group by customer_id) order_cnt
                        on (order_cnt.customer_id = o.customer_id),
                    order_address oa,
                    channel ch
                WHERE
                    r.id IN (select distinct(return_id) from return_item where return_item_status_id = $RETURN_ITEM_STATUS__AWAITING_RETURN)
                AND r.shipment_id = s.id
                AND s.id = los.shipment_id
                AND los.orders_id = o.id
                AND s.shipment_address_id = oa.id
                AND o.channel_id = ch.id";

        # extra query for Late and Severely Late returns
        if ($view_type eq "Late" || $view_type eq "Severely_Late"){

            # exclude premier shipments
            $qry .= " AND s.shipment_type_id != $SHIPMENT_TYPE__PREMIER";

            # late returns fall between 14 and 20 days old
            if ($view_type eq "Late"){
                $qry .= " AND r.creation_date between (now() - interval '14 days') and (now() - interval '20 days')";
            }
            # severley late are older than 21 days
            elsif ($view_type eq "Severely_Late"){
                $qry .= " AND r.creation_date < (now() - interval '21 days')";
            }
        }

        # view restricted to Premier orders only
        if ($view_type eq "Premier"){
            $qry .= " AND s.shipment_type_id = $SHIPMENT_TYPE__PREMIER";
        }
    }

    my $sth = $dbh->prepare($qry);
    $sth->execute();

    while ( my $row = $sth->fetchrow_hashref() ) {
        $row->{$_} = decode_db( $row->{$_} ) for (qw(
            first_name
            last_name
        ));

        my $ordering    = $row->{return_id};
        my $channel     = $row->{sales_channel};
        my $type        = '';
        my $include     = 0;

        my $num_orders = $row->{customer_order_count};

        if ($row->{exchange_shipment_id}){
            $type = 'exchanges';
        }
        else {
            $type = 'returns';
        }

        if ($view_type eq "Partial"){
            if ( $partial->{ $row->{return_id} } ) {
                $include = 1;
            }
        }
        elsif ($view_type eq "Defective"){
            if ( $defective->{ $row->{return_id} } ) {
                $include = 1;
            }
        }
        # EN-972 - they no longer want to filter out partial or defective orders for Late/Severely late
        #elsif ($view_type eq "Late" || $view_type eq "Severely_Late"){
        #    if ( !$defective->{ $row->{return_id} } && !$partial->{ $row->{return_id} } ) {
        #        $include = 1;
        #    }
        #}
        else {
            $include = 1;
        }

        if ( $include == 1 ) {
            $returns{ $channel }{ $type }{ $ordering }               = $row;
            $returns{ $channel }{ $type }{ $ordering }{num_orders}   = $num_orders;
        }

    }

    return \%returns;

}

### Subroutine : get_partial_return_id         ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_partial_return_id :Export() {

    my ($dbh) = @_;

    my %list = ();

    my $qry = "SELECT id FROM return WHERE id IN (select return_id from return_item where return_item_status_id = 1) AND id IN (select return_id from return_item where return_item_status_id > 1 and return_item_status_id < 9)";
    my $sth = $dbh->prepare($qry);
    $sth->execute();

    while ( my $row = $sth->fetchrow_hashref() ) {
        $list{ $$row{id} } = 1;
    }

    return \%list;
}

### Subroutine : get_defective_return_id       ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_defective_return_id :Export() {

    my ($dbh) = @_;

    my %list = ();

    my $qry = "SELECT id FROM return WHERE id IN (select return_id from return_item where return_item_status_id < 4 AND customer_issue_type_id = 10)";
    my $sth = $dbh->prepare($qry);
    $sth->execute();

    while ( my $row = $sth->fetchrow_hashref() ) {
        $list{ $$row{id} } = 1;
    }

    return \%list;
}


### Subroutine : get_returns_arrived           ###
# usage        : get_returns_arrived($dbh)                                #
# description  : lists all returns scanned at arrivals which aren't booked in #
# parameters   : db handle                                #
# returns      : hash                                #

sub get_returns_arrived :Export() {

    my ( $dbh ) = @_;

    my $qry = "SELECT ra.id, ra.return_airway_bill, to_char(ra.date, 'DD-MM-YYYY HH24:MI') as date, o.id AS orders_id, o.order_nr
                FROM return_arrival ra LEFT JOIN return_item ri ON ra.return_airway_bill = ri.return_airway_bill, return_delivery rd, shipment s, link_orders__shipment los, orders o
                WHERE ra.return_delivery_id = rd.id
                AND rd.confirmed is true
                AND ra.return_airway_bill = s.return_airway_bill
                AND s.id = los.shipment_id
                AND los.orders_id = o.id
                AND ri.id IS null";
    my $sth = $dbh->prepare($qry);
    $sth->execute();

    my %data;

    while ( my $row = $sth->fetchrow_hashref() ) {
        $data{ $row->{id} } = $row;
    }

    return \%data;

}


### Subroutine : release_return_refunds                                                       ###
# usage        : release_return_refunds($schema, $return_id)                                    #
# description  : checks if refunds/debits against a return require status updates               #
# parameters   : schema, return id                                                              #
# returns      :                                                                                #

sub release_return_invoice :Export() {

    my ( $schema, $return_id ) = @_;

    if (!$return_id) {
        die "No return id defined";
    }

    my $dbh = $schema->storage->dbh;

    # get status of all items in return
    my %return_items = ();
    my $qry = "SELECT shipment_item_id, return_item_status_id FROM return_item WHERE return_id = ? AND return_item_status_id != $RETURN_ITEM_STATUS__CANCELLED";
    my $sth = $dbh->prepare($qry);
    $sth->execute($return_id);

    while ( my $row = $sth->fetchrow_hashref() ) {
        $return_items{ $row->{shipment_item_id} } = $row->{return_item_status_id};
    }

    # get all refunds/debits against the return
    # loop over each one and get items and check for status updates
    $qry = "SELECT r.id
                FROM renumeration r, link_return_renumeration lrr
                WHERE lrr.return_id = ?
                AND lrr.renumeration_id = r.id
                AND r.renumeration_status_id = $RENUMERATION_STATUS__PENDING";
    $sth = $dbh->prepare($qry);
    $sth->execute($return_id);

    # store the invoice Id's that can be released
    my @release_invoices;

    while ( my $row = $sth->fetchrow_hashref() ) {

        my $invoice_id  = $row->{id};
        my $release     = 1;

        # get items in refund/debit
        my $invoice_items = get_invoice_item_info($dbh, $invoice_id);


        # loop over items and check return item status for each
        foreach my $item ( keys %{$invoice_items} ) {

            my $ship_item_id = $invoice_items->{$item}{shipment_item_id};
            my $ris = $return_items{ $ship_item_id };
            # item has not passed QC
            if ( !$ris
                || $ris == $RETURN_ITEM_STATUS__AWAITING_RETURN
                || $ris == $RETURN_ITEM_STATUS__BOOKED_IN
                || $ris == $RETURN_ITEM_STATUS__FAILED_QC__DASH__AWAITING_DECISION) {
                $release = 0;
            }
        }

        # Flag for Release of invoice if required.
        if ( $release == 1 ) {
            push @release_invoices, $invoice_id;
        }

    }

    return @release_invoices;

}

=head2 release_return_invoice_to_customer

    release_return_invoice_to_customer( $schema, $message_factory, $return_id, $operator_id, {
                                                                                        # this is optional
                                                                                        no_auto_refund => 1
                                                                                    });

This is a wrapper that calls 'release_return_invoice' followed by 'auto_refund_to_customer' or updates
the renumeration status to 'Awaiting Action' depending on whether 'no_auto_refund' has been passed used to
seperate the decision to release an invoice from actually releasing it.

=cut

sub release_return_invoice_to_customer :Export() {
    my ( $schema, $message_factory, $return_id, $operator_id, $args )  = @_;

    my @invoice_ids    = release_return_invoice( $schema, $return_id );

    foreach my $invoice_id ( @invoice_ids ) {
        my $renumeration    = $schema->resultset('Public::Renumeration')->find( $invoice_id );
        if ( $args->{no_auto_refund} ) {
            $renumeration->update_status( $RENUMERATION_STATUS__AWAITING_ACTION, $operator_id );
        }
        else {
            auto_refund_to_customer( $schema, $message_factory, $renumeration, $operator_id );
        }
    }

    return @invoice_ids;
}

=head2 auto_refund_to_customer

    auto_refund_to_customer( $schema, $message_factory, $renumeration,  { # this is optional
                                                                            no_reset_psp_update => 1,
                                                                        } );

This will automatically give the money back to the customer either by through the PSP or as Store Credit
depending on the Type of Renumeration. If it fails to do this it will set the Status of the Renumeration
to 'AWAITING_AUTHORISATION' so it shows up in the 'Active Invoices' page to be done manually.

=cut

sub auto_refund_to_customer :Export() {
    my ( $schema, $message_factory, $renumeration, $operator_id, $args ) = @_;

    eval {

       $renumeration->refund_to_customer( { refund_and_complete => 1, message_factory => $message_factory, ( $args ? %{ $args } : () ) } );

    };

    if ( my $error = $@ ) {

        # Add order note advising of error.
        $renumeration->shipment->link_orders__shipment->order->create_related( 'order_notes', {
            note            => $error,
            note_type_id    => $NOTE_TYPE__RETURNS,
            operator_id     => $APPLICATION_OPERATOR_ID,
            date            => DateTime->now( time_zone => 'local' ),
        } );

        $renumeration->update_status( $RENUMERATION_STATUS__AWAITING_ACTION, $operator_id );
    }

    return;
}

### Subroutine : get_return_item_by_sku           ###
# usage        : get_return_item_by_sku($dbh, $return_id, $sku, $exclude_id)     #
# description  : gets info for a given SKU in a return                           #
#                to handle multiples of the same SKU you can pass in another item id to exlcude #
# parameters   : db handle, return id, sku, exclude item id                              #
# returns      : variant_id, return_item_id, wrong_sent_item variant                     #

sub get_return_item_by_sku :Export() {

    my ( $dbh, $return_id, $sku, $exclude_id ) = @_;

    my $variant_id      = 0;
    my $return_item_id  = 0;
    my $wrong_sent_item = 0;

    $variant_id = get_variant_by_sku($dbh, $sku);

    my $qry = "select ri.id, cit.description, cit.id
                from return_item ri, customer_issue_type cit
                where ri.return_id = ?
                and ri.variant_id = ?
                and ri.return_item_status_id = 1
                and ri.customer_issue_type_id = cit.id";

    if ($exclude_id) {
        $qry .= " and ri.id != $exclude_id";
    }

    my $sth = $dbh->prepare( $qry );
    $sth->execute( $return_id, $variant_id );

    while ( my $rows = $sth->fetchrow_arrayref ) {
        $return_item_id = $rows->[0];

        # it was 'Wrong Sent Item' but now 'Incorrect Item' but by id
        if ($rows->[2] == $CUSTOMER_ISSUE_TYPE__7__INCORRECT_ITEM) {
            $wrong_sent_item = $variant_id;
        }
    }

    return $variant_id, $return_item_id, $wrong_sent_item;
}


sub calculate_refund_charge_per_item :Export(:DEFAULT) {
    my($schema,$item,$shipment_item,$shipment_address,
        $charge_duty,$charge_tax) = @_;

    if ( !defined $schema || ref( $schema ) !~ /::Schema/ ) {
        croak "Non Schema Object passed into 'calculate_refund_charge_per_item' function";
    }

    my $dbh = $schema->storage->dbh;
    # get the Shipment Country
    my $ship_country    = get_dbic_country( $schema, $shipment_address->{country} );

    my $got_refund = 0;
    my $num_exchange_items = undef;
    # item selected for straight Return
    if ( $item->{type} eq 'Return' || $item->{type} =~ /^[0-9]+$/ && $item->{type} == $RETURN_TYPE__RETURN) {
        # get unit price to be refunded from shipment data

        # Hey look - ash was here:
        # HACK HACK BODGE: Sometimes shipment_item is a DBIC row, sometimes
        # its just a hash
        $item->{unit_price} = blessed($shipment_item )
                            ? $shipment_item->unit_price
                            : $shipment_item->{unit_price};

        # refund tax and duty for certain "reasons" for return
        if ( (defined $item->{reason_id} and ($item->{reason_id} == $CUSTOMER_ISSUE_TYPE__7__INCORRECT_ITEM
            || $item->{reason_id} == $CUSTOMER_ISSUE_TYPE__7__DEFECTIVE_FSLASH_FAULTY ))
            || ( defined $item->{full_refund} and $item->{full_refund} == 1)) {
            # check if we have an object or just a hash ref
            if (blessed($shipment_item)) {
                $item->{tax} = $shipment_item->tax;
                $item->{duty} = $shipment_item->duty;
            } else {
                $item->{tax} = $shipment_item->{tax};
                $item->{duty} = $shipment_item->{duty};
            }
        }
        else {
            # assume we don't refund any tax or duties
            $item->{tax}  = "0.00";
            $item->{duty} = "0.00";

            # based on the Shipping Country check to see if we can refund Tax &/or Duties

            if ( $ship_country->can_refund_for_return( $REFUND_CHARGE_TYPE__TAX ) ) {
                # check if we have an object or just a hash ref
                if (blessed($shipment_item)) {
                    $item->{tax} = $shipment_item->tax;
                } else {
                    $item->{tax} = $shipment_item->{tax};
                }
            }
            if ( $ship_country->can_refund_for_return( $REFUND_CHARGE_TYPE__DUTY ) ) {
                # check if we have an object or just a hash ref
                if (blessed($shipment_item)) {
                    $item->{duty} = $shipment_item->duty;
                } else {
                    $item->{duty} = $shipment_item->{duty};
                }
            }
        }

        $got_refund = 1;
    }
    # item selected for Exchange
    elsif ( $item->{type} eq 'Exchange' || $item->{type} == $RETURN_TYPE__EXCHANGE) {
        # incerement the total number of exchange items
        $num_exchange_items++;

        # split out exchange variant and size if set
        ($item->{exchange_variant_id}, $item->{exchange_size}) = split /-/, $item->{exchange}
            if defined $item->{exchange};

        # set refund for unit price to 0
        $item->{unit_price} = '0.00';

        # don't charge extra tax and duty for countries who have tax refunded OR for faulty items
        if ( defined $item->{reason_id} and ($item->{reason_id} == $CUSTOMER_ISSUE_TYPE__7__INCORRECT_ITEM
            || $item->{reason_id} == $CUSTOMER_ISSUE_TYPE__7__DEFECTIVE_FSLASH_FAULTY ) ) {
            $item->{tax}    = '0.00';
            $item->{duty}   = '0.00';
        }
        else {
            my $tax  = blessed($shipment_item) ? $shipment_item->tax : $shipment_item->{tax};
            my $duty = blessed($shipment_item) ? $shipment_item->duty : $shipment_item->{duty};

            # check based on Shipping Country as to whether Tax &/or Duties should NOT be Charged
            if ( $ship_country->no_charge_for_exchange( $REFUND_CHARGE_TYPE__TAX ) ) {
                $tax    = 0;
            }
            if ( $ship_country->no_charge_for_exchange( $REFUND_CHARGE_TYPE__DUTY ) ) {
                $duty   = 0;
            }

            if ( $tax == 0) {
                $item->{tax}    = '0.00';
            }
            else {
                $item->{tax} = (-1 * $tax);
            }
            $charge_tax += $tax;

            if ( $duty == 0) {
                $item->{duty}    = '0.00';
            }
            else {
                $item->{duty} = (-1 * $duty);
            }
            $charge_duty += $duty;
        }
    }
    else {
        die "unknown return type $item->{type}";
    }

    return ($got_refund,$charge_duty,$charge_tax,$num_exchange_items);
}

=head2 calculate_returns_charge

…sorry for the confusion, we don’t currently refund shipping on NAP so we
should continue as we do now to reduce any confusion – there is a discussion to
be had around whether we should but let’s keep that separate.

Details of the rules from Confluence…

Outnet Shipping Refund Rules

    * Only exchange items in RMA : No shipping refunds or charges
    * 1 or more standard returns in RMA :
          o DC1
                + If one or more items selected as 'Defective/faulty' : refund
                  original shipping cost
                + Otherwise: refund original shipping cost AND charge returns
                  shipping
          o DC2
                + If one or more items selected as 'Defective/faulty' : refund
                  original shipping cost
                + Otherwise: charge returns shipping (no refund of original
                  shipping cost)

=cut

sub calculate_returns_charge :Export(:DEFAULT) {
    my ($args) = @_;
    my $shipment_row = $args->{shipment_row}
        or croak('Missing $args->{shipment_row}');

    # (atm, all returns are free, except for non-Premier Outnet)
    if($shipment_row->shipping_charge_table->is_return_shipment_free) {
        return (0, 0);
    }

    # Only exchange items in RMA : No shipping refunds or charges
    if (     $args->{num_exchange_items}
          && $args->{num_exchange_items} == $args->{num_return_items} ) {
        return (0, 0);
    }

    # 1 or more non-exchange items
    my ($shipping_refund, $shipping_charge) = (0, 0);

    my $instance = config_var('XTracker', 'instance')
        or die 'No instance defined in config';
    if ($args->{got_faulty_items}) {
        # If one or more items selected as 'Defective/faulty' : refund original shipping cost
        $shipping_refund = $shipment_row->shipping_charge;
        $shipping_charge = 0;
    }
    else {
        # Otherwise: do we refund original shipping cost based
        if ($shipment_row->get_business->does_refund_shipping()) {
            $shipping_refund = $shipment_row->shipping_charge;
        }

        # And then charge returns shipping
        my $return_charge_obj = $shipment_row->get_return_charge();
        $shipping_charge = ($return_charge_obj ? $return_charge_obj->charge() : 0);
    }

    # don't refund shipping costs if previously refunded
    my $previous_shipping_refund
        = $shipment_row->renumerations->previous_shipping_refund
            // Carp::confess("previous_shipping_refund missing!");
    if ($previous_shipping_refund) {
        $shipping_refund = 0;
    }

    # convert charge to negative value before adding to refund
    $shipping_charge *= -1;

    return ($shipping_refund, $shipping_charge);
}

1;
