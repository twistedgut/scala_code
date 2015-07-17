package XTracker::Database::Delivery;
use strict;
use warnings;
use Carp;
use Perl6::Export::Attrs;
use XTracker::Database qw( :common );
use XTracker::Database::Utilities;
use XTracker::Constants::FromDB     qw(
    :delivery_item_status
    :delivery_item_type
    :delivery_status
    :delivery_type
    :stock_process_status
    :stock_process_type
    :delivery_action
);

# Create a delivery from data structure:
#
# $del = [  { stock_order_item_id => 0,
#              return_item_id => 0,
#             packing_slip        => 0,
#              type_id        => 0, }...
#        ]

sub create_delivery :Export(:DEFAULT) {

    my ( $dbh, $data_ref ) = @_;

    #!!! check input data

    my $qry = "insert into delivery values ( default, current_timestamp, null, $DELIVERY_STATUS__NEW, ? )";

    my $sth = $dbh->prepare($qry);
    $sth->execute( $data_ref->{delivery_type_id} );

    $data_ref->{delivery_id} = last_insert_id( $dbh, 'delivery_id_seq' );

    if ( $data_ref->{delivery_items}->[0]->{return_item_id} ) {
        _link_return_delivery( $dbh,
                                [ $data_ref->{delivery_id},
                                  $data_ref->{delivery_items}->[0]->{return_item_id}
                                ] );
    }
    elsif ( $data_ref->{delivery_items}->[0]->{shipment_item_id} ) {
        _link_shipment_delivery( $dbh,
                                [ $data_ref->{delivery_id},
                                  $data_ref->{delivery_items}->[0]->{shipment_item_id}
                                ] );
    }
    elsif ( $data_ref->{delivery_items}->[0]->{quarantine_process_id} ) {
        # no link from delivery for processed quarantine
    }
    else {
        _link_stock_order_delivery(
            $dbh,
            [   $data_ref->{delivery_id},
                $data_ref->{delivery_items}->[0]->{stock_order_item_id}
            ]
        );
    }

    foreach my $di_ref ( @{ $data_ref->{delivery_items} } ) {

        my $delivery_item_id = _create_delivery_item( $dbh,
                                                      $data_ref->{delivery_id},
                                                      $di_ref );

    }

    # Create db link between shipment and delivery (if applicable)
    if($data_ref->{shipment_id}) {
        $qry = "insert into link_delivery__shipment values ( ?, ? )";
        $sth = $dbh->prepare($qry);
        $sth->execute( $data_ref->{delivery_id}, $data_ref->{shipment_id} );
    }

    return $data_ref->{delivery_id};
}


### Subroutine : get_stock_process_log            ###
# usage        :                                    #
# description  :                                    #
#
#   returns log of stock movement
#
# parameters   : dbh, delivery id                   #
# returns      : resultset of log of stock movement #

sub get_stock_process_log :Export() {
    my ($dbh, $delivery_id) = @_;

    my $schema  = get_schema_using_dbh( $dbh, 'xtracker_schema' );

    my $log_delivery = $schema->resultset('Public::LogDelivery')
                       ->search({ delivery_id        => $delivery_id,
                                  delivery_action_id => $DELIVERY_ACTION__CREATE });

    return ($log_delivery);
}


### Subroutine : _create_delivery_item          ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub _create_delivery_item {

    my ( $dbh, $delivery_id, $data_ref ) = @_;

    my $qry = "insert into delivery_item values ( default, ?, ?, 0, 1, ? )";
    my $sth = $dbh->prepare($qry);

    $sth->execute( $delivery_id,
                   $data_ref->{packing_slip},
                   $data_ref->{type_id} );

    my $delivery_item_id = last_insert_id( $dbh, 'delivery_item_id_seq' );

    if ( $data_ref->{return_item_id} ) {
        _link_return_delivery_item( $dbh,
            [ $delivery_item_id, $data_ref->{return_item_id} ] );
    }
    elsif ( $data_ref->{shipment_item_id} ) {
        _link_shipment_delivery_item( $dbh,
            [ $delivery_item_id, $data_ref->{shipment_item_id} ] );
    }
    elsif ( $data_ref->{quarantine_process_id} ) {
        _link_quarantine_delivery_item( $dbh,
            [ $delivery_item_id, $data_ref->{quarantine_process_id} ] );
    }
    else {
        _link_stock_order_delivery_item( $dbh,
            [ $delivery_item_id, $data_ref->{stock_order_item_id} ] );
    }

    return $delivery_item_id;
}



