package XTracker::Database::Logging;

use strict;
use warnings;
use Carp qw(croak cluck);
# use Data::Dumper;

use Perl6::Export::Attrs;
use XTracker::Constants::FromDB     qw(:flow_status :shipment_item_status :pws_action);
use XTracker::Database;
use XTracker::Database::Shipment    qw( get_shipment_info );
use XTracker::Database::Stock;
use XTracker::Database::Utilities;
use XTracker::EmailFunctions qw( send_email );
use XTracker::Config::Local qw( config_var );
use XTracker::Database::Product qw( product_present );
### Subroutine : log_delivery                   ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub log_delivery :Export() {

    my ( $dbh, $arg_ref ) = @_;

    my $delivery_id = $arg_ref->{delivery_id};
    my $type_id     = $arg_ref->{type_id};
    my $action      = $arg_ref->{action};
    my $quantity    = $arg_ref->{quantity};
    my $operator_id = $arg_ref->{operator};
    my $notes       = $arg_ref->{notes};

    croak unless $delivery_id;
    croak unless $action;

    my $qry = "insert into log_delivery
                   ( delivery_id, delivery_action_id, operator_id,
                     quantity, notes, type_id )
               values( ?, ?, ?, ?, ?, ? )";

    my $sth = $dbh->prepare( $qry );
    $sth->execute( $delivery_id, $action, $operator_id, $quantity, $notes,
                   $type_id );

    return;
}


### Subroutine : log_stock                      ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub log_stock :Export(){

    my ( $dbh, $arg_ref ) = @_;

    my $variant_id  = $arg_ref->{variant_id} || 0;
    my $channel_id  = $arg_ref->{channel_id};
    my $action      = $arg_ref->{action}     || 0;
    my $quantity    = $arg_ref->{quantity};
    my $operator_id = $arg_ref->{operator_id};
    my $notes       = $arg_ref->{notes};

    croak "invalid variant_id '$variant_id'" unless $variant_id;
    croak "invalid action '$action'" unless $action;

    # calculate stock balance for log entry
    my $qry = "select sum( quantity ) from
               (
                    select sum( quantity ) as quantity
                    from quantity
                    where variant_id = ?
                        and channel_id = ?
                        and status_id = $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS
                union all
                    select count(si.*) from shipment_item si, link_orders__shipment los, orders o
                    where si.variant_id = ?
                        and si.shipment_item_status_id in ($SHIPMENT_ITEM_STATUS__PICKED, $SHIPMENT_ITEM_STATUS__CANCEL_PENDING)
                        and si.shipment_id = los.shipment_id
                        and los.orders_id = o.id
                        and o.channel_id = ?
                union all
                    select count(si.*) from shipment_item si, link_stock_transfer__shipment link, stock_transfer st
                    where si.variant_id = ?
                        and si.shipment_item_status_id in ($SHIPMENT_ITEM_STATUS__PICKED, $SHIPMENT_ITEM_STATUS__CANCEL_PENDING)
                        and si.shipment_id = link.shipment_id
                        and link.stock_transfer_id = st.id
                        and st.channel_id = ?
                union all
                    select sum( quantity ) as quantity
                    from quantity
                    where variant_id = ?
                        and channel_id = ?
                        and status_id in (
                            $FLOW_STATUS__IN_TRANSIT_FROM_IWS__STOCK_STATUS,
                            $FLOW_STATUS__IN_TRANSIT_FROM_PRL__STOCK_STATUS
                        )
               ) as total
    ";

    my $sth = $dbh->prepare($qry);
    $sth->execute( ($variant_id, $channel_id ) x 4 );

    my $current_stock = 0;
    $sth->bind_columns( \$current_stock );
    $sth->fetch();

    $qry = "insert into log_stock
                   ( variant_id, stock_action_id, operator_id, quantity,
                   balance, notes, channel_id )
               values( ?, ?, ?, ?, ? ,?, ? )";

    $sth = $dbh->prepare( $qry );
    $sth->execute( $variant_id, $action, $operator_id, $quantity, $current_stock, $notes, $channel_id );

    return;
}

