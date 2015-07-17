package XTracker::Database::PurchaseOrder;

use strict;
use warnings;
use Carp;

use Readonly;
use Perl6::Export::Attrs;
use DateTime;

use XTracker::Constants::FromDB     qw( :stock_order_item_status :stock_order_status );
use XTracker::Database;
use XTracker::Database::Utilities qw( results_list results_hash last_insert_id );

### Subroutine : confirm_purchase_order         ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub confirm_purchase_order :Export() {

    my $p = shift;

    my $qry = qq{
update purchase_order set
       confirmed = true,
       confirmed_operator_id = ?,
       when_confirmed = ?
 where id = ?
};

    my $sth = $p->{dbh}->prepare( $qry );

    $sth->execute(
        $p->{operator_id},
        'now()',
        $p->{purchase_order_id},
    );

    $sth->finish;

    return 1;

}


### Subroutine : is_purchase_order_confirmed    ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub is_purchase_order_confirmed :Export() {

    my $p = shift;

    my $qry = qq{
  select count( id ) as rocker, confirmed_operator_id
    from purchase_order
   where id = ?
     and confirmed is true
    group by confirmed_operator_id
};

    my $sth = $p->{dbh}->prepare( $qry );
    $sth->execute( $p->{purchase_order_id} );
    my $h = $sth->fetchrow_hashref();
    $sth->finish;

    if ( $h->{rocker} ) {
        return $h->{confirmed_operator_id};
    }

    return;

}

### Subroutine : get_payment_terms              ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_payment_terms :Export( ) {

    my ( $dbh, $p ) = @_;

    my $data;

    eval {

        my $qry = qq{
(
    select so1.id as id,
           to_char(so1.start_ship_date, 'yyyy-mm-dd') as date,
           sos.status as status
      from stock_order so1,
           stock_order_status sos
     where so1.purchase_order_id = ?
       and so1.status_id = sos.id
  order by so1.start_ship_date limit 1
)
union
(
    select so2.id as id,
           to_char(so2.cancel_ship_date, 'yyyy-mm-dd') as date,
           sos.status as status
      from stock_order so2,
           stock_order_status sos
     where purchase_order_id = ?
       and so2.status_id = sos.id
  order by so2.cancel_ship_date
      desc limit 1
)
};

        my $sth = $dbh->prepare( $qry );

        $sth->execute( $p->{id}, $p->{id} );

        $data->{start}  = $sth->fetchrow_hashref;
        $data->{cancel} = $sth->fetchrow_hashref;

        $sth->finish;

    }; if ($@) {
        $data->{error} = "456" . $@;
    }

    eval {

        my $qry = qq{
 select p.id as product_id, pt.payment_term, psd.discount_percentage, pd.deposit_percentage
   from product p,
        purchase_order po,
        stock_order so,
        payment_term pt,
        payment_settlement_discount psd,
        payment_deposit pd
  where po.id = ?
    and so.product_id = p.id
    and so.purchase_order_id = po.id
    and p.payment_term_id = pt.id
    and p.payment_settlement_discount_id = psd.id
    and p.payment_deposit_id = pd.id
};

        my $sth = $dbh->prepare( $qry );

        $sth->execute( $p->{id} );

        $data->{terms} = $sth->fetchrow_hashref;

        $sth->finish;

    }; if ( $@ ) {
        $data->{error} = "123" . $@;
    }

    return $data;

}

### Subroutine : create_purchase_order          ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub create_purchase_order :Export( :create ) {

    my ( $dbh, $data_ref ) = @_;


    # var to hold the new purchase order id
    my $po_id;

    # array to hold the insert vars
    my @execute_vars = ();

    # build insert sql
    my $qry = "INSERT INTO purchase_order ( id, date, purchase_order_number, description, designer_id, status_id, comment, currency_id, exchange_rate, season_id, type_id, cancel, supplier_id, act_id, confirmed, confirmed_operator_id, placed_by, channel_id ) VALUES (";

    # purchase order id passed to function?
    if ( defined( $data_ref->{purchase_order_id} ) ) {
        $qry .= "?";

        # put purchase order id into the insert vars
        push @execute_vars, $data_ref->{purchase_order_id};

        # pass the purchase order id to the po_id var
        $po_id = $data_ref->{purchase_order_id};
    }
    # generate purchase order id
    else {
        $qry .= "default";
    }

    if (defined $data_ref->{date}) {
        $qry .= ", ?";
        push @execute_vars, $data_ref->{date};
    }
    else {
        $qry .= ", current_timestamp";
    }
    $qry .= ", ? , ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? )";
    # finish of insert sql

    # put data into insert vars
    push @execute_vars, (
        $data_ref->{purchase_order_nr}, $data_ref->{description},
        $data_ref->{designer_id},       $data_ref->{status_id},
        $data_ref->{comment},           $data_ref->{currency_id},
        $data_ref->{exchange_rate},     $data_ref->{season_id},
        $data_ref->{type_id},           $data_ref->{cancel},
        $data_ref->{supplier_id},       $data_ref->{act_id},
        $data_ref->{confirmed},         $data_ref->{confirmed_operator_id},
        $data_ref->{placed_by},         $data_ref->{channel_id}
    );

    # do the insert
    my $sth = $dbh->prepare($qry);
    $sth->execute(@execute_vars);

    # get the purchase order id if not passed to function
    if ( not defined( $data_ref->{purchase_order_id} ) ) {
        $po_id = last_insert_id( $dbh, 'purchase_order_id_seq' );
    }

    return $po_id;

}