### Subroutine : get_delivery                 ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_delivery :Export(:DEFAULT) {

    my ( $dbh, $id ) = @_;

    my $qry = qq{
               select date, invoice_nr, status_id, type_id, cancel, on_hold
                   from delivery
                   where id = ?
};

    my $sth = $dbh->prepare($qry);
    $sth->execute( $id );

    return $sth->fetchrow_hashref();
}

### Subroutine : get_delivery_channel                 ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_delivery_channel :Export() {

    my ( $dbh, $delivery_id ) = @_;

    my $channel = undef;

    # check stock orders
    my $qry = qq{
                   SELECT ch.name
                       FROM channel ch, super_purchase_order po, stock_order so, link_delivery__stock_order link, delivery d
                       WHERE d.id = ?
                       AND d.id = link.delivery_id
                       AND link.stock_order_id = so.id
                       AND so.purchase_order_id = po.id
                       AND po.channel_id = ch.id
                    UNION
                   SELECT ch.name
                    FROM channel ch, orders o, link_orders__shipment los, return r, link_delivery__return link, delivery d
                    WHERE d.id = ?
                    AND d.id = link.delivery_id
                    AND link.return_id = r.id
                    AND r.shipment_id = los.shipment_id
                    AND los.orders_id = o.id
                    AND o.channel_id = ch.id
                    UNION
                   SELECT ch.name
                    FROM channel ch, stock_transfer st, link_stock_transfer__shipment lsts, return r, link_delivery__return link, delivery d
                    WHERE d.id = ?
                    AND d.id = link.delivery_id
                    AND link.return_id = r.id
                    AND r.shipment_id = lsts.shipment_id
                    AND lsts.stock_transfer_id = st.id
                    AND st.channel_id = ch.id
                    UNION
                   SELECT ch.name
                    FROM channel ch, stock_transfer st, link_stock_transfer__shipment lsts, link_delivery__shipment link, delivery d
                    WHERE d.id = ?
                    AND d.id = link.delivery_id
                    AND link.shipment_id = lsts.shipment_id
                    AND lsts.stock_transfer_id = st.id
                    AND st.channel_id = ch.id
                    UNION
                   SELECT ch.name
                    FROM channel ch, quarantine_process qp, link_delivery_item__quarantine_process link, delivery_item di
                    WHERE di.delivery_id = ?
                    AND di.id = link.delivery_item_id
                    AND link.quarantine_process_id = qp.id
                    AND qp.channel_id = ch.id
                    GROUP BY ch.name
    };

    my $sth = $dbh->prepare( $qry );
    $sth->execute( $delivery_id, $delivery_id, $delivery_id, $delivery_id, $delivery_id );
    while ( my $row = $sth->fetchrow_hashref ) {
        $channel = $row->{name};
    }

    return $channel;
}

### Subroutine : set_delivery_item_quantity     ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub set_delivery_item_quantity :Export(:DEFAULT) {

    my ( $dbh, $delivery_item_id, $quantity ) = @_;

    my $qry = "update delivery_item set quantity = ? where id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $quantity, $delivery_item_id );

    return;
}

### Subroutine : set_delivery_status            ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub set_delivery_status :Export(:DEFAULT) {

    my ( $dbh, $id, $source, $type_id ) = @_;

    my %subqry = (
        'delivery_item_id' =>
            "( select delivery_id from delivery_item where id = ?)",
        'stock_process_id' =>
            "( select delivery_id from delivery_item where id =
                                            ( select delivery_item_id from
                                            stock_process where id = ? ))",
        'delivery_id' => " ?",
    );

    my $qry = "update delivery set status_id = ?
               where id = $subqry{$source}";

    my $sth = $dbh->prepare($qry);
    $sth->execute( $type_id, $id );

    return;
}

### Subroutine : set_delivery_item_status       ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub set_delivery_item_status :Export(:DEFAULT) {

    my ( $dbh, $id, $source, $type_id ) = @_;

    my %subqry = (
        'delivery_item_id' => " ?",
        'stock_process_id' => "( select delivery_item_id
                                            from stock_process where id = ? )",
    );

    my $qry = "update delivery_item set status_id = ?
               where id = $subqry{$source}";

    my $sth = $dbh->prepare($qry);
    $sth->execute( $type_id, $id );

    return;
}