### Subroutine : log_location                   ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub log_location :Export() {

    my ( $dbh, $arg_ref ) = @_;

    my $variant_id  = $arg_ref->{variant_id}  || 0;
    my $location    = $arg_ref->{location}  || 0;
    my $location_id = $arg_ref->{location_id} || 0;
    my $operator_id = $arg_ref->{operator_id};
    my $channel_id  = $arg_ref->{channel_id};

    if ( $arg_ref->{old_loc} ) {
        $location = $arg_ref->{old_loc};
    }

    my %clause = ( 'location_id' => ' ?',
                   'location'    => ' ( select id from location where location = ?)',
                 );

    my $type    = 'location';
    my $qrydata = $location;

    if( $location_id ){
        $type    = 'location_id';
        $qrydata = $location_id;
    }


    my $qry = "insert into log_location
                   ( variant_id, location_id, operator_id, channel_id )
               values( ?, $clause{$type}, ?, ? )";

    my $sth = $dbh->prepare( $qry );
    $sth->execute( $variant_id, $qrydata, $operator_id, $channel_id );

    return;
}


### Subroutine : get_delivery_log               ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_delivery_log :Export() {

    my ( $dbh, $product_id ) = @_;

    my $qry = "select ld.delivery_id,
                      to_char(ld.date, 'YYYY-MM-DD') as date,
                      to_char(ld.date, 'HH24:MI') as time,
                      sa.action, o.name as operator, ld.quantity,
                      spt.type,
                      coalesce( notes, 'none') as notes,
                      c.name as sales_channel
               from log_delivery ld, delivery_action sa, operator o,
                    stock_process_type spt, link_delivery__stock_order ldso, stock_order so, purchase_order po, channel c
               where ld.delivery_action_id = sa.id
               and ld.operator_id = o.id
               and ld.type_id = spt.id
               and ld.delivery_id = ldso.delivery_id
               and ldso.stock_order_id = so.id
               and so.purchase_order_id = po.id
               and po.channel_id = c.id
               and ld.delivery_id in
                    ( select delivery_id from link_delivery__stock_order where stock_order_id in
                        ( select id from stock_order where product_id = ?))
               order by ld.delivery_id, ld.date";

    my $sth = $dbh->prepare( $qry );
    $sth->execute( $product_id );

    return results_channel_list($sth);
}


### Subroutine : get_stock_log                  ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_stock_log :Export() {

    my ( $dbh, $args_ref ) = @_;

    my $type = $args_ref->{type};
    my $id   = $args_ref->{id  };

    my %qry_id = ( 'variant_id' => ' and ls.variant_id = ? ',
                   'product_id' => ' and ls.variant_id in
                                        ( select id from super_variant where product_id = ?) ',
                 );


    my $qry = "select ls.variant_id, sku_padding(v.size_id) as size_id,
                      to_char(ls.date, 'DD-MM-YYYY') as date,
                      to_char(ls.date, 'HH24:MI') as time,
                      sa.action, o.name as operator, ls.quantity, ls.balance,
                      coalesce( notes, 'none') as notes, los.orders_id, c.name as sales_channel
               from log_stock ls left join link_orders__shipment los on ls.notes = los.shipment_id::text, stock_action sa, operator o, super_variant v, channel c
               where ls.stock_action_id = sa.id
               and ls.variant_id = v.id
               and ls.operator_id = o.id
               and ls.channel_id = c.id
               $qry_id{$type}
               order by ls.id,ls.date";

    my $sth = $dbh->prepare( $qry );
    $sth->execute( $id );

    return results_channel_list($sth);
}

### Subroutine : check_variance_transaction                ###
# usage        : check_variance_transaction(                 #
#                  $database_handle,                         #
#                  $variant_id,                              #
#                  $variance)                                #
# description  : Checks to see if a record has been created  #
#                in the log_stock record with a matching     #
#                variant id and variance                     #
# parameters   : DB Handle, Variant Id & Variance            #
# returns      : ZERO meaning no match ONE meaning a match   #