### Subroutine : update_purchase_order          ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub update_purchase_order :Export() {

    my ( $dbh, $purchase_order_id, $data_ref ) = @_;

    # build update sql
    my $qry = "UPDATE purchase_order SET
                description = ?,
                season_id = ?,
                act_id = ?,
                placed_by = ?
               WHERE id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $data_ref->{description}, $data_ref->{season_id}, $data_ref->{act_id}, $data_ref->{placed_by}, $purchase_order_id );

    return;

}


### Subroutine : set_shipping_window          ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub set_shipping_window :Export() {

    my ( $dbh, $purchase_order_id, $data_ref ) = @_;

    # build update sql
    my $qry = "UPDATE stock_order SET
                start_ship_date = ?,
                cancel_ship_date = ?
               WHERE purchase_order_id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $data_ref->{start_ship_date}, $data_ref->{cancel_ship_date}, $purchase_order_id );

    return;

}



### Subroutine : create_stock_order            ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub create_stock_order :Export( :create ) {

    my ( $dbh, $purchase_order_id, $data_ref ) = @_;


    # var to hold the new stock order id
    my $so_id;

    # array to hold the insert vars
    my @execute_vars = ();

    # build insert sql
    my $qry = "INSERT INTO stock_order ( id, product_id, purchase_order_id, start_ship_date, cancel_ship_date, status_id, comment, type_id, consignment, cancel, confirmed, shipment_window_type_id ) VALUES (";

    # stock order id passed to function?
    if ( defined( $data_ref->{stock_order_id} ) ) {
        $qry .= "?";

        # put stock order id into the insert vars
        push @execute_vars, $data_ref->{stock_order_id};

        # pass the stock order id to the so_id var
        $so_id = $data_ref->{stock_order_id};
    }
    # generate purchase order id
    else {
        $qry .= "default";
    }

    # finish of insert sql
    $qry .= ", ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? )";


    # put data into insert vars
    push @execute_vars, (
        $data_ref->{product_id},      $purchase_order_id,
        $data_ref->{start_ship_date}, $data_ref->{cancel_ship_date},
        $data_ref->{status_id},       $data_ref->{comment},
        $data_ref->{type_id},         $data_ref->{consignment},
        $data_ref->{cancel},         $data_ref->{confirmed},
        $data_ref->{shipment_window_type_id}
    );

    # do the insert
    my $sth = $dbh->prepare($qry);
    $sth->execute(@execute_vars);

    # get the stock order id if not passed to function
    if ( not defined( $data_ref->{stock_order_id} ) ) {
        $so_id = last_insert_id( $dbh, 'stock_order_id_seq' );
    }

    return $so_id;

}

### Subroutine : get_soi_uniq_variant       ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub check_soi_uniq_variant :Export() {
    my ($dbh, $stock_order_id, $variant_id) = @_;

    my $qry;
    my $count;

    $qry = qq{
                SELECT  COUNT(*)
                FROM    stock_order_item
                WHERE   stock_order_id = ?
                AND     variant_id = ?
        };

    my $sth = $dbh->prepare($qry);
    $sth->execute($stock_order_id,$variant_id);

    ($count) = $sth->fetchrow_array();

    return $count;
}