### Subroutine : get_delivery_items                 ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_delivery_items :Export() {

    my ( $dbh, $delivery_id ) = @_;

    my $qry = qq{
               select id, packing_slip, quantity, status_id, type_id, cancel
                 from delivery_item
                where delivery_id = ?
    };
    my $sth = $dbh->prepare($qry);
    $sth->execute( $delivery_id );

    return $sth->fetchall_arrayref();
}


### Subroutine : get_cancelable_deliveries      ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_cancelable_deliveries :Export() {

    my ( $dbh ) = @_;

    my $qry = <<EOQ
SELECT del.id,
       TO_CHAR( del.date, 'YYYY-MM-DD' ) AS date,
       SUM( di.quantity ) AS quantity,
       SUM( di.packing_slip ) AS packing_slip,
       p.id AS product_id,
       d.designer,
       c.colour,
       p.legacy_sku,
       ds.status,
       del.type_id,
       MAX(sp.type_id) AS sp_type_id,
       ch.name AS sales_channel,
       po.channel_id
FROM delivery del
     JOIN delivery_status ds ON del.status_id = ds.id
     JOIN delivery_item di ON del.id = di.delivery_id
LEFT JOIN stock_process sp ON di.id = sp.delivery_item_id
     JOIN link_delivery_item__stock_order_item di_soi ON di_soi.delivery_item_id = di.id
     JOIN stock_order_item soi ON di_soi.stock_order_item_id = soi.id
     JOIN variant v ON soi.variant_id = v.id
     JOIN product p ON v.product_id = p.id
     JOIN colour c ON p.colour_id = c.id
     JOIN designer d ON p.designer_id = d.id
     JOIN stock_order so ON soi.stock_order_id = so.id
     JOIN purchase_order po ON so.purchase_order_id = po.id
     JOIN channel ch ON po.channel_id = ch.id
WHERE del.cancel = 'f'
  AND del.status_id IN ( $DELIVERY_STATUS__NEW, $DELIVERY_STATUS__COUNTED, $DELIVERY_STATUS__PROCESSING )
  AND del.type_id != $DELIVERY_TYPE__CUSTOMER_RETURN
GROUP BY del.id,
         del.date,
         p.id,
         d.designer,
         c.colour,
         p.legacy_sku,
         ds.status,
         del.type_id,
         ch.name,
         po.channel_id
HAVING MAX(sp.status_id) is null
    OR (
        MAX(sp.status_id) IN ( $STOCK_PROCESS_STATUS__NEW, $STOCK_PROCESS_STATUS__APPROVED, $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED )
    AND NOT bool_and( sp.complete )
    AND MAX( sp.type_id ) != $STOCK_PROCESS_TYPE__RTV
    )
ORDER BY del.id
EOQ
;

    my $sth = $dbh->prepare($qry);
    $sth->execute();

    my %data;

    while ( my $row = $sth->fetchrow_hashref ) {
        push @{$data{ $row->{sales_channel} }}, $row;
    }

    return \%data;
}


### Subroutine : get_stock_delivery_items       ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_stock_delivery_items :Export(:DEFAULT) {

    my ( $dbh, $delivery_id, $type ) = @_;

    my %status = ( 'item_count' => 1,
                 );

    my $qry = "select di.id, soi.variant_id, soi.quantity, di.packing_slip,
                      sku_padding(v.size_id) as size_id, s.size, s2.size as designer_size,
                      v.legacy_sku, di.quantity as delivered,
                      p.id as product_id, pa.description, c.colour, p.product_type_id, d.designer, sea.season, p.id || '-' || sku_padding(v.size_id) as sku
               from delivery_item di, stock_order_item soi, variant v, size s, size s2,
                    link_delivery_item__stock_order_item di_soi,
                    product p, product_attribute pa, colour c, season sea, designer d
               where di_soi.stock_order_item_id = soi.id
               and di_soi.delivery_item_id = di.id
               and soi.variant_id = v.id
               and v.size_id = s.id
               and v.designer_size_id = s2.id
               and v.product_id = p.id
               and pa.product_id = p.id
               and p.colour_id = c.id
               and p.season_id = sea.id
               and p.designer_id = d.id
               and di.delivery_id = ?";

     if( $type ){
         $qry .= " and di.status_id = $status{$type}";
     }

    my $sth = $dbh->prepare($qry);
    $sth->execute( $delivery_id );

    return results_list($sth);
}