sub check_variance_transaction :Export() {

    my ( $dbh, $var_id, $variance ) = @_;

    my $duplicate = 0;
    my $qry = "SELECT * FROM log_stock WHERE variant_id = ? AND quantity = ? AND stock_action_id = 12 AND date > current_timestamp - interval '2 hours'";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $var_id, $variance );

    while ( my $row = $sth->fetchrow_arrayref() ) {
        $duplicate = 1;
    }

    return $duplicate;
}

### Subroutine : get_pws_log                    ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_pws_log :Export() {

    my ( $dbh, $args_ref ) = @_;

    my $type = $args_ref->{type};
    my $id   = $args_ref->{id  };

    my %qry_id = ( 'variant_id' => ' and ls.variant_id = ? ',
                   'product_id' => ' and ls.variant_id in
                                        ( select id from super_variant where product_id = ?) ',
                 );


    my $qry = "select ls.variant_id, sku_padding(v.size_id) as size_id,
                      to_char(ls.date, 'DD-MM-YYYY') as date,
                      to_char(ls.date, 'HH24:MI') as time,
                      pwsa.action, o.name as operator, ls.quantity, ls.balance,
                      coalesce( notes, 'none') as notes,
                      c.name as sales_channel
               from log_pws_stock ls, pws_action pwsa, operator o, super_variant v, channel c
               where ls.pws_action_id = pwsa.id
               and ls.variant_id = v.id
               and ls.operator_id = o.id
               and ls.channel_id = c.id
               $qry_id{$type}
               order by ls.date";

    my $sth = $dbh->prepare( $qry );
    $sth->execute( $id );

    return results_channel_list($sth);
}

### Subroutine : get_cancellation_log           ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_cancellation_log :Export() {

    my ( $dbh, $args_ref ) = @_;

    my $type = $args_ref->{type};
    my $id   = $args_ref->{id  };

    my %qry_id = ( 'variant_id' => ' and v.id = ? ',
                   'product_id' => ' and v.id in
                                        ( select id from super_variant where product_id = ?) ',
                 );


    # Tried to dbic-ify this but the data doesn't render properly in the
    # channelised template tabs unless you have selected sales_channel in the
    # results, which makes it difficult as we want to do left joins to collect
    # both data for customer and sample shipments:(
    my $qry = <<EOQ
SELECT v.id,
       v.product_id || '-' || sku_padding(v.size_id) AS sku,
       sis.status,
       TO_CHAR(sisl.date, 'DD-MM-YYYY HH24:MI') AS date,
       si.shipment_id,
       los.orders_id,
       COALESCE (c.first_name || ' ' || c.last_name, 'Sample') AS customer_name,
       op.name AS operator,
       COALESCE (ch.name,ch2.name) AS sales_channel
FROM shipment_item_status_log sisl
JOIN shipment_item_status sis ON sis.id = sisl.shipment_item_status_id
JOIN operator op ON sisl.operator_id = op.id
JOIN shipment_item si ON sisl.shipment_item_id = si.id
JOIN cancelled_item ci ON si.id = ci.shipment_item_id
JOIN shipment s ON si.shipment_id = s.id

-- We join on super_variant to include regular products and vouchers
JOIN super_variant v ON si.variant_id = v.id

-- Get our data for customer orders
LEFT JOIN link_orders__shipment los ON los.shipment_id = s.id
LEFT JOIN orders o ON los.orders_id = o.id
LEFT JOIN customer c ON o.customer_id = c.id
LEFT JOIN channel ch ON o.channel_id = ch.id

-- Get our data for sample orders
LEFT JOIN link_stock_transfer__shipment lsts ON lsts.shipment_id = s.id
LEFT JOIN stock_transfer st ON lsts.stock_transfer_id = st.id
LEFT JOIN channel ch2 ON st.channel_id = ch2.id