### Subroutine : create_stock_order_item       ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub create_stock_order_item :Export( :create ) {

    my ( $dbh, $stock_order_id, $data_ref ) = @_;


    # var to hold the new stock order item id
    my $soi_id;

    # array to hold the insert vars
    my @execute_vars = ();

    # build insert sql
    my $qry = "INSERT INTO stock_order_item ( id, stock_order_id, variant_id, quantity, status_id, type_id, cancel, original_quantity ) VALUES (";

    # stock order item id passed to function?
    if ( defined( $data_ref->{stock_order_item_id} ) ) {
        $qry .= "?";

        # put stock order item id into the insert vars
        push @execute_vars, $data_ref->{stock_order_item_id};

        # pass the stock order item id to the soi_id var
        $soi_id = $data_ref->{stock_order_item_id};
    }
    # generate purchase order id
    else {
        $qry .= "default";
    }

    # finish of insert sql
    $qry .= ", ?, ?, ?, ?, ?, ?, ? )";


    # put data into insert vars
    push @execute_vars, (
        $stock_order_id,
        $data_ref->{variant_id}, $data_ref->{quantity},
        $data_ref->{status_id},  $data_ref->{type_id},
        $data_ref->{cancel},     $data_ref->{original_quantity}
    );

    # do the insert
    my $sth = $dbh->prepare($qry);
    $sth->execute(@execute_vars);

    # get the stock order item id if not passed to function
    if ( not defined( $data_ref->{stock_order_item_id} ) ) {
        $soi_id = last_insert_id( $dbh, 'stock_order_item_id_seq' );
    }

    return $soi_id;

}



### Subroutine : get_stock_order_items_advanced ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_stock_order_items_advanced :Export() {

    my $p = shift;

    my %clause = ( 'stock_order_id'      => 'soi.stock_order_id = ?',
                   'stock_order_item_id' => 'soi.id = ?',
                   'delivery_id'         => 'soi.stock_order_id = ( select stock_order_id
                                                                         from link_delivery__stock_order
                                                                         where delivery_id = ? )',
                   'purchase_order_id'   => qq{ soi.stock_order_id in (
                                                       select so.id
                                                       from stock_order so
                                                       where so.purchase_order_id = ?
                                                   ) },
               );


    my $qry = qq|
    select v.product_id,
           soi.id, soi.variant_id, soi.quantity, soi.original_quantity, soi.status_id, soi.cancel, soi.stock_order_id,
           so.confirmed,
           sku_padding(v.size_id) as size_id, v.legacy_sku,
           s.size,
           ds.size as designer_size,
           vt.type,
           sois.status,
           pa.designer_colour_code,
           p.style_number,
           pr.wholesale_price,
           pr.uk_landed_cost
      from stock_order so, stock_order_item soi inner join stock_order_item_status sois
        on soi.status_id = sois.id inner join variant v
        on soi.variant_id = v.id left join size s
        on v.size_id = s.id left join size ds
        on v.designer_size_id = ds.id left join variant_type vt
        on v.type_id = vt.id left join product_attribute pa
        on v.product_id = pa.product_id, product p, price_purchase pr
     where p.id = v.product_id
       and $clause{$p->{type}}
       and p.id = pr.product_id
       and so.id = soi.stock_order_id
  order by v.product_id, ds.size, s.size
    |;

    my $sth = $p->{dbh}->prepare( $qry );

    $sth->execute( $p->{id} );

    my $bits;
    my $last_prod = 0;

    while ( my $row = $sth->fetchrow_hashref() ) {
        if ($last_prod != $row->{product_id}) {
            $bits->{$row->{product_id}}{product} = $row;
            $last_prod = $row->{product_id};
        }
        $bits->{$row->{product_id}}{items}{$row->{id}} = $row;
    }

    return $bits;
}


### Subroutine : get_stock_order_items          ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_stock_order_items :Export(:DEFAULT) {

    my ( $dbh, $args_ref ) = @_;

    my $type = $args_ref->{type};
    my $id   = $args_ref->{id};

    my %clause = ( 'stock_order_id'      => 'soi.stock_order_id = ?',
                   'stock_order_item_id' => 'soi.id = ?',
                   'delivery_id'         => 'soi.stock_order_id = ( select stock_order_id
                                                                         from link_delivery__stock_order
                                                                         where delivery_id = ? )',
                   'purchase_order_id'   => qq{ soi.stock_order_id in (
                                                       select so.id
                                                       from stock_order so
                                                       where so.purchase_order_id = ?
                                                   ) },
                 );

    my $qry = qq|SELECT soi.id, soi.variant_id, soi.quantity, soi.original_quantity,
                        sku_padding(v.size_id) as size_id, s.size, ds.size AS designer_size, ss.short_name as size_prefix, soi.status_id,
                        vt.type, v.legacy_sku, sois.status, soi.cancel
                   FROM stock_order_item soi, stock_order_item_status sois, product_attribute pa, size_scheme ss, variant v
                        LEFT JOIN size s ON v.size_id = s.id
                        LEFT JOIN size ds ON v.designer_size_id = ds.id
                        LEFT JOIN variant_type vt ON v.type_id = vt.id
                  WHERE soi.status_id = sois.id
                  AND v.product_id = pa.product_id
                  AND pa.size_scheme_id = ss.id
                  AND soi.variant_id = v.id
                  AND $clause{$type}
        |;

    my $sth = $dbh->prepare($qry);
    $sth->execute($id);

    return results_list($sth);
}