### Subroutine : get_variant_delivery_ids       ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_variant_delivery_ids :Export() {

    my ( $dbh, $variant_id, $channel_id ) = @_;

    if ( not defined $variant_id) {
        die 'No variant_id defined for get_variant_delivery_ids()';
    }

    if ( not defined $channel_id) {
        die 'No channel_id defined for get_variant_delivery_ids()';
    }

    my $qry = "select di.delivery_id, di.id
                from delivery_item di, link_delivery_item__stock_order_item lk, stock_order_item soi, stock_order so, purchase_order po
                    where di.id = lk.delivery_item_id
                    and lk.stock_order_item_id = soi.id
                    and soi.variant_id = ?
                    and soi.stock_order_id = so.id
                    and so.purchase_order_id = po.id
                    and po.channel_id = ?
                    order by di.id asc limit 1";

    my $sth = $dbh->prepare( $qry );
    $sth->execute( $variant_id, $channel_id );

    my ($delivery_id, $delivery_item_id);

    $sth->bind_columns(\($delivery_id, $delivery_item_id));

    $sth->fetch();
    $sth->finish();

    return ($delivery_id, $delivery_item_id);

}

=head2

  usage        : $hash_ref  = get_incomplete_delivery_items_by_variant(
                        $database_handler,
                        $variant_id,
                        $channel_id
                    );

  description  : This function will return all the delivery items for a
                 variant that haven't been completed yet for a Sales
                 Channel for Stock Order Types only with either a
                 packing slip quantity or quantity > 0.

  parameters   : A Database Handler, A Variant Id, A Sales Channel Id.
  returns      : A HASH Ref of Delivery Items indexed by Delivery Item Id.

=cut

sub get_incomplete_delivery_items_by_variant :Export() {

    my ( $dbh, $variant_id, $channel_id ) = @_;

    if ( not defined $dbh ) {
        die 'No DBH Handler passed in';
    }
    if ( not defined $variant_id) {
        die 'No variant_id defined for get_incomplete_delivery_items_by_variant()';
    }

    if ( not defined $channel_id) {
        die 'No channel_id defined for get_incomplete_delivery_items_by_variant()';
    }

    my $retval;

    my $qry =<<SQL
SELECT  di.*
FROM    delivery_item di,
        link_delivery_item__stock_order_item lk,
        stock_order_item soi,
        stock_order so,
        purchase_order po
WHERE   di.id = lk.delivery_item_id
AND     di.cancel = FALSE
AND     di.type_id = $DELIVERY_ITEM_TYPE__STOCK_ORDER
AND     di.status_id < $DELIVERY_ITEM_STATUS__COMPLETE
AND     (di.packing_slip > 0 OR di.quantity > 0)
AND     lk.stock_order_item_id = soi.id
AND     soi.variant_id = ?
AND     soi.stock_order_id = so.id
AND     soi.cancel = FALSE
AND     so.purchase_order_id = po.id
AND     po.channel_id = ?
ORDER BY di.id ASC
SQL
;

    my $sth = $dbh->prepare( $qry );
    $sth->execute( $variant_id, $channel_id );

    while ( my $row = $sth->fetchrow_hashref() ) {
        $retval->{ $row->{id} } = $row;
    }

    return $retval;
}



### Subroutine : complete_delivery              ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub complete_delivery :Export() {

    my ( $dbh, $args_ref ) = @_;

    my $type = $args_ref->{type};
    my $id   = $args_ref->{id};

    my %clause = ( 'delivery' => ' = ?',
                   'stock_process' => ' = ( select delivery_id from delivery_item where id =
                              ( select delivery_item_id from stock_process where id = ? ))',
                 );

    my $qry = "update delivery set status_id = 6 where id $clause{$type}";
    my $sth = $dbh->prepare( $qry );
    $sth->execute( $id );

    return;
}