WHERE (si.variant_id = v.id OR si.voucher_variant_id = v.id)
AND sisl.shipment_item_status_id in ($SHIPMENT_ITEM_STATUS__CANCEL_PENDING,$SHIPMENT_ITEM_STATUS__CANCELLED)
$qry_id{$type}
EOQ
;

    my $sth = $dbh->prepare( $qry );
    $sth->execute( $id );

    return results_channel_list($sth);
}

### Subroutine : get_location_log               ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_location_log :Export() {

    my ( $dbh, $args_ref ) = @_;

    my $type = $args_ref->{type};
    my $id   = $args_ref->{id  };
    my $logtype   = $args_ref->{logtype};

    my %qry_id = ( 'variant_id' => 'll.variant_id = ? ',
                   'product_id' => 'll.variant_id in
                                        ( select id from super_variant where product_id = ?) ',
                 );

    my $qry
        = qq|SELECT ll.variant_id, sku_padding(v.size_id) as size_id, v.legacy_sku,
                to_char(ll.date, 'DD-MM-YYYY') as date, to_char(ll.date, 'HH24:MI') as time,
                l.location, o.name as operator, c.name AS sales_channel
            FROM log_location ll INNER JOIN super_variant v
                ON ll.variant_id = v.id INNER JOIN location l
                ON ll.location_id = l.id LEFT JOIN operator o
                ON ll.operator_id = o.id,
                channel c
            WHERE $qry_id{$type}
            AND ll.channel_id = c.id
            ORDER BY ll.date
    |;

    ### old log table
    if ($logtype && $logtype eq "old"){

        $qry
        = qq|SELECT ll.variant_id, sku_padding(v.size_id) as size_id, v.legacy_sku,
                to_char(ll.date, 'DD-MM-YYYY') as date, to_char(ll.date, 'HH24:MI') as time,
                l.location, o.name as operator, c.name AS sales_channel
            FROM old_log_location ll INNER JOIN variant v
                ON ll.variant_id = v.id INNER JOIN old_location l
                ON ll.location_id = l.id LEFT JOIN operator o
                ON ll.operator_id = o.id,
                channel c
            WHERE $qry_id{$type}
            AND ll.channel_id = c.id
            ORDER BY ll.date
    |;

    }

    my $sth = $dbh->prepare( $qry );
    $sth->execute( $id );

    return results_channel_list($sth);
}



### Subroutine : get_rtv_stock_total
# usage        : my $rtv_stock_total_ref = get_rtv_stock_total( { dbh => $dbh, variant_id => $variant_id } );
# description  : get the total stock quantity for a specified variant across RTV locations, Quarantine and Dead Stock
# parameters   :
#              :
# returns      :
sub get_rtv_stock_total :Export(:rtv) {
    my ($arg_ref)   = @_;
    my $dbh         = $arg_ref->{dbh};
    my $variant_id  = $arg_ref->{variant_id};
    my $channel_id  = $arg_ref->{channel_id};

    croak "Invalid variant_id ($variant_id)" if $variant_id !~ m{\A\d+\z}xms;

    my $qry
        = qq{SELECT v.id, v.product_id, v.size_id, coalesce(sum(q.quantity), 0) AS sum_quantity
            FROM variant v
            LEFT JOIN quantity q
                ON (v.id = q.variant_id AND q.channel_id = ?)
            WHERE v.id = ?
            AND q.status_id IN (
                $FLOW_STATUS__QUARANTINE__STOCK_STATUS,
                $FLOW_STATUS__RTV_GOODS_IN__STOCK_STATUS,
                $FLOW_STATUS__RTV_WORKSTATION__STOCK_STATUS,
                $FLOW_STATUS__RTV_PROCESS__STOCK_STATUS,
                $FLOW_STATUS__RTV_TRANSFER_PENDING__STOCK_STATUS,
                $FLOW_STATUS__DEAD_STOCK__STOCK_STATUS
            )
            GROUP BY v.id, v.product_id, v.size_id
        };

    my $sth = $dbh->prepare($qry);
    $sth->execute($channel_id, $variant_id);

    my $rtv_stock_total_ref = results_list($sth);

    return $rtv_stock_total_ref->[0];

} ## END get_rtv_stock_total