### Subroutine : get_stock_orders               ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_stock_orders :Export(:DEFAULT :search) {

    my ( $dbh, $args_ref ) = @_;
    my @db_args = ();

    my %clause = (
        'purchase_order_id' => ' so.purchase_order_id = ?',
        'stock_order_id'    => ' so.id = ?',
    );

    my $qry = qq{
select so.id,
       so.product_id,
       so.voucher_product_id,
       so.start_ship_date,
       so.comment,
       to_char(so.cancel_ship_date, 'YYYY-MM-DD') as cancel_ship_date,
       to_char(so.start_ship_date, 'YYYY-MM-DD') as start_ship_date,
           to_char(so.cancel_ship_date, 'DD-MM-YY') as display_cancel_date,
           to_char(so.start_ship_date, 'DD-MM-YY') as display_start_date,
           swt.type as shipment_window_type,
       CASE WHEN so.voucher_product_id IS NOT NULL THEN 'Voucher' ELSE pt.product_type END,
       sos.status,
       p.style_number,
       pa.designer_colour_code,
       sot.type,
       so.purchase_order_id,
       p.legacy_sku,
       so.cancel,
       so.status_id,
       sa.act,
       case when so.cancel_ship_date < current_date then 1 else 0 end as cancel_ship_date_active,
       so.cancel_ship_date AS parse_cancel_date,
       so.start_ship_date AS parse_start_date,
       pa.pre_order
  from stock_order so
            LEFT JOIN shipment_window_type swt ON (so.shipment_window_type_id = swt.id)
        LEFT JOIN product p ON (so.product_id = p.id)
        LEFT JOIN product_attribute pa ON (pa.product_id = p.id)
        LEFT JOIN product_type pt ON (p.product_type_id = pt.id)
        LEFT JOIN stock_order_status sos ON (so.status_id = sos.id)
        LEFT JOIN stock_order_type sot ON (so.type_id = sot.id)
        LEFT JOIN season_act sa ON (pa.act_id = sa.id)
};

    foreach my $key ( keys %$args_ref ){
        push @db_args, $args_ref->{$key};
        $qry .= "where $clause{$key}";
    }


    my $sth = $dbh->prepare($qry);
    $sth->execute(@db_args);

    return results_list($sth);

}


### Subroutine : get_purchase_order             ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_purchase_order :Export(:DEFAULT) {

    my ( $dbh, $id, $type ) = @_;

    my %qry_id = (
        'purchase_order_id'      => " spo.id = ?",
        'purchase_order'         => " spo.id = ( select id from super_purchase_order where purchase_order_number = ? )",
        'stock_order_id'         => " spo.id = ( select purchase_order_id from stock_order where id = ? )",
        'product_id'             => " spo.id in
                                                    (select purchase_order_id
                                                       from stock_order
                                                      where product_id = ? )",
        'variant_id'             => " spo.id in
                                                    (select purchase_order_id
                                                       from stock_order so, variant v
                                                      where v.id = ?
                                                        and so.product_id = v.product_id )",
    );

    my $qry = qq{
select  spo.id,
        spo.purchase_order_number,
        po.description,
        CASE WHEN po.act_id is NULL THEN 0 ELSE po.act_id END AS act_id,
        spo.supplier_id,
        CASE WHEN d.designer IS NULL AND vpo.id IS NOT NULL THEN
            'Voucher (N/A/)'
            ELSE d.designer END as designer,
        pos.status,
       po.comment,
       cur.currency,
       spo.exchange_rate,
       po.placed_by,
       po.confirmed,
       spo.channel_id,
       s.season,
       pot.type,
       s.id as season_id,
       d.id as designer_id,
       cur.id as currency_id,
       sa.act, ch.name as sales_channel, ch.id as channel_id
  from
        super_purchase_order spo
        inner join channel ch on (spo.channel_id = ch.id)
        inner join currency cur on (spo.currency_id = cur.id)
        inner join purchase_order_status pos on (spo.status_id = pos.id)
        inner join purchase_order_type pot on (spo.type_id = pot.id)
        left join purchase_order po on (spo.id = po.id)
        left join voucher.purchase_order vpo on (spo.id = vpo.id)

        left join designer d on (po.designer_id = d.id)
        left join season s on (po.season_id = s.id)
        left join currency c on (po.currency_id = c.id)
        left join season_act sa on (po.act_id = sa.id)
 where $qry_id{$type}
};

    my $sth = $dbh->prepare($qry);
    $sth->execute($id);

    return results_list($sth);
}