### Subroutine : complete_delivery_item         ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub complete_delivery_item :Export() {

    my ( $dbh, $args_ref ) = @_;

    my $type = $args_ref->{type};
    my $id   = $args_ref->{id};

    my %clause = ( 'delivery_item' => ' = ?',
                   'stock_process' => ' = ( select delivery_item_id from stock_process where id = ? )',
             );

    my $qry = "update delivery_item set status_id = $DELIVERY_ITEM_STATUS__COMPLETE where id $clause{$type}";
    my $sth = $dbh->prepare( $qry );
    $sth->execute( $id );

    return;
}


### Subroutine : delivery_is_complete           ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub delivery_is_complete :Export() {

    my ( $dbh, $args_ref ) = @_;

    my $type = $args_ref->{type};
    my $id   = $args_ref->{id};

    my %clause = ( 'delivery' => ' = ?',
                   'stock_process' => ' = ( select delivery_id from delivery_item where id =
                              ( select delivery_item_id from stock_process where id = ? ))',
                 );

    my $qry = "select min( di.status_id ) as di_status
                from delivery_item di
                where di.cancel is not True
                and di.quantity > 0
                and di.delivery_id $clause{$type}";

    my $sth = $dbh->prepare( $qry );
    $sth->execute( $id );

    my $complete = 0;
        $sth->bind_columns( \$complete );
        $sth->fetch();
    if($complete){
        return $complete == 4 ? 1 : 0;
    }else{
        return 0;
    }
}


### Subroutine : delivery_item_is_complete      ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub delivery_item_is_complete :Export() {

    my ( $dbh, $args_ref ) = @_;

    my $type = $args_ref->{type};
    my $id   = $args_ref->{id};

    my %clause = ( 'delivery_item' => ' = ?',
                   'stock_process' => ' = ( select delivery_item_id from stock_process where id = ? )',
             );

    my $qry = "select bool_and( sp.complete ) as complete
                 from stock_process sp, delivery_item di
                   where di.id = sp.delivery_item_id
           and di.id $clause{$type}";

    my $sth = $dbh->prepare( $qry );
    $sth->execute( $id );

    my $complete = 0;
        $sth->bind_columns( \$complete );
        $sth->fetch();

    return $complete;
}


### Subroutine : cancel_delivery                ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub cancel_delivery :Export() {

    my ( $dbh, $delivery_id ) = @_;

    my @qrys = (
             "delete from putaway where stock_process_id in (select id from stock_process where delivery_item_id in ( select id from delivery_item where delivery_id = ? ))",
             "delete from stock_process where delivery_item_id in ( select id from delivery_item where delivery_id = ? )",
             "update delivery_item set cancel = 't' where id in (  select id from delivery_item where delivery_id = ? )",
             "update delivery set cancel = 't' where id = ?",
    );

    #TODO: status updates - stock_order_item + stock_order

        foreach my $qry ( @qrys ){
            my $sth = $dbh->prepare( $qry );
            $sth->execute( $delivery_id );
        }

    return;
}


### Subroutine : get_variant_id_by_delivery_item_id               ###
# usage        : $scalar = get_variant_id_by_delivery_item_id(      #
#                     $dbh,                                         #
#                     $delivery_item_id                             #
#                 );                                                #
# description  : Returns the Variant Id for a Delivery Item Id.     #
# parameters   : Database Handle, Delivery Item Id.                 #
# returns      : The Variant Id                                     #

sub get_variant_id_by_delivery_item_id :Export() {

    my ( $dbh, $delivery_item_id ) = @_;

    my $qry = qq{
SELECT    v.id
FROM    variant v,
        stock_order_item soi,
        delivery_item dii,
        link_delivery_item__stock_order_item ldi_soi
WHERE    v.id = soi.variant_id
AND        soi.id = ldi_soi.stock_order_item_id
AND        ldi_soi.delivery_item_id = dii.id
AND        dii.id = ?
};

    my $sth = $dbh->prepare( $qry );

    $sth->execute( $delivery_item_id );

    my $variant_id = $sth->fetchrow;

    return $variant_id;
}


### Subroutine : get_stock_order_item_id_by_delivery_item_id                 ###
# usage        : $scalar = get_stock_order_item_id_by_delivery_item_id(        #
#                     $dbh,                                                    #
#                     $delivery_item_id                                        #
#                 );                                                           #
# description  : Returns a Stock Order Item Id for a Delivery Item Id.         #
# parameters   : Database Handle, Delivery Item Id.                            #
# returns      : The Stock Order Item Id                                       #