### Subroutine : log_rtv_stock
# usage        :
# description  :
# parameters   :
#              :
# returns      :
sub log_rtv_stock :Export(:rtv) {

    my ($arg_ref)       = @_;
    my $dbh             = $arg_ref->{dbh};
    my $variant_id      = defined $arg_ref->{variant_id} ? $arg_ref->{variant_id} : '';
    my $rtv_action_id   = defined $arg_ref->{rtv_action_id} ? $arg_ref->{rtv_action_id} : '';
    my $quantity        = defined $arg_ref->{quantity} ? $arg_ref->{quantity} : 0;
    my $balance         = defined $arg_ref->{balance} ? $arg_ref->{balance} : undef;
    my $operator_id     = defined $arg_ref->{operator_id} ? $arg_ref->{operator_id} : '';
    my $notes           = $arg_ref->{notes};
    my $channel_id  = $arg_ref->{channel_id};

    my $msg_croak   = '';
    $msg_croak .= "Invalid variant_id ($variant_id)\n" if $variant_id !~ m{\A\d+\z}xms;
    $msg_croak .= "Invalid rtv_action_id ($rtv_action_id)\n" if $rtv_action_id !~ m{\A\d+\z}xms;
    $msg_croak .= "Invalid operator_id ($operator_id)\n" if $operator_id !~ m{\A\d+\z}xms;
    $msg_croak .= "Invalid quantity - must be non-zero\n" if $quantity == 0;
    $msg_croak .= "No channel defined\n" if not defined $channel_id;

    croak $msg_croak if $msg_croak;

    # During quarantine, we are now logging rtv and dead stock as well.
    # The product balance is passed in the function call itself, hence no point
    # to make this db call. But we do not want to break existing code,
    # as this function is used from other places as well, hence still keeping
    # this db call
    if ( ! defined ($balance) ) {
        ## get stock balance for log entry
        my $rtv_stock_total_ref = get_rtv_stock_total( { dbh => $dbh, variant_id => $variant_id, channel_id => $channel_id } );

        $balance = $rtv_stock_total_ref->{sum_quantity};
        $balance = defined $balance ? $balance : 0;
    }

    my $sql_insert
        = q{INSERT INTO log_rtv_stock (variant_id, rtv_action_id, operator_id, notes, quantity, balance, channel_id)
                VALUES (?, ?, ?, ?, ?, ?, ?)
        };
    my $sth_insert = $dbh->prepare($sql_insert);

    $sth_insert->execute($variant_id, $rtv_action_id, $operator_id, $notes, $quantity, $balance, $channel_id);

    return;

} ## END sub log_rtv_stock