### Subroutine : set_ordered_quantity           ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub set_ordered_quantity :Export( :stock_order ){

    my ( $dbh, $args_ref ) = @_;

    my $quantity = $args_ref->{quantity};
    my $id       = $args_ref->{id};

    my $qry = "update stock_order_item set quantity = ? where id = ?";

    my $sth = $dbh->prepare($qry);
    $sth->execute( $quantity, $id );

    return;
}


### Subroutine : set_stock_order_details        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub set_stock_order_details :Export(:stock_order ){

    my ( $dbh, $args_ref ) = @_;

    my $value = $args_ref->{value};
    my $field = $args_ref->{field};
    my $so_id = $args_ref->{so_id};

    #TODO: check input data

    my $qry = "update stock_order set $field = ? where id = ?";

    my $sth = $dbh->prepare($qry);
    $sth->execute( $value, $so_id );

    return;
}

### Subroutine : set_stock_order_cancel_flag    ###
# usage        : set_stock_order_cancel_flag(     #
#                    $dbh,                        #
#                    $stock_order_id              #
#                );                               #
# description  : Sets the 'cancel' flag on the    #
#                stock order record if all of the #
#                stock order's items have been    #
#                cancelled.                       #
# parameters   : Database Handle, Stock Order Id  #
# returns      : Nothing                          #

sub set_stock_order_cancel_flag :Export() {

    my ( $dbh, $stock_order_id )    = @_;

    my $soi         = get_stock_order_items( $dbh, { type => 'stock_order_id', id => $stock_order_id } );
    my $num_cancel  = 0;
    my $flag        = 0;

    # see how many cancelled items we have
    foreach ( @{ $soi } ) {
        if ( $_->{'cancel'} ) {
            $num_cancel++;
        }
    }

    # if we have any canelled items and it's the same
    # number of records then set the cancel flag
    if ( $num_cancel && ( $num_cancel == scalar( @{ $soi } ) ) ) {
        $flag   = 1;
    }

    # update the stock order cancel flag accordingly
    set_stock_order_details( $dbh, { field => 'cancel', value => $flag, so_id => $stock_order_id } );

    return
}


### Subroutine : set_stock_order_item_details   ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub set_stock_order_item_details :Export(:stock_order ){

    my ( $dbh, $args_ref ) = @_;

    my $value = $args_ref->{value};
    my $field = $args_ref->{field};
    my $id    = $args_ref->{id};
    my $type  = $args_ref->{type};

    my %clause = ( 'stock_order_id' => ' stock_order_id = ?',
                   'id'             => ' id = ?',
                 );


    #TODO: check input data

    my $qry = "update stock_order_item set $field = ? where $clause{$type}";

    my $sth = $dbh->prepare($qry);
    $sth->execute( $value, $id );

    return;
}


### Subroutine : check_soi_status               ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub check_soi_status :Export() {

    my ( $dbh, $id, $type ) = @_;

    my %clause = ( 'delivery_item_id'       => ' (select stock_order_item_id from link_delivery_item__stock_order_item where delivery_item_id = ?)',
                   'stock_order_item_id'    => '?',
                 );

    my $qry  = "select soi.quantity as ordered, sum(di.quantity) as delivered
                from stock_order_item soi, delivery_item di,
                     link_delivery_item__stock_order_item ldi_soi
                where soi.id  = ldi_soi.stock_order_item_id
                and di.id  = ldi_soi.delivery_item_id
                and soi.id = $clause{$type}
                and di.cancel is not True
                group by soi.quantity";

    my $sth = $dbh->prepare($qry);
    $sth->execute( $id );

    my $ordered   = 0;
    my $delivered = 0;
    $sth->bind_columns( \$ordered, \$delivered );
    $sth->fetch();

    my $status = ( $delivered == 0 )                         ? $STOCK_ORDER_ITEM_STATUS__ON_ORDER
               : ( $delivered > 0 && $delivered < $ordered ) ? $STOCK_ORDER_ITEM_STATUS__PART_DELIVERED
               : ( $delivered >= $ordered )                  ? $STOCK_ORDER_ITEM_STATUS__DELIVERED
               : undef
               ;

    return $status;
}