sub get_stock_order_item_id_by_delivery_item_id :Export() {

    my ( $dbh, $delivery_item_id ) = @_;

    my $qry = qq{
SELECT    stock_order_item_id
FROM    link_delivery_item__stock_order_item ldi_soi
WHERE    ldi_soi.delivery_item_id = ?
};

    my $sth = $dbh->prepare( $qry );

    $sth->execute( $delivery_item_id );

    my $stock_order_item_id = $sth->fetchrow;

    return $stock_order_item_id;
}


# generalised functions

BEGIN {

    # inserts
    *_link_return_delivery_item = make_update(
        "insert into link_delivery_item__return_item values ( ?, ? )");

    *_link_return_delivery = make_update(
        "insert into link_delivery__return ( delivery_id, return_id )
                                                values ( ?,
                                                    ( select return_id from return_item where id = ?))"
    );

    *_link_shipment_delivery_item = make_update(
        "insert into link_delivery_item__shipment_item values ( ?, ? )");

    *_link_quarantine_delivery_item = make_update(
        "insert into link_delivery_item__quarantine_process values ( ?, ? )");

    *_link_shipment_delivery = make_update(
        "insert into link_delivery__shipment ( delivery_id, shipment_id )
                                                values ( ?,
                                                    ( select shipment_id from shipment_item where id = ?))"
    );

    *_link_stock_order_delivery = make_update(
        "insert into link_delivery__stock_order ( delivery_id, stock_order_id )
                                                values ( ?,
                                                    ( select stock_order_id
                                                      from stock_order_item where id = ?))"
    );

    *_link_stock_order_delivery_item
        = make_update( "insert into link_delivery_item__stock_order_item values ( ?, ? )");

    # selects

    *get_return_deliveries = make_select(
        "select del.id, to_char( del.date, 'YYYY-MM-DD' ) as date, r.rma_number, sum( di.packing_slip ) as quantity, sp.type_id, ch.name as sales_channel
              from stock_process sp, delivery_item di, delivery del, link_delivery__return d_r, return r, shipment s, link_orders__shipment los, orders o, channel ch
              where sp.status_id = ?
                and sp.type_id = ?
                and sp.complete = false
                and sp.delivery_item_id = di.id
                and di.delivery_id = del.id
                and del.id = d_r.delivery_id
                and d_r.return_id = r.id
                and r.shipment_id = s.id
                and s.id = los.shipment_id
                and los.orders_id = o.id
                and o.channel_id = ch.id
              group by del.id, to_char( del.date, 'YYYY-MM-DD' ), r.rma_number, sp.type_id, ch.name
          union
          select del.id, to_char( del.date, 'YYYY-MM-DD' ) as date, r.rma_number, sum( di.packing_slip ) as quantity, sp.type_id, ch.name as sales_channel
              from stock_process sp, delivery_item di, delivery del, link_delivery__return d_r, return r, shipment s, link_stock_transfer__shipment link, stock_transfer st, channel ch
              where sp.status_id = ?
                and sp.type_id = ?
                and sp.complete = false
                and sp.delivery_item_id = di.id
                and di.delivery_id = del.id
                and del.id = d_r.delivery_id
                and d_r.return_id = r.id
                and r.shipment_id = s.id
                and s.id = link.shipment_id
                and link.stock_transfer_id = st.id
                and st.channel_id = ch.id
              group by del.id, to_char( del.date, 'YYYY-MM-DD' ), r.rma_number, sp.type_id, ch.name"
    );

    *get_return_delivery_items = make_select(
        "select di.id, di.packing_slip, v.size_id, v.legacy_sku, s.size
               from delivery_item di, variant v, size s,
                    return_item ri, link_delivery_item__return_item di_ri
               where di_ri.return_item_id = ri.id
               and di_ri.delivery_item_id = di.id
               and ri.variant_id = v.id
               and v.size_id = s.id
               and di.delivery_id = ?"
    );
}



### Subroutine : create_quarantine_process                 ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub create_quarantine_process :Export() {

    my ( $dbh, $variant_id, $channel_id ) = @_;

    # Shoes, Jewelry and Small Leather Goods need 2 small and 0 large
    my $qry = "INSERT INTO quarantine_process ( variant_id, channel_id ) VALUES ( ?, ? )";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $variant_id, $channel_id );

    return last_insert_id( $dbh, 'quarantine_process_id_seq' );
}


1;

__END__