### Subroutine : get_rtv_log
# usage        :
# description  :
# parameters   :
# returns      :
sub get_rtv_log :Export(:rtv) {

    my ( $dbh, $args_ref ) = @_;

    my $type    = $args_ref->{type};
    my $id      = $args_ref->{id};

    my $msg_croak   = '';
    $msg_croak .= "Invalid type ($type)\n" if $type !~ m{\A(?:variant_id|product_id)\z}xms;
    $msg_croak .= "Invalid id ($id)\n" if $id !~ m{\A\d+\z}xms;
    croak $msg_croak if $msg_croak;

    my %qry_id = (
        variant_id  => ' ( lrs.variant_id = ? OR lrs.voucher_variant_id = ? )',
        product_id  => ' v.product_id = ?',
    );

    my $qry
        = qq{SELECT
                CASE WHEN lrs.variant_id IS NULL THEN lrs.voucher_variant_id ELSE lrs.variant_id END AS variant_id
            ,   v.product_id || '-' || sku_padding(v.size_id) as sku
            ,   to_char(lrs.date, 'DD-MM-YYYY') AS date
            ,   to_char(lrs.date, 'HH24:MI') AS time
            ,   ra.action
            ,   op.name AS operator
            ,   lrs.quantity
            ,   lrs.balance
            ,   coalesce(lrs.notes, 'none') AS notes
            ,   c.name as sales_channel
            FROM log_rtv_stock lrs
            INNER JOIN super_variant v
                ON (lrs.variant_id = v.id OR lrs.voucher_variant_id = v.id)
            INNER JOIN rtv_action ra
                ON (lrs.rtv_action_id = ra.id)
            INNER JOIN operator op
                ON (lrs.operator_id = op.id),
            channel c
            WHERE $qry_id{$type}
            AND lrs.channel_id = c.id
            ORDER BY lrs.date, lrs.id
        };

    my $sth = $dbh->prepare( $qry );
    if ( $type eq 'variant_id' ) {
        $sth->execute( $id, $id );
    }
    else {
        $sth->execute( $id );
    }

    return results_channel_list($sth);

} ## END sub get_rtv_log


### Subroutine : log_shipment_rtcb                                                       ###
# usage        : log_shipment_rtcb(                                                        #
#                      $dbh,                                                               #
#                      $shipment_id,                                                       #
#                      $new_state,                                                         #
#                      $op_id,                                                             #
#                      $reason                                                             #
#                  );                                                                      #
# description  : This should be used to log any change to the 'real_time_carrier_booking'  #
#                field on the 'shipment' table.                                            #
# parameters   : A Database Handle, A Shipment Id, The New State for the Field (TRUE       #
#                or FALSE), An Operator Id, The Reason for the Change.                     #
# returns      : Nothing.                                                                  #

sub log_shipment_rtcb :Export(:carrier_automation) {

    my ( $dbh, $shipment_id, $new_state, $op_id, $reason )    = @_;

    die "No Database Handle"            if (!$dbh);
    die "No Shipment Id"                if (!$shipment_id);
    die "No New State was Given"        if (! defined $new_state );
    die "No Operator Id"                if (!$op_id);
    die "No Reason Given"               if (!$reason);

    if ( !get_shipment_info( $dbh, $shipment_id ) ) {
        die "No Shipment found for Shipment Id: ".$shipment_id;
    }

    my $sql =<<SQL
INSERT INTO log_shipment_rtcb_state ( shipment_id, new_state, operator_id, reason_for_change )
VALUES ( ?, ?, ?, ? )
SQL
;
    my $sth = $dbh->prepare($sql);

    $sth->execute( $shipment_id, $new_state, $op_id, $reason );

    return;
}

### Subroutine : get_log_shipment_rtcb                                                   ###
# usage        : $array_ref = get_log_shipment_rtcb(                                       #
#                      $dbh,                                                               #
#                      $shipment_id                                                        #
#                  );                                                                      #
# description  : This returns the log entries for the change in state to the 'rtcb' field  #
#                on the 'shipment' table with most recent log comming first.               #
# parameters   : A Database Handle, A Shipment Id.                                         #
# returns      : AN ARRAY Ref of HASH Ref's to the log entries.                            #

sub get_log_shipment_rtcb :Export(:carrier_automation) {

    my ( $dbh, $shipment_id )       = @_;

    die "No Database Handle"            if (!$dbh);
    die "No Shipment Id"                if (!$shipment_id);

    my $sql =<<SQL
SELECT  lsrs.*,
        o.name AS operator_name
FROM    log_shipment_rtcb_state lsrs
        JOIN operator o ON o.id = lsrs.operator_id
WHERE   lsrs.shipment_id = ?
ORDER BY lsrs.id DESC
SQL
;
    my $sth = $dbh->prepare($sql);
    $sth->execute( $shipment_id );

    return results_list( $sth );
}

1;