### Subroutine : set_soi_status                 ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub set_soi_status :Export() {

    my ( $dbh, $id, $type, $status ) = @_;

    my %clause = ( 'delivery_item_id' => " (select stock_order_item_id
                                            from link_delivery_item__stock_order_item
                                            where delivery_item_id = ?)",
                                        'stock_order_item_id' => "?",
                 );

    my $qry  = "update stock_order_item set
                status_id = ?
                where id = $clause{$type}";

    my $sth = $dbh->prepare($qry);
    $sth->execute( $status, $id );

    return;
}


### Subroutine : check_stock_order_status       ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub check_stock_order_status :Export() {

    my ( $dbh, $stock_order_id ) = @_;

    my $qry = "SELECT MIN(status_id) AS min_id, MAX(status_id) AS max_id FROM stock_order_item WHERE stock_order_id = ? AND cancel = FALSE";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $stock_order_id );
    my ( $min, $max )   = $sth->fetchrow_array();

    return $STOCK_ORDER_STATUS__DELIVERED
        if ( defined $min && $min == $STOCK_ORDER_ITEM_STATUS__DELIVERED );

    return $STOCK_ORDER_STATUS__ON_ORDER
        if ( !defined $max || $max == $STOCK_ORDER_ITEM_STATUS__ON_ORDER );

    return $STOCK_ORDER_STATUS__PART_DELIVERED;
}



# set_stock_order_item_status( $dbh, { type => 'stock_order_item_id', id => $stock_order_item_id, status => 3 } );

### Subroutine : set_stock_order_item_status    ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub set_stock_order_item_status :Export() {

    my ( $dbh, $args_ref ) = @_;

    my $type   = $args_ref->{type};
    my $status = $args_ref->{status};
    my $id     = $args_ref->{id};

    my %clause = (
            'stock_order_item_id' => ' id = ?',
            'stock_order_id'      => ' id = ?',
            'variant_id'          => ' id = ?',
            );

    my $qry  = qq{
        update stock_order_item set
        status_id = ?
        where $clause{$type}
    };

    my $sth = $dbh->prepare($qry);
    $sth->execute( $status, $id );

    return;
}


### Subroutine : check_purchase_order_status    ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub check_purchase_order_status :Export() {

    my ( $dbh, $id, $type ) = @_;

    if (!$type) {
        $type = 'purchase_order_id';
    }

    my %clause = (
        'purchase_order_id' => ' purchase_order_id = ?',
        'stock_order_id' => ' purchase_order_id = (select purchase_order_id from stock_order where id = ?)',
    );

    my $qry = "select min( status_id ), max(status_id) from stock_order where $clause{$type} and cancel = false";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $id );

    my ( $min, $max );
    $sth->bind_columns( \$min, \$max );
    $sth->fetch();

    my $status = $min == $max           ? $min
               : $max == 3 && $min < 3  ? 2
               : $max == 2              ? 2
               : 1
               ;
    $status = 1     if ( !defined $status );

    return $status;
}


### Subroutine : set_purchase_order_status      ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub set_purchase_order_status :Export() {

    my ( $dbh, $args_ref ) = @_;

    my $type   = $args_ref->{type};
    my $status = $args_ref->{status};
    my $id     = $args_ref->{id};

    my %clause = (
        'purchase_order_id' => ' id = ?',
        'stock_order_id' => ' id = (select purchase_order_id from stock_order where id = ?)',
    );

    my $qry  = "update super_purchase_order set status_id = ? where $clause{$type}";

    my $sth = $dbh->prepare($qry);
    $sth->execute( $status, $id );

    return;
}



### Subroutine : get_purchase_order_id          ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_purchase_order_id :Export() {

    my ( $dbh, $args_ref ) = @_;

    my $type   = $args_ref->{type};
    my $id     = $args_ref->{id};

    my %clause = ( 'stock_order_id' => ' id = ?', );

    my $qry  = "select purchase_order_id from stock_order where $clause{$type}";

    my $sth = $dbh->prepare($qry);
    $sth->execute( $id );

    my $purchase_order_id = $sth->fetch()->[0];

    return $purchase_order_id;
}


### Subroutine : get_product_purchase_orders                               ###
# usage        : get_product_purchase_orders( $dbh, $product_id );           #
# description  : get all purchase orders for a products                      #
# parameters   : $dbh, $product_id                                           #
# returns      : hash ref                                                    #

sub get_product_purchase_orders :Export() {

    my ( $dbh, $product_id ) = @_;

    if (not defined $product_id) {
        die 'No product_id defined for get_product_purchase_orders()';
    }

    my $qry  = qq{
        select po.id as purchase_order_id, po.purchase_order_number
            from stock_order so, purchase_order po
        where so.product_id = ?
            and so.purchase_order_id = po.id
    };

    my $sth = $dbh->prepare($qry);
    $sth->execute( $product_id );

    my %data;

    while ( my $row = $sth->fetchrow_hashref() ) {
        $data{ $row->{purchase_order_id} } = $row;
    }

    return \%data;
}

### Subroutine : get_purchase_order_type        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_purchase_order_type :Export() {

    my ( $dbh, $p ) = @_;

    my $qry = q{
select id, type
from purchase_order_type
};

    my $sth = $dbh->prepare( $qry );

    $sth->execute;

    return results_list( $sth );

}


### Subroutine : get_status                     ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_status :Export() {

    my ( $dbh, $p ) = @_;

    my $qry = q{
select id, status
from purchase_order_status
};

    my $sth = $dbh->prepare( $qry );

    $sth->execute;

    return results_list( $sth );

}


### Subroutine : get_product                    ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_product :Export() {

    my ( $dbh, $p ) = @_;

    my $clause = {
        stock_order_type => "and sot.type = '$p->{value}'",
        none             => "and 1 = 1",
    };

    my $qry = qq{
select so.purchase_order_id, so.product_id, to_char(so.start_ship_date, 'YYYY-MM-DD') as date_start_ship,
       to_char(so.cancel_ship_date, 'YYYY-MM-DD') as date_cancel_ship, sos.status, p.legacy_sku,
       sot.type as stock_order_type, style_number
  from purchase_order po, stock_order so, product p, stock_order_status sos, stock_order_type sot
 where po.id = ?
   and po.id = so.purchase_order_id
   and so.product_id = p.id
   and sos.id = so.status_id
   and so.type_id = sot.id
   $clause->{$p->{clause}}
};

    my $sth = $dbh->prepare( $qry );

    $sth->execute( $p->{id} );

    if ( $p->{results} eq 'hash' ) {
        return results_hash( $sth );
    }
    else {
        return results_list( $sth );
    }

}


### Subroutine : get_sample_stock_order_id                                ###
# usage        : $scalar = get_sample_order_id(                             #
#                            $dbh,                                          #
#                            $args_ref = { type,id }                        #
#                    );                                                     #
# description  : Returns a single 'stock_order_id' for a Sample Purchase    #
#                Order for a given product_id, variant_id or delviery_id.   #
# parameters   : Database Handle, Args Ref containing a 'type' (product_id, #
#                variant_id or delivery_id) and an 'id' for the 'type'.     #
# returns      : A scalar variable containing the stock order id.           #

sub get_sample_stock_order_id :Export() {

    my ( $dbh, $args_ref ) = @_;

    my $type   = $args_ref->{type};
    my $id     = $args_ref->{id};

    my %clause = ( 'delivery_id' => ' ld_so.delivery_id = ?',  );

    my $qry  = qq{
select ld_so.stock_order_id
  from link_delivery__stock_order ld_so,
       stock_order so,
       stock_order_type sot
 where $clause{$type}
   and so.cancel is not true
   and so.type_id = sot.id
   and ld_so.stock_order_id = so.id
   and sot.type = 'Sample'
};

    if ( $args_ref->{type} eq 'product_id' ) {

        $qry = qq{
select so.id as stock_order_id
  from stock_order so,
       stock_order_type sot,
       product p,
       variant v,
       variant_type vt,
       stock_order_item soi,
       size s,
       stock_order_item_status sois,
       purchase_order po
 where soi.variant_id = v.id
   and v.size_id = s.id
   and v.type_id = vt.id
   and vt.type = 'Sample'
   and soi.status_id = sois.id
   and so.id = soi.stock_order_id
   and so.product_id = p.id
   and p.id = v.product_id
   and v.type_id = 3
   and so.type_id = sot.id
   and sot.type = 'Sample'
   and po.id = so.purchase_order_id
   and so.cancel is not true
   and v.product_id = ?
        };

    }
    elsif ( $args_ref->{type} eq 'variant_id' ) {

        $qry = qq{
select so.id as stock_order_id
  from stock_order so,
       product p,
       variant v,
       stock_order_type sot
 where sot.type = 'Sample'
   and so.type_id = sot.id
   and so.cancel is not true
   and p.id = so.product_id
   and p.id = v.product_id
   and v.type_id = 3
   and v.id = ?
        };

    }

    my $sth = $dbh->prepare($qry);

    $sth->execute( $id );

    my $stock_order_id = 0;

    ($stock_order_id) = $sth->fetchrow_array();

    if ( !defined $stock_order_id || !$stock_order_id ) {
        return 0;
    }
    else {
        return $stock_order_id;
    }
}


### Subroutine : get_sample_stock_order_items                                  ###
# usage        : $array_ptr = get_sample_stock_order_items(                      #
#                     $dbh,                                                      #
#                     $args_ref = { type,id }                                    #
#                  );                                                            #
# description  : Gets the items ordered for a Sample Purchase Order.             #
#                Pass in either 'stock_order_id','stock_order_item_id'           #
#                or a 'delivery_id'                                              #
# parameters   : Database Handle, Args Ref containing a 'type' (stock_order_id,  #
#                stock_order_item_id or deliver_id) and an 'id' for the #type'.  #
# returns      : A pointer to an ARRAY of HASH's                                 #

sub get_sample_stock_order_items :Export() {

    my ( $dbh, $args_ref ) = @_;

    my $type = $args_ref->{type};
    my $id   = $args_ref->{id};

    my %clause = ( 'stock_order_id'      => ' AND soi.stock_order_id = ?',
                   'stock_order_item_id' => ' AND soi.id = ?',
                   'delivery_id'         => ' AND soi.stock_order_id = ( SELECT stock_order_id
                                                                         FROM link_delivery__stock_order
                                                                         WHERE delivery_id = ? )',
                 );

    my $qry = qq/
SELECT soi.id, soi.variant_id, soi.quantity,
 sku_padding(v.size_id) as size_id, s.size, soi.status_id,
 vt.type, v.legacy_sku, sois.status, soi.cancel, po.channel_id, ch.name AS sales_channel,
 di.quantity AS delivered_qty
FROM stock_order_item soi
LEFT JOIN link_delivery_item__stock_order_item ldisoi ON soi.id = ldisoi.stock_order_item_id
LEFT JOIN delivery_item di ON di.id = ldisoi.delivery_item_id,
stock_order_item_status sois, variant v, size s, variant_type vt,
stock_order so, stock_order_type sot, purchase_order po, channel ch
WHERE soi.variant_id = v.id
AND soi.stock_order_id = so.id
AND so.purchase_order_id = po.id
AND v.size_id = s.id
AND v.type_id = vt.id
AND vt.type = 'Sample'
AND soi.status_id = sois.id
AND so.type_id = sot.id
AND sot.type = 'Sample'
AND po.channel_id = ch.id
$clause{$type}
/;

    my $sth = $dbh->prepare($qry);

    $sth->execute($id);

    return results_list($sth);
}


sub is_confirmed :Export() {

    my $p = shift;

    my $qry = qq{
select count(so.id) as rock
from stock_order so
where so.purchase_order_id = ?
and so.confirmed is not true
};

    my $sth = $p->{dbh}->prepare( $qry );

    $sth->execute( $p->{id} );

    my $row = $sth->fetchrow_hashref( );

    if ( $row->{rock} > 0 ) {
        return 0;
    }
    else {
        return 1;
    }

}

### Subroutine : mark_po_as_not_editable_in_fulcrum                     ###
# usage        : mark_po_as_not_editable_in_fulcrum( $po_number );        #
# description  : Given a Purchase Order Number marks it as not            #
#                being editable in fulcrum (hense editable in XT)         #
# parameters   : po_number                                                #
# returns      : columns changed                                   #

sub mark_po_as_not_editable_in_fulcrum :Export() {

    my ( $dbh, $po_number ) = @_;

    my $qry = "insert into public.purchase_orders_not_editable_in_fulcrum(number) values (?)";

    my $sth = $dbh->prepare( $qry );

    return $sth->execute( $po_number );

}

1;
