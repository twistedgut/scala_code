package XTracker::Database::Stock;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use Carp;
use Perl6::Export::Attrs;
use Perl6::Junction 'any';
use MooseX::Params::Validate qw/validated_hash/;
use Moose::Util::TypeConstraints; # duck_type
use Try::Tiny;

use XTracker::Constants::FromDB qw(
    :flow_status
    :reservation_status
    :shipment_item_status
    :stock_action
    :variant_type
);

use XTracker::Constants qw/ $APPLICATION_OPERATOR_ID /;
use XTracker::Config::Local qw( config_var iws_location_name );
use XTracker::Database qw(get_schema_using_dbh);
use XTracker::Database::Utilities;
use XTracker::Logfile qw(xt_logger);
use XTracker::Utilities qw( d2 );
use XT::Domain::PRLs;

use Scalar::Util qw/blessed/;

### Subroutine : get_delivered_quantity         ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_delivered_quantity :Export(:DEFAULT){

    my ( $dbh, $args_ref ) = @_;

    my $type  = $args_ref->{type};
    my $id    = $args_ref->{id  };
    my $list  = $args_ref->{list};
    my $index = $args_ref->{index} || 'stock_order_id';

    my ( $db_args, $placeholder ) = make_placeholder( $args_ref );

    # No results - just return
    return if !$placeholder;

    my %clause = ( 'product_id'          => ' soi.variant_id in ( select id from variant where product_id = ? )',
                   'variant_id'          => ' soi.variant_id = ?',
                   'stock_order_id'      => ' soi.stock_order_id = ?',
                   'purchase_order_id'   => " soi.stock_order_id in ( select id from stock_order where purchase_order_id = $placeholder )",
                   'purchase_order_list' => " soi.stock_order_id in ( select id from stock_order where purchase_order_id in $placeholder )",
                   'delivery_id'         => " soi.stock_order_id = ( select stock_order_id from link_delivery__stock_order where delivery_id = ? )",
                 );

    my $qry = "SELECT $index, sum( di.quantity ) as quantity
               FROM  delivery_item di, stock_order_item soi
               LEFT JOIN variant v ON (soi.variant_id = v.id),
                     link_delivery_item__stock_order_item ldi_soi
               WHERE di.id  = ldi_soi.delivery_item_id
               AND   soi.id = ldi_soi.stock_order_item_id
               AND   $clause{ $type }
               AND   di.cancel = 'f'
               GROUP BY $index";

    my $sth = $dbh->prepare($qry);
    $sth->execute( @$db_args );

    return $index eq 'product_id' ? ($sth->fetchrow_array())[1] : results_hash2( $sth, $index );
}

### Subroutine : get_total_item_quantity                ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_total_item_quantity :Export() {

    my ( $dbh, $product_id ) = @_;

    my %data;

    if (not defined $product_id) {
        die 'No product_id defined for get_total_item_quantity()';
    }

    my $qry = "select sales_channel, variant_id, sum(quantity) as quantity from
               (
                   select ch.name as sales_channel, q.variant_id, sum(q.quantity) as quantity
                   from quantity q, super_variant v, channel ch
                   where q.variant_id = v.id
                   and v.product_id = ?
                   and q.status_id = $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS
                   and q.channel_id = ch.id
                   group by ch.name, q.variant_id
               union all
                   select ch.name as sales_channel, v.id as variant_id, count(si.*) as quantity
                   from shipment_item si, super_variant v, shipment s, link_orders__shipment link, orders o, channel ch
                   where (si.variant_id = v.id or si.voucher_variant_id = v.id)
                   and v.product_id = ?
                   and si.shipment_item_status_id in ($SHIPMENT_ITEM_STATUS__PICKED, $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION, $SHIPMENT_ITEM_STATUS__CANCEL_PENDING)
                   and si.shipment_id = s.id
                   and s.id = link.shipment_id
                   and link.orders_id = o.id
                   and o.channel_id = ch.id
                   group by ch.name, v.id
               union all
                   select ch.name as sales_channel, v.id as variant_id, count(si.*) as quantity
                   from shipment_item si, super_variant v, shipment s, link_stock_transfer__shipment link, stock_transfer st, channel ch
                   where (si.variant_id = v.id or si.voucher_variant_id = v.id)
                   and v.product_id = ?
                   and si.shipment_item_status_id in ($SHIPMENT_ITEM_STATUS__PICKED, $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION, $SHIPMENT_ITEM_STATUS__CANCEL_PENDING)
                   and si.shipment_id = s.id
                   and s.id = link.shipment_id
                   and link.stock_transfer_id = st.id
                   and st.channel_id = ch.id
                   group by ch.name, v.id
               ) as stock
               group by sales_channel, variant_id";

    my $sth = $dbh->prepare($qry);
    $sth->execute( $product_id, $product_id, $product_id );

    while ( my $row = $sth->fetchrow_hashref() ) {
        $data{ $row->{sales_channel} }{ $row->{variant_id} } = $row->{quantity};
    }

    return \%data;
}


### Subroutine : get_delivered_item_quantity      ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_delivered_item_quantity :Export() {

    my ( $dbh, $product_id ) = @_;

    my %data;

    if (not defined $product_id) {
        die 'No product_id defined for get_delivered_item_quantity()';
    }

    my $qry = qq{
          select ch.name as sales_channel, soi.variant_id, sum( di.quantity ) as quantity
            from delivery_item di, link_delivery_item__stock_order_item ldi_soi,
                 stock_order_item soi, stock_order so, super_purchase_order po, channel ch
           where so.product_id = ?
             and so.type_id in (1,2)
             and so.purchase_order_id = po.id
             and po.channel_id = ch.id
             and so.id = soi.stock_order_id
             and soi.id = ldi_soi.stock_order_item_id
             and ldi_soi.delivery_item_id = di.id
             and di.cancel = 'f'
            group by ch.name, soi.variant_id
    };

    my $sth = $dbh->prepare($qry);
    $sth->execute( $product_id );

    while ( my $row = $sth->fetchrow_hashref() ) {
        $data{ $row->{sales_channel} }{ $row->{variant_id} } = $row->{quantity};
    }

    return \%data;

}

### Subroutine : get_ordered_item_quantity      ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_ordered_item_quantity :Export() {

    my ( $dbh, $product_id ) = @_;

    my %data;

    if (not defined $product_id) {
        die 'No product_id defined for get_ordered_item_quantity()';
    }

    my $qry = "SELECT ch.name AS sales_channel, soi.variant_id, sum( soi.quantity ) AS quantity
                FROM super_purchase_order po
                LEFT JOIN stock_order so ON so.purchase_order_id = po.id
                LEFT JOIN stock_order_item soi ON so.id = soi.stock_order_id
                LEFT JOIN channel ch ON po.channel_id = ch.id
                WHERE so.product_id = ?
                AND so.type_id IN (1,2)
                AND soi.cancel = 'f'
                GROUP BY ch.name, soi.variant_id";


    my $sth = $dbh->prepare_cached($qry);       # use 'prepare_cached' for faster acces on subsequent calls
    $sth->execute( $product_id );

    while ( my $row = $sth->fetchrow_hashref() ) {
        next unless ((defined $row->{variant_id}) && ($row->{variant_id} ne ""));
        $data{ $row->{sales_channel} }{ $row->{variant_id} } = $row->{quantity};
    }

    return \%data;
}


### Subroutine : get_allocated_item_quantity                                      ###
# usage        : get_allocated_item_quantity($dbh, $product_id)                     #
# description  : get allocated quantity for all variants of a product               #
#                'allocated' includes reserved stock, ordered but not packed items  #
#                and cancelled items not adjusted back to the site yet              #
# parameters   : $dbh, $product_id                                                  #
# returns      : hash ref                                                           #

sub get_allocated_item_quantity :Export(){

    my ( $dbh, $product_id ) = @_;

    my %data;

    if (not defined $product_id) {
        die 'No product_id defined for get_allocated_item_quantity()';
    }

    my $qry = qq{
        select sales_channel, variant_id, sum(quantity) as quantity from
                    (
                          select ch.name as sales_channel, r.variant_id, count(*) as quantity
                          from reservation r, super_variant v, channel ch
                          where r.status_id = $RESERVATION_STATUS__UPLOADED
                          and r.variant_id = v.id
                          and v.product_id = ?
                          and r.channel_id = ch.id
                          group by ch.name, r.variant_id
                      union all
                           select ch.name as sales_channel, v.id as variant_id, count(si.*) as quantity
                           from shipment_item si, super_variant v, shipment s, link_orders__shipment link, orders o, channel ch
                           where (si.variant_id = v.id or si.voucher_variant_id = v.id)
                           and v.product_id = ?
                           and si.shipment_item_status_id IN (
                               $SHIPMENT_ITEM_STATUS__NEW,
                               $SHIPMENT_ITEM_STATUS__SELECTED,
                               $SHIPMENT_ITEM_STATUS__PICKED,
                               $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
                               $SHIPMENT_ITEM_STATUS__CANCEL_PENDING )
                           and si.shipment_id = s.id
                           and s.id = link.shipment_id
                           and link.orders_id = o.id
                           and o.channel_id = ch.id
                           group by ch.name, v.id
                       union all
                           select ch.name as sales_channel, v.id as variant_id, count(si.*) as quantity
                           from shipment_item si, super_variant v, shipment s, link_stock_transfer__shipment link, stock_transfer st, channel ch
                           where (si.variant_id = v.id or si.voucher_variant_id = v.id)
                           and v.product_id = ?
                           and si.shipment_item_status_id IN (
                               $SHIPMENT_ITEM_STATUS__NEW,
                               $SHIPMENT_ITEM_STATUS__SELECTED,
                               $SHIPMENT_ITEM_STATUS__PICKED,
                               $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
                               $SHIPMENT_ITEM_STATUS__CANCEL_PENDING )
                           and si.shipment_id = s.id
                           and s.id = link.shipment_id
                           and link.stock_transfer_id = st.id
                           and st.channel_id = ch.id
                           group by ch.name, v.id
                    ) as allocated
               group by sales_channel, variant_id
    };

    my $sth = $dbh->prepare($qry);
    $sth->execute( $product_id, $product_id, $product_id );

    while ( my $row = $sth->fetchrow_hashref() ) {
        $data{ $row->{sales_channel} }{ $row->{variant_id} } = $row->{quantity};
    }

    return \%data;
}


### Subroutine : get_picked_item_quantity                                     ###
# usage        : get_picked_item_quantity($dbh, $product_id)                    #
# description  : get picked quantity for all variants of a product              #
#                includes items which are picked but not packed                 #
#                and items in packing exception                                 #
# parameters   : $dbh, $product_id                                              #
# returns      : hash ref                                                       #

sub get_picked_item_quantity :Export(){

    my ( $dbh, $product_id ) = @_;

    my %data;

    if (not defined $product_id) {
        die 'No product_id defined for get_picked_item_quantity()';
    }

    my $qry = "select sales_channel, variant_id, sum(quantity) as quantity from
               (
                   select ch.name as sales_channel, v.id as variant_id, count(si.*) as quantity
                   from shipment_item si, super_variant v, shipment s, link_orders__shipment link, orders o, channel ch
                   where (si.variant_id = v.id or si.voucher_variant_id = v.id)
                   and v.product_id = ?
                   and si.shipment_item_status_id in ($SHIPMENT_ITEM_STATUS__PICKED, $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION, $SHIPMENT_ITEM_STATUS__CANCEL_PENDING)
                   and si.shipment_id = s.id
                   and s.id = link.shipment_id
                   and link.orders_id = o.id
                   and o.channel_id = ch.id
                   group by ch.name, v.id
               union all
                   select ch.name as sales_channel, v.id as variant_id, count(si.*) as quantity
                   from shipment_item si, super_variant v, shipment s, link_stock_transfer__shipment link, stock_transfer st, channel ch
                   where (si.variant_id = v.id or si.voucher_variant_id = v.id)
                   and v.product_id = ?
                   and si.shipment_item_status_id in ($SHIPMENT_ITEM_STATUS__PICKED, $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION, $SHIPMENT_ITEM_STATUS__CANCEL_PENDING)
                   and si.shipment_id = s.id
                   and s.id = link.shipment_id
                   and link.stock_transfer_id = st.id
                   and st.channel_id = ch.id
                   group by ch.name, v.id
               ) as stock
               group by sales_channel, variant_id";

    my $sth = $dbh->prepare($qry);
    $sth->execute( $product_id, $product_id );

    while ( my $row = $sth->fetchrow_hashref() ) {
        $data{ $row->{sales_channel} }{ $row->{variant_id} } = $row->{quantity};
    }

    return \%data;
}


### Subroutine : get_saleable_item_quantity  DEPRECATED                             ###
# usage        : get_saleable_item_quantity($dbh, $product_id)                      #
# description  : get 'saleable' or 'free' quantity for all variants of a product    #
# parameters   : $dbh, $product_id                                                  #
# returns      : hash ref                                                           #

sub get_saleable_item_quantity :Export(){
    # NOTE this method should be deprecated. Use get_saleable_item_quantity method on
    # DBIC Public::Product or Voucher::Product row object directly.
    my ( $schema, $pid )    = @_;
    die 'No product_id defined for get_picked_item_quantity()' unless defined $pid;

    if (!$schema->isa('DBIx::Class::Schema')) {
        $schema = get_schema_using_dbh($schema,'xtracker_schema');
    }
    my $p_ob = $schema->resultset('Public::Product')->find($pid);
    # might actually be a voucher
    $p_ob = $schema->resultset('Voucher::Product')->find($pid) unless $p_ob;
    return {} unless $p_ob; # maintain old behaviour rather than dying
    return $p_ob->get_saleable_item_quantity;
}


### Subroutine : get_reserved_item_quantity                                      ###
# usage        : get_reserved_item_quantity($dbh, $product_id)                     #
# description  : get reserved quantity for all variants of a product               #
# parameters   : $dbh, $product_id                                                  #
# returns      : hash ref                                                           #

sub get_reserved_item_quantity :Export(){

    my ( $dbh, $product_id, $status_id ) = @_;

    my %data;

    if (not defined $product_id) {
        die 'No product_id defined for get_picked_item_quantity()';
    }

    my $qry = qq{
        select sales_channel, variant_id, sum(quantity) as quantity
          from (

                  select ch.name as sales_channel, r.variant_id, count(r.*) as quantity
                    from reservation r, super_variant v, channel ch
                   where r.variant_id = v.id
                   and v.product_id = ?
                   and r.status_id = ?
                   and r.channel_id = ch.id
                   group by ch.name, r.variant_id

          ) as reserved
        group by sales_channel, variant_id
    };

    my $sth = $dbh->prepare($qry);
    $sth->execute( $product_id, $status_id );

    while ( my $row = $sth->fetchrow_hashref() ) {
        $data{ $row->{sales_channel} }{ $row->{variant_id} } = $row->{quantity};
    }

    return \%data;
}



### Subroutine : get_on_hand_quantity           ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_on_hand_quantity :Export(:DEFAULT){

    my ( $dbh, $args_ref ) = @_;

    my $type = $args_ref->{type};
    my $id   = $args_ref->{id};

    my %clause = ( 'product_id' => ' in ( select id from variant where product_id = ? '
                        . ' UNION select id from voucher.variant where voucher_product_id = ? )',
                   'variant_id' => ' = ?'
                 );

    my $qry = "select sum( quantity )
               from quantity
               where variant_id $clause{$type}
               and status_id != $FLOW_STATUS__QUARANTINE__STOCK_STATUS";

    my $sth = $dbh->prepare($qry);
    if($type eq 'product_id') {
        $sth->execute( $id, $id );
    }
    else {
        $sth->execute( $id );
    }

    my $stock_level = 0;
    $sth->bind_columns( \$stock_level );
    $sth->fetch();

    return $stock_level || 0;
}

### same as get_saleable_stock but including reservations
### Subroutine : get_total_pws_stock            ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_total_pws_stock :Export(:DEFAULT) {

    my ( $dbh, $args_ref ) = @_;

    my $type        = $args_ref->{type};
    my $id          = $args_ref->{id};
    my $channel_id  = $args_ref->{channel_id};

    my %clause = ( 'product_id' => ' in ( select id from super_variant where product_id = ?)',
                   'variant_id' => ' = ?'
                 );

    my $qry = "select variant_id, sum(quantity) as quantity from
               ( select id as variant_id, 0 as quantity
                 from super_variant
                 where id $clause{$type}
                 group by variant_id

                 union all

                 select variant_id, sum( quantity ) as quantity
                 from quantity
                 where variant_id $clause{$type}
                 and status_id = $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS
                 and channel_id = ?
                 group by variant_id

                 union all

                 select v.id as variant_id, -count(si.*) as quantity
                 from shipment_item si, super_variant v, link_orders__shipment link, orders o
                 where v.id $clause{$type}
                 and ( si.variant_id = v.id or si.voucher_variant_id = v.id )
                 and si.shipment_item_status_id IN ( $SHIPMENT_ITEM_STATUS__NEW, $SHIPMENT_ITEM_STATUS__SELECTED)
                 and si.shipment_id = link.shipment_id
                 and link.orders_id = o.id
                 and o.channel_id = ?
                 group by v.id

                 union all

                 select v.id as variant_id, -count(si.*) as quantity
                 from shipment_item si, super_variant v, link_stock_transfer__shipment link, stock_transfer st
                 where v.id $clause{$type}
                 and ( si.variant_id = v.id or si.voucher_variant_id = v.id )
                 and si.shipment_item_status_id IN ( $SHIPMENT_ITEM_STATUS__NEW, $SHIPMENT_ITEM_STATUS__SELECTED)
                 and si.shipment_id = link.shipment_id
                 and link.stock_transfer_id = st.id
                 and st.channel_id = ?
                 group by v.id
               ) as saleable
               group by variant_id";

    my $sth = $dbh->prepare($qry);
    $sth->execute( $id, $id, $channel_id, $id, $channel_id, $id, $channel_id );

    return results_hash2( $sth, 'variant_id' );
}

### Subroutine : get_ordered_quantity           ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_ordered_quantity :Export(:DEFAULT){

    my ( $dbh, $args_ref ) = @_;

    my $type = $args_ref->{type};
    my $id   = $args_ref->{id  };
    my $list  = $args_ref->{list};
    my $index = $args_ref->{index} || 'stock_order_id';

    my ( $db_args, $placeholder ) = make_placeholder( $args_ref );

    return if !$placeholder; # No results to query the database

    my %clause = ( 'product_id'          => ' variant_id in ( select id from variant where product_id = ?)',
                   'variant_id'          => ' variant_id = ?',
                   'stock_order_id'      => ' stock_order_id = ?',
                   'purchase_order_id'   => " stock_order_id in ( select id from stock_order where purchase_order_id = $placeholder )",
                   'purchase_order_list' => " stock_order_id in ( select id from stock_order where purchase_order_id in $placeholder )",
                 );

    my $qry = "select $index, sum( quantity ) as quantity, sum( original_quantity ) as original_quantity
               from stock_order_item soi
               left join variant v on (soi.variant_id = v.id)
               where $clause{ $type }
                and soi.cancel is false
               group by $index";

#die Dumper $qry;
    my $sth = $dbh->prepare($qry);
    $sth->execute( @$db_args );

    return $index eq 'product_id'? ($sth->fetchrow_array())[1] : results_hash2( $sth, $index );
}

### Subroutine : update_quantity                                               ###
# usage        : $scalar = update_quantity(                                      #
#                     $dbh,                                                      #
#                     $args_ref = {variant_id,                                   #
#                                  quantity,                                     #
#                                  channel_id,                                   #
#                                  type = [inc|dec],                             #
#                                  [location|location_id],                       #
#                                  [current_status|current_status_id,            #
#                                  [next_status|next_status_id}                  #
#                 );                                                             #
# description  : This updates the quantity table for a given variant, channel    #
#                & location. You can either increase (inc) or decrease (dec)     #
#                the quantity. Using the 'type' arg specify whether you want to  #
#                increment or decrement the quantity along with a negative       #
#                quantity to decrement or a positive quantity to increment.      #
# parameters   : Database Handle, Quantity to inc/dec, Channel Id, Type & either #
#                a Location Code or a Location Id.                               #
# returns      : The Id of the Quantity record updated.                          #

sub update_quantity :Export(:DEFAULT) {
    my ( $schema, $args_ref ) = @_;
    if (! $schema->isa('DBIx::Class::Schema')) {
        $schema=get_schema_using_dbh($schema,'xtracker_schema');
    }

    # check if we have the required data
    foreach my $field ( qw(variant_id quantity channel_id type) ) {
        if ( !defined $args_ref->{$field} ) {
            die "No $field defined for update_quantity()";
        }
    }

    # must have a location of some type passed in
    if (!defined $args_ref->{location} && !defined $args_ref->{location_id}) {
            die "No Location or Location Id defined for update_quantity()";
    }
    if (!defined $args_ref->{current_status} && !defined $args_ref->{current_status_id}) {
            die "No current status or current status id defined for update_quantity()";
    }

    die "Incorrect Type: $args_ref->{type} for update_quantity()" if ($args_ref->{type} ne "dec" && $args_ref->{type} ne "inc");
    die "Positive Value Passed: $$args_ref{quantity}, when should be negative in update_quantity()" if ($args_ref->{type} eq "dec" && $args_ref->{quantity} > 0);
    die "Negative Value Passed: $$args_ref{quantity}, when should be positive in update_quantity()" if ($args_ref->{type} eq "inc" && $args_ref->{quantity} < 0);
    die "Zero Value Passed: $$args_ref{quantity}, in update_quantity()" if ($args_ref->{quantity} == 0 && !defined $args_ref->{next_status_id});

    my $location = _get_location($schema,$args_ref);

    my $current_status = $args_ref->{current_status};
    my $next_status    = $args_ref->{next_status};

    if (defined $args_ref->{current_status_id}) {
        $current_status = $schema->resultset('Flow::Status')->find({
            id => $args_ref->{current_status_id},
        });
        die "Unknown current status @{[ $args_ref->{current_status_id} ]}"
            unless $current_status;
    }

    if (defined $args_ref->{next_status_id}) {
        $next_status = $schema->resultset('Flow::Status')->find({
            id => $args_ref->{next_status_id},
        });
        die "Unknown next status @{[ $args_ref->{next_status_id} ]}"
            unless $next_status;
    }

    if (defined $current_status && defined $next_status) {
        die "Can't move from @{[ $args_ref->{current_status_id} ]} to @{[ $args_ref->{next_status_id} ]}"
            unless $current_status->is_valid_next($next_status);
    }

    die "Location @{[ defined $args_ref->{location_id} ? ('id ',$args_ref->{location_id}) : $args_ref->{location} ]} does not accept next status @{[ $next_status->id ]}"
        if defined $next_status && !$location->allows_status($next_status);

    my $quant = $schema->resultset('Public::Quantity')->search({
        location_id => $location->id,
        variant_id  => $args_ref->{variant_id},
        channel_id  => $args_ref->{channel_id},
        status_id   => $current_status->id,
    });

    my $ret = $quant->first;
    if ($ret) { $ret = $ret->id } # WARN when this returns undef, it
                                # means that the stock quantity we
                                # were asked to upate *does not
                                # exist*. This is probably a problem.

    $quant->update({
        quantity => \[ 'quantity + ?', [quantity=>$args_ref->{quantity}] ],
        ( defined $next_status ? ( status_id => $next_status->id ) : () ),
    });

    return $ret;
}


### Subroutine : insert_quantity                                         ###
# usage        : $scalar = insert_quantity(                                #
#                     $dbh,                                                #
#                     $args_ref = {variant_id,                             #
#                                  quantity,                               #
#                                  channel_id,                             #
#                                  [location|location_id],                 #
#                                  [initial_status|initial_status_id]}     #
#                  );                                                      #
# description  : This creates a quantity record for a variant for a        #
#                location & channel. The quantity can't be less than zero  #
#                & either a location or location id can be passed in.      #
# parameters   : Database Handle, Variant Id, Quantity, Channel Id         #
#                & Location or Location Id                                 #
# returns      : The Id of the new Quantity Record.                        #

sub insert_quantity :Export(:DEFAULT) {
    my ( $schema, $args_ref ) = @_;
    if (! $schema->isa('DBIx::Class::Schema')) {
        $schema = get_schema_using_dbh($schema,'xtracker_schema');
    }

    # check we have the required data
    foreach my $field ( qw(variant_id quantity channel_id) ) {
        if ( !defined $args_ref->{$field} ) {
            confess "No $field defined for insert_quantity()";
        }
    }

    # must have a location of some type passed in
    if (!defined $args_ref->{location} && !defined $args_ref->{location_id}) {
        confess "No Location or Location Id defined for insert_quantity()";
    }

    if (!defined $args_ref->{initial_status} && !defined $args_ref->{initial_status_id}) {
        confess "No initial status or initial status id defined for insert_quantity()";
    }

    # check for negative quantity for insert
    if ($args_ref->{quantity} < 0) {
        confess "Negative Quantity: $args_ref->{quantity} passed in to insert_quantity()";
    }

    my $location = _get_location($schema,$args_ref);

    my $status = $args_ref->{initial_status};

    if (defined $args_ref->{initial_status_id}) {
        $status=$schema->resultset('Flow::Status')->find({id=>$args_ref->{initial_status_id}});
    }

    confess "Unknown status @{[ $args_ref->{initial_status_id} ]}" unless $status;

    confess "Status @{[ $args_ref->{initial_status_id} ]} is not a valid initial status" unless $status->is_initial;

    confess "Location @{[ defined $args_ref->{location_id} ? ('id ',$args_ref->{location_id}) : $args_ref->{location} ]} does not accept initial status @{[ $args_ref->{initial_status_id} ]}"
        unless $location->allows_status($status);

    my $quant=$schema->resultset('Public::Quantity')->create({
        quantity    => $args_ref->{quantity},
        location_id => $location->id,
        variant_id  => $args_ref->{variant_id},
        channel_id  => $args_ref->{channel_id},
        status_id   => $status->id,
    });

    return $quant->id;
}

### Subroutine : delete_quantity                            ###
# usage        : delete_quantity(                             #
#                     $dbh,                                   #
#                     $args_ref = {variant_id,                #
#                                  channel_id,                #
#                                  [location|location_id],    #
#                                  status_id}                 #
#                  );                                         #
# description  : This deletes a quantity record for a variant #
#                by channel_id or location. You can specify   #
#                either a location code or location id.       #
# parameters   : Database Handle, Variant Id, Channel Id &    #
#                either a Location Code or Location Id        #
# returns      : Nothing.                                     #

sub delete_quantity :Export(:DEFAULT) {

    my ( $schema, $args_ref ) = @_;
    if (! $schema->isa('DBIx::Class::Schema')) {
        $schema=get_schema_using_dbh($schema,'xtracker_schema');
    }

    # check we have the required data
    foreach my $field ( qw(variant_id channel_id) ) {
        if ( !defined $args_ref->{$field} ) {
            confess "No $field defined for delete_quantity()";
        }
    }

    # must have a location of some type passed in
    if (!defined $args_ref->{location} && !defined $args_ref->{location_id}) {
        confess "No Location or Location Id defined for delete_quantity()";
    }

    if (!defined $args_ref->{status} && !defined $args_ref->{status_id}) {
        confess "No status or status id defined for delete_quantity()";
    }

    my $status = $args_ref->{status};

    if (defined $args_ref->{status_id}) {
        $status=$schema->resultset('Flow::Status')->find({id=>$args_ref->{status_id}});
    }

    die "Unknown status @{[ $args_ref->{status_id} ]}" unless $status;

    my $location=_get_location($schema,$args_ref);

    $schema->resultset('Public::Quantity')->search({
        location_id => $location->id,
        variant_id => $args_ref->{variant_id},
        channel_id => $args_ref->{channel_id},
        status_id => $status->id,
    })->delete;

    return;
}


### Subroutine : get_located_stock              ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_located_stock :Export(:DEFAULT) {
    my ( $dbh, $args_ref, $class ) = @_;

    my $type        = $args_ref->{type};    # 'product_id' or 'variant_id'
    my $id          = $args_ref->{id};      # id of product or variant
    my $phase       = $args_ref->{iws_rollout_phase} || config_var('IWS', 'rollout_phase');
    my $prl_phase   = $args_ref->{prl_rollout_phase} || config_var('PRL', 'rollout_phase');
    my $exclude_iws = $args_ref->{exclude_iws} || ''; # include IWS unless the caller doesn't want it
    my $exclude_prl = $args_ref->{exclude_prl} || ''; # include PRLs unless the caller doesn't want it
    my $and_by      = '';

    unless ($args_ref->{type} eq any('product_id', 'variant_id')) {
        die 'Unexpected clause type for get_located_stock()';
    }

    my $and_not_in_iws = '';
    my $and_not_in_prl = '';

    if ( $exclude_iws && $phase > 0 ) {
        my $iws_location_name = iws_location_name();
        # not in works where != doesn't, if $iws_location_name is not known to the DB
        $and_not_in_iws = qq{ and l.id not in ( select id from location where location='$iws_location_name' ) };
    }

    if ( $exclude_prl && $prl_phase > 0 ) {
        my $prl_location_names = XT::Domain::PRLs::get_prl_location_names();

        if ($prl_location_names && @$prl_location_names) {
            my $prl_location_string = "'".join("','",@$prl_location_names)."'";
            $and_not_in_prl = qq{ and l.id not in ( select id from location where location in ($prl_location_string) ) };
        }
    }

    if ( $class ) {
        if ( $class eq 'stock_dc1' or $class eq 'stock_main' ) {
            $and_by = qq{ and q.status_id = $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS }
                    . $and_not_in_iws
                    . $and_not_in_prl;
        }
        elsif ( $class eq 'stock_transit'  ) {
            $and_by = qq{ and q.status_id in ($FLOW_STATUS__IN_TRANSIT_FROM_IWS__STOCK_STATUS, $FLOW_STATUS__IN_TRANSIT_FROM_PRL__STOCK_STATUS) };
        }
        elsif ( $class eq 'stock_other'  ) {
            $and_by = qq{ and q.status_id not in ($FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
                                                  $FLOW_STATUS__IN_TRANSIT_FROM_IWS__STOCK_STATUS,
                                                  $FLOW_STATUS__IN_TRANSIT_FROM_PRL__STOCK_STATUS)
                        }
                    . $and_not_in_iws
                    . $and_not_in_prl;
        }
        elsif ( $class eq 'sample' ) {
            $and_by = qq{ and v.type_id = $VARIANT_TYPE__SAMPLE };
        }
    }

    my $qry;
    require XTracker::Database::Product;

    if(XTracker::Database::Product::is_voucher($dbh, $args_ref)) {
        return 0 if $class eq 'sample';

        my %clause = ( 'product_id' => ' in ( select id from voucher.variant where voucher_product_id = ?)',
                   'variant_id' => ' = ?'
        );

        $qry = "select ch.name as sales_channel, ch.id as channel_id, l.id as location_id,
            l.location, q.status_id, fs.name AS status_name, q.variant_id, sum(q.quantity) as quantity
        FROM quantity q
        JOIN location l ON q.location_id = l.id
        JOIN voucher.variant v ON q.variant_id = v.id
        JOIN channel ch ON q.channel_id = ch.id
        JOIN flow.status fs ON q.status_id = fs.id
        where q.variant_id $clause{$type}
        $and_by
        group by ch.name, ch.id, l.id, l.location, q.status_id, q.variant_id, fs.name";
    }
    else {
        my %clause = ( 'product_id' => ' in ( select id from variant where product_id = ?)',
                   'variant_id' => ' = ?'
        );

        $qry = "select ch.name as sales_channel, ch.id as channel_id, l.id as location_id,
            l.location, q.status_id, fs.name AS status_name, q.variant_id, sum(q.quantity) as quantity
        FROM quantity q
        JOIN location l ON q.location_id = l.id
        JOIN variant v ON q.variant_id = v.id
        JOIN channel ch ON q.channel_id = ch.id
        JOIN flow.status fs ON q.status_id = fs.id
        where q.variant_id $clause{$type}
        $and_by
        group by ch.name, ch.id, l.id, l.location, q.status_id, q.variant_id, fs.name";
    }

    my $sth = $dbh->prepare($qry);
    $sth->execute( $id );

    my %results = ();

    while ( my $row = $sth->fetchrow_hashref() ) {
        $results{ $row->{sales_channel} }{ $row->{variant_id} }{ $row->{location_id} }{ $row->{status_id} } = $row;
    }

    return \%results;
}




### Subroutine : check_stock_location                             ###
# usage        : $scalar = check_stock_location(                    #
#                  $dbh,                                            #
#                  $args_ref = {variant_id,location,channel_id,status_id }    #
#                );                                                 #
# description  : Returns 1 or 0 if there is a quantity record       #
#                at a location for a channel.                       #
# parameters   : Database Handle, Variant Id, Location, Channel Id  #
# returns      : A 1 or a 0                                         #

sub check_stock_location :Export() {

    my ( $schema, $args_ref ) = @_;
    if (! $schema->isa('DBIx::Class::Schema')) {
        $schema = get_schema_using_dbh($schema,'xtracker_schema');
    }

    # check we have everything we need
    foreach my $field ( qw(variant_id channel_id status_id) ) {
        if ( !defined $args_ref->{$field} ) {
            die "No $field defined for check_stock_location()";
        }
    }

    # must have a location of some type passed in
    if (!defined $args_ref->{location} && !defined $args_ref->{location_id}) {
        die "No Location or Location Id defined for check_stock_location()";
    }

    my $location = _get_location($schema,$args_ref);

    my $count = $schema->resultset('Public::Quantity')->search({
        location_id => $location->id,
        variant_id  => $args_ref->{variant_id},
        channel_id  => $args_ref->{channel_id},
        status_id   => $args_ref->{status_id},
    })->count;

    return $count;
}

### Subroutine : get_stock_location_quantity                      ###
# usage        : $scalar = get_stock_location_quantity(             #
#                   $dbh,                                           #
#                   $args_ref = {variant_id,location,channel_id}    #
#                 );                                                #
# description  : Returns the quantity for a SKU in a particular     #
#                location for a channel.                            #
# parameters   : Database Handle, Variant Id, Location, Channel Id  #
# returns      : A Quantity of Stock                                #

sub get_stock_location_quantity :Export(:DEFAULT) {

    my ( $schema, $args_ref ) = @_;
    if (! $schema->isa('DBIx::Class::Schema')) {
        $schema=get_schema_using_dbh($schema,'xtracker_schema');
    }

    # check we have everything we need
    foreach my $field ( qw(variant_id channel_id status_id) ) {
        if ( !defined $args_ref->{$field} ) {
            die "No $field defined for get_stock_location_quantity()";
        }
    }

    # must have a location of some type passed in
    if (!defined $args_ref->{location} && !defined $args_ref->{location_id}) {
            die "No Location or Location Id defined for get_stock_location_quantity()";
    }

    my $location=_get_location($schema,$args_ref);

    my $quantity = $schema->resultset('Public::Quantity')->search({
        location_id => $location->id,
        variant_id => $args_ref->{variant_id},
        channel_id => $args_ref->{channel_id},
        status_id => $args_ref->{status_id},
    })->get_column('quantity')->sum();

    return $quantity || 0;
}

### Subroutine : set_quantity_details           ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub set_quantity_details :Export(:DEFAULT) {

    my ( $dbh, $args_ref ) = @_;

    my $quantity_id = $args_ref->{id};
    my $details     = $args_ref->{details};

    my $qry = "insert into quantity_details ( quantity_id, details )
               values ( ?, ?)";

    my $sth = $dbh->prepare($qry);
    $sth->execute( $quantity_id, $details );

    return;
}


### Subroutine : get_quantity_details           ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_quantity_details :Export(:DEFAULT) {

    my ( $dbh, $args_ref ) = @_;

    my $quantity_id = $args_ref->{quantity_id};

    my $qry = q{SELECT * FROM quantity_details WHERE quantity_id = ?};

    my $sth = $dbh->prepare($qry);
    $sth->execute($quantity_id);

    my $quantity_details_ref = results_list($sth)->[0];

    return $quantity_details_ref;

} ## END sub get_quantity_details


### Subroutine : get_quarantine_stock           ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_quarantine_stock :Export(:DEFAULT) {
    my ( $dbh ) = @_;

    my $qry
        = qq{SELECT
                q.id AS quantity_id
            ,   q.variant_id
            ,   q.location_id
            ,   q.quantity
            ,   q.channel_id
            ,   qd.details AS reason
            ,   v.size_id
            ,   v.designer_size_id
            ,   v.legacy_sku
            ,   v.product_id
            ,   s.size
            ,   d.designer
            ,   pa.name
            ,   sku_padding(v.size_id) as sku_size
            ,   to_char(max(ls.date), 'DD-MM-YYYY') as display_date
            ,   max(ls.date) as quarantine_date
            ,   ch.name as sales_channel
            FROM quantity q
            INNER JOIN channel ch
                ON (q.channel_id = ch.id)
            INNER JOIN location l
                ON (q.location_id = l.id)
            INNER JOIN variant v
                ON (q.variant_id = v.id)
            INNER JOIN size s
                ON (v.size_id = s.id)
            INNER JOIN product p
                ON (v.product_id = p.id)
            INNER JOIN designer d
                ON (p.designer_id = d.id)
            INNER JOIN product_attribute pa
                ON (v.product_id = pa.product_id)
            LEFT JOIN quantity_details qd
                ON (qd.quantity_id = q.id)
            LEFT JOIN log_stock ls
                ON (ls.variant_id = q.variant_id) AND ls.stock_action_id = $STOCK_ACTION__QUARANTINED
            WHERE q.status_id = $FLOW_STATUS__QUARANTINE__STOCK_STATUS
            GROUP BY q.id, q.variant_id, q.location_id, q.quantity, q.channel_id, qd.details, v.size_id, v.designer_size_id, v.legacy_sku, v.product_id, s.size, d.designer, pa.name, ch.name
            ORDER BY quarantine_date ASC
    };

    my $sth = $dbh->prepare($qry);
    $sth->execute();

    my %list;
    my $loop = 1;

    while ( my $row = $sth->fetchrow_hashref() ) {
        $list{ $row->{sales_channel} }{ $loop } = $row;
        $loop++;
    }

    return \%list;

}


### Subroutine : get_exchange_variants          ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_exchange_variants :Export(:DEFAULT) {

    my ($dbh, $shipment_item_id) = @_;

    my $qry = "SELECT v.id, v.product_id, v.size_id, v.designer_size_id, v.legacy_sku, s.size, ds.size as designer_size, v.product_id || '-' || sku_padding(v.size_id) as sku, ss.short_name as sizing_name, ch.name as sales_channel
               FROM shipment_item si, link_orders__shipment los, orders o, channel ch, variant v, size s, size ds, product_attribute pa, size_scheme ss
               WHERE si.id = ?
                AND si.shipment_id = los.shipment_id
                AND los.orders_id = o.id
                AND o.channel_id = ch.id
                AND v.product_id = (SELECT v.product_id FROM variant v, shipment_item si WHERE si.id = ? AND si.variant_id = v.id)
                                AND v.size_id = s.id
                                AND v.designer_size_id = ds.id
                                AND v.type_id = 1
                                AND v.product_id = pa.product_id
                                AND pa.size_scheme_id = ss.id";

    my $sth = $dbh->prepare($qry);
    $sth->execute($shipment_item_id, $shipment_item_id);

    my %vars;
    my $product_id;

    while ( my $row = $sth->fetchrow_hashref() ) {
        $vars{ $row->{id} } = $row;
        $product_id         = $row->{product_id};
    }

    # get free stock for product id
    my $free_stock;
    if ( $product_id ) {
        $free_stock = get_saleable_item_quantity($dbh, $product_id );
    }

    foreach my $variant_id ( keys %vars ) {
        $vars{ $variant_id }{quantity} = $free_stock->{ $vars{ $variant_id }{sales_channel} }{ $variant_id } || 0;
    }

    return \%vars;
}

### Subroutine : get_cust_reservation_variants                     ###
# usage        : $hash_ptr = get_cust_reservation_variants(          #
#                       $dbh,                                        #
#                       $shipment_item_id                            #
#                  );                                                #
# description  : This returns a list of variants for a particular    #
#                product that a customer has made reservations for.  #
#                Created for use when customers want to exchange     #
#                items for another item that has low stock it can be #
#                used with the above function get_exchange_variants. #
#                See JIRA: DCS-556.                                  #
# parameters   : A Database Handle & a Shipment Item Id.             #
# returns      : A Pointer to a HASH containing the list of variants #
#                with the variant id as the key.                     #

sub get_cust_reservation_variants :Export(:DEFAULT) {

    my ( $dbh, $shipment_item_id ) = @_;

    my %retval;

    my $qry =<<QRY
SELECT v.id,
 v.product_id,
 v.size_id,
 v.designer_size_id,
 v.legacy_sku,
 s.size,
 ds.size AS designer_size,
 v.product_id || '-' || sku_padding(v.size_id) as sku,
 ss.short_name AS sizing_name,
 ch.name AS sales_channel,
 r.id AS reservation_id,
 1 AS quantity
FROM shipment_item si,
 link_orders__shipment los,
 orders o,
 reservation r,
 channel ch,
 variant v,
 size s,
 size ds,
 product_attribute pa,
 size_scheme ss
WHERE si.id = ?
AND si.shipment_id = los.shipment_id
AND los.orders_id = o.id
AND o.customer_id = r.customer_id
AND r.channel_id = o.channel_id
AND r.variant_id = v.id
AND r.status_id = $RESERVATION_STATUS__UPLOADED
AND o.channel_id = ch.id
AND v.product_id = (
 SELECT v.product_id
 FROM variant v,
      shipment_item si
 WHERE si.id = ?
 AND si.variant_id = v.id
)
AND v.size_id = s.id
AND v.designer_size_id = ds.id
AND v.type_id = 1
AND v.product_id = pa.product_id
AND pa.size_scheme_id = ss.id
QRY
;

    my $sth = $dbh->prepare($qry);
    $sth->execute($shipment_item_id, $shipment_item_id);

    while ( my $row = $sth->fetchrow_hashref() ) {
        $retval{ $row->{id} } = $row;
    }

    return \%retval;
}

### Subroutine : get_variant_locations          ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_variant_locations :Export() {

    my ( $dbh, $args_ref ) = @_;

    my %data;
    my $type   = $args_ref->{type};
    my $id     = $args_ref->{id};
    my $sample = $args_ref->{sample};
    my $status_id = $args_ref->{status_id};

    $id =~ s/^p-//i;

    die "get_variant_locations does not accept location_type anymore"
        if defined $args_ref->{location_type};

    my $restriction_clause = '';

    if ($status_id) {
        $restriction_clause = " and q.status_id=$status_id";
    }

    if ( $sample ) {

        my $qry = qq{
            select v.product_id, v.size_id, v.legacy_sku, q.channel_id, l.location,
                l.id as location_id, q.quantity, q.status_id as status_id, st.name as status_name, v.id as variant_id
            from variant v, quantity q, location l, flow.status st
            where q.variant_id = v.id
            and l.id = q.location_id
            and q.status_id = st.id
            $restriction_clause
            and v.id in (
                select variant_id
                  from stock_order_item
                 where id in (
                    select stock_order_item_id
                      from link_delivery_item__stock_order_item
                     where delivery_item_id in (
                         select delivery_item_id
                           from stock_process
                          where group_id = ?
                     )
                 ) union
                   select variant_id from shipment_item where id in
                        ( select shipment_item_id from link_delivery_item__shipment_item where delivery_item_id in
                             ( select delivery_item_id from stock_process
                             where group_id = ? )
                  ))
        };

        my $sth = $dbh->prepare($qry);
        $sth->execute( $id, $id );

        while ( my $row = $sth->fetchrow_hashref() ) {
            $data{ $row->{channel_id} }{ $row->{variant_id} } = $row;
        }

    }
    else {

        my $qry = "select v.product_id, v.size_id, v.legacy_sku, q.channel_id, l.location, l.id as location_id, q.quantity, q.status_id as status_id, st.name as status_name, v.id as variant_id
               from channel ch, variant v, quantity q, location l, flow.status st
               where q.variant_id = v.id
               and l.id = q.location_id
               and q.status_id = st.id
             $restriction_clause
               and v.id in
                ( select variant_id from stock_order_item where id in
                   ( select stock_order_item_id from link_delivery_item__stock_order_item where delivery_item_id in
                       ( select delivery_item_id from stock_process where group_id = ? )
                   ) union
                     select variant_id from return_item where id in
                          ( select return_item_id from link_delivery_item__return_item where delivery_item_id in
                               ( select delivery_item_id from stock_process
                               where group_id = ? ) )
                    union
                     select variant_id from quarantine_process where id in
                          ( select quarantine_process_id from link_delivery_item__quarantine_process where delivery_item_id in
                               ( select delivery_item_id from stock_process
                               where group_id = ? ) )
               )";

        my $sth = $dbh->prepare($qry);
        $sth->execute( $id, $id, $id );

        while ( my $row = $sth->fetchrow_hashref() ) {
            $data{ $row->{channel_id} }{ $row->{variant_id} } = $row;
        }
    }

    # YES, this function returns "a" location record, not all of
    # them. It's only used in GoodsIn/Putaway, so it does not matter.

    return \%data;

}

###############################
### PERPETUAL INVENTORY FUNCTIONS
###############################


### Subroutine : set_stock_count           ###
# usage        :                                  #
# description  : create entry for a stock count                                 #
# parameters   :  variant_id, location, round of counting, currenct stock level, counted stock level, operator id, stock count group                                #
# returns      :   id of inserted row                               #

sub set_stock_count :Export() {

    my ( $dbh, $args ) = @_;

    if ($args->{cur_stock} eq "none"){ $args->{cur_stock} = 0; }

    ## get a group id if nothing passed to function
    if ( !$args->{group} ){
        my $qry = "INSERT INTO stock_count (id, variant_id, location_id, group_id, date, operator_id, expected_quantity, counted_quantity, round, stock_count_status_id, origin_id) VALUES (default, ?, (SELECT id FROM location WHERE location = ?), (SELECT nextval('stock_count_group')), current_timestamp, ?, ?, ?, ?, 1, ?)";
        my $sth = $dbh->prepare($qry);
        $sth->execute( $args->{variant_id}, $args->{location}, $args->{operator_id}, $args->{cur_stock}, $args->{count}, $args->{round}, $args->{origin_id} );
    }
    else {
        my $qry = "INSERT INTO stock_count (id, variant_id, location_id, group_id, date, operator_id, expected_quantity, counted_quantity, round, stock_count_status_id, origin_id) VALUES (default, ?, (SELECT id FROM location WHERE location = ?), ?, current_timestamp, ?, ?, ?, ?, 1, ?)";
        my $sth = $dbh->prepare($qry);
        $sth->execute( $args->{variant_id}, $args->{location}, $args->{group}, $args->{operator_id}, $args->{cur_stock}, $args->{count}, $args->{round}, $args->{origin_id} );
    }

    return last_insert_id( $dbh, 'stock_count_id_seq' );

}


### Subroutine : set_decline_stock_count           ###
# usage        :                                  #
# description  : create entry for a declined stock count where alternative variance found                                #
# parameters   :  count_id, actual variance                                #
# returns      :    id of inserted row                            #

sub set_decline_stock_count :Export() {

    my ( $dbh, $count_id, $variance ) = @_;

    # get details of last count
    my $qry = "select sc.variant_id, sc.operator_id, sc.expected_quantity, sc.counted_quantity, sc.round, sc.group_id, sc.origin_id, l.location
               from stock_count sc, location l
               where sc.id = ?
               and sc.location_id = l.id";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $count_id );
    my $row = $sth->fetchrow_hashref();

    # work out what the actual counted quantity is based on variance entered
    my $count = $row->{expected_quantity} + $variance;

    my $new_id = set_stock_count($dbh,
                                 {
                                     'variant_id'    => $row->{variant_id},
                                     'location'      => $row->{location},
                                     'round'         => ($row->{round}+1),
                                     'cur_stock'     => $row->{expected_quantity},
                                     'count'         => $count,
                                     'operator_id'   => $row->{operator_id},
                                     'group'         => $row->{group_id},
                                     'origin_id'     => $row->{origin_id}
                                 }
                             );

    return $new_id;

}

### Subroutine : check_stock_count_complete           ###
# usage        :                                  #
# description  : checks whether a stock count is completed - count matches stock level or two matching counts recorded       #
# parameters   :  stock count id      #
# returns      :   0 - not complete, 1 - complete                               #

sub check_stock_count_complete :Export() {

    my ( $dbh, $id ) = @_;

    my $complete = 0;

    my %count = ();

    my $qry = "select expected_quantity, counted_quantity from stock_count where group_id = (select group_id from stock_count where id = ?)";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $id );

    while ( my $row = $sth->fetchrow_arrayref() ) {

        ## count matches expected quantity - count complete
        if ($row->[0] == $row->[1]) {
            $complete = 1;
        }
        ## count matches a previous count within the count group- count complete
        elsif ($count{$row->[1]}) {
            $complete = 1;
        }
        ## count not completed - just record counted quantity for checking against further records
        else {
            $count{$row->[1]} = 1;
        }
    }

    return $complete;

}

### Subroutine : check_stock_count_variance                          ###
# usage        : ($scalar,$scalar) = check_stock_count_variance(       #
#                       $count_id                                      #
#                    );                                                #
# description  : Checks a stock_count to see if there is any variance  #
#                in expected & counted quantities for the last round   #
#                of counts, returns the last counted quantity and a    #
#                boolean flag indicating any variance.                 #
# parameters   : The Id of the Stock Count                             #
# returns      : The Counted Quantity, and Variance flag               #

sub check_stock_count_variance :Export() {

    my ($dbh, $count_id) = @_;

    # flag to check for variance between counted and expected quantity
    my $variance = 0;

    # var to keep track of the final counted quantity
    my $count = 0;

    my $qry =<<QRY
SELECT expected_quantity,
 counted_quantity
FROM stock_count
WHERE group_id = (SELECT group_id FROM stock_count WHERE id = ?)
ORDER BY round DESC LIMIT 1
QRY
        ;
    my $sth = $dbh->prepare($qry);
    $sth->execute( $count_id );

    while ( my $row = $sth->fetchrow_arrayref() ) {
        $count = $row->[1];

        # count doesn't match expected quantity - flag variance
        if ($row->[0] != $row->[1]) {
            $variance = 1;
        }
    }

    return ($count,$variance);
}

### Subroutine : update_stock_count                               ###
# usage        : update_stock_count(                                #
#                     $dbh,                                         #
#                     $args = {type, type_id, status_id}            #
#                 );                                                #
# description  : Updates stock_count_status field on the stock      #
#                count record, either by a direct stock count id    #
#                or by all records in a group for a stock count id. #
# parameters   : Database Handle & a hash of aguments containing    #
#                the Status Id to update to along with the Stock    #
#                Count Id and whether to update all in a group      #
#                or not                                             #
# returns      : Nothing                                            #

sub update_stock_count :Export() {

    my ($dbh, $args) = @_;

    my $type = $args->{type};
    my $type_id = $args->{type_id};
    my $status_id = $args->{status_id};

    my %clause = (
        'id' => ' id = ? ',
        'all_group' => ' group_id = (SELECT group_id FROM stock_count WHERE id = ?) '
    );

    my $qry =<<UPD
UPDATE stock_count
SET stock_count_status_id = ?
WHERE $clause{$type}
UPD
        ;

    my $sth = $dbh->prepare($qry);
    $sth->execute( $status_id, $type_id );

    return;
}

### Subroutine : accept_stock_count_variance           ###
# usage        :                                  #
# description  : updates a stock count as accepted       #
# parameters   :  stock count id      #
# returns      :   nothing                               #

sub accept_stock_count_variance :Export() {

    my ( $dbh, $count_id, $operator_id ) = @_;

    # update stock count group as 'Accepted' & set the date of count to current date less 1 hour (just a reporting quirk)
    my $qry = "update stock_count set stock_count_status_id = 3, date = current_timestamp - interval '1 hour', operator_id = ? where group_id = (select group_id from stock_count where id = ?)";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $operator_id, $count_id );

    # now set counted date of the last count to current timestamp - the accepted date
    $qry = "update stock_count set date = current_timestamp where id = ?";
    $sth = $dbh->prepare($qry);
    $sth->execute( $count_id );

    return;
}

### Subroutine : decline_stock_count_variance           ###
# usage        :                                  #
# description  : updates a stock count as declined       #
# parameters   :  stock count id      #
# returns      :   nothing                               #

sub decline_stock_count_variance :Export() {

    my ( $dbh, $count_id, $operator_id ) = @_;

    ## update stock count group as 'Declined'
    my $qry = "update stock_count set stock_count_status_id = 4, operator_id = ? where group_id = (select group_id from stock_count where id = ?)";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $operator_id, $count_id );

    # now set counted date of the last count to current timestamp - the declined date
    $qry = "update stock_count set date = current_timestamp where id = ?";
    $sth = $dbh->prepare($qry);
    $sth->execute( $count_id );

    return;

}

### Subroutine : delete_stock_count           ###
# usage        :                                  #
# description  : deletes a stock count group       #
# parameters   :  stock count id      #
# returns      :   nothing                               #

sub delete_stock_count :Export() {

    my ( $dbh, $count_id ) = @_;

    my $qry = "delete from stock_count where group_id = (select group_id from stock_count where id = ?)";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $count_id );

    return;
}

### Subroutine : check_stock_count_variant           ###
# usage        :                                  #
# description  : returns whether or not a variant needs to be counted       #
# parameters   :  variant id, location, if auto counting is on or off     #
# returns      :   0 - count not required, 1 - count required                               #

sub check_stock_count_variant :Export( :DEFAULT ) {
    my ( $dbh, $var_id, $location, $switch ) = @_;

    my $required = 0;

    # check if a Voucher Variant if it is then we can't do PI
    # for now until we can get it working with Vouchers, so
    # return ZERO immediately
    my $schema  = XTracker::Database::get_schema_using_dbh( $dbh, 'xtracker_schema' );
    my $voucher = $schema->resultset('Voucher::Variant')->find( $var_id );
    if ( defined $voucher ) {
        return $required;
    }

    ### check if 0 stock check required
    my $qry = "select sum(quantity) from quantity where variant_id = ? and location_id = (select id from location where location = ?) and status_id=?";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $var_id, $location, $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS );

    while ( my $row = $sth->fetchrow_arrayref() ) {
        if (defined $row->[0] && $row->[0] == 0) {

            $required = 1; # stock check required for 0 location quantity

            ### may need to reassign category A to stock count variant table OR create new entry if nothing in stock count table
            my $qry = "select stock_count_category_id from stock_count_variant where variant_id = ? and location_id = (select id from location where location = ?) and last_count is null";
            my $sth = $dbh->prepare($qry);
            $sth->execute( $var_id, $location );

            ### change existing stock count entry to a category A
            if ($sth->rows) {
                my $up_qry = "update stock_count_variant set stock_count_category_id = 1 where variant_id = ? and location_id = (select id from location where location = ?)";
                my $up_sth = $dbh->prepare($up_qry);
                $up_sth->execute( $var_id, $location );
            }
            ### create a category A stock count entry
            else {
                my $ins_qry = "insert into stock_count_variant values (?, (select id from location where location = ?), 1, null)";
                my $ins_sth = $dbh->prepare($ins_qry);
                $ins_sth->execute( $var_id, $location );
            }
        }
    }


    ### if not 0 stock level && stock counting is switched on - check if PI stock check required
    if ($required == 0 && $switch) {
        $qry = "select case when last_count is null then 1 else 0 end from stock_count_variant where variant_id = ? and location_id = (select id from location where location = ?)";
        $sth = $dbh->prepare($qry);
        $sth->execute( $var_id, $location );

        while ( my $row = $sth->fetchrow_arrayref() ) {
            $required = $row->[0];
        }
    }

    return $required;
}

### Subroutine : get_stock_count_by_location           ###
# usage        :                                  #
# description  : returns nearest stock count to be processed based on location entered by user       #
# parameters   :  location     #
# returns      :   variant id, location                               #

sub get_stock_count_by_location :Export( :DEFAULT ) {

    my ( $dbh, $scan_location ) = @_;

    my $var_id = "";
    my $location = "";

    $scan_location =~ s/-//;

    if ($scan_location =~ m/(\d{3})(\w{1})(\d{3,4})(\w{1})/) {

        my $dc = $1;
        my $zone = $2;
        my $bay = $3;
        my $srow = $4;

        ### get all stock counts on the same floor and zone as scanned location

        my %counts = ();

        my $qry = "select scv.variant_id, l.location, scc.priority from stock_count_variant scv, stock_count_category scc, location l where scv.last_count is null and scc.id = scv.stock_count_category_id and scv.location_id = l.id and l.location like '".$dc.$zone."%'";
        my $sth = $dbh->prepare($qry);
        $sth->execute();

        while ( my $row = $sth->fetchrow_hashref() ) {

            if ($row->{location} =~ m/(\d{3})(\w{1})-?(\d{3,4})(\w{1})/) {

                my $ldc = $1;
                my $lzone = $2;
                my $lbay = $3;
                my $lrow = $4;

                ### difference between scanned bay and stock count bay
                my $loc_diff = $lbay - $bay;
                if ($loc_diff < 0) {
                    $loc_diff = $loc_diff * -1;
                }
                if ($loc_diff == 0) {
                    $loc_diff = 1;
                }

                ### difference between scanned row and stock count row
                my %compare_row = ("A" => 1, "B" => 2, "C" => 3, "D" => 4, "E" => 5);
                my $row_diff = $compare_row{$lrow} - $compare_row{$srow};
                if ($row_diff < 0) {
                    $row_diff = $row_diff * -1;
                }


                # if difference between locations is > 10 then boost it by 1000
                if ($row->{priority} > 1 && $loc_diff > 10) {
                    $loc_diff = $loc_diff * 1000;
                }

                my $sort_val;

                # priority 1 counts come first
                if ($row->{priority} == 1) {
                    $sort_val = $loc_diff + $row_diff;
                }
                # other priority counts
                else {
                    $sort_val = (($loc_diff * 100) + $row_diff)  * ($row->{priority}**8);
                }

                $counts{$sort_val}{variant_id} = $row->{variant_id};
                $counts{$sort_val}{location} = $row->{location};
                $counts{$sort_val}{priority} = $row->{priority};
                $counts{$sort_val}{loc_diff} = $loc_diff;
            }
        }

        ### loop through sorted stock counts to get nearest
        foreach my $sort (sort {$b <=> $a} keys %counts ) {
            $var_id = $counts{$sort}{variant_id};
            $location = $counts{$sort}{location};
        }
    }

    return $var_id, $location;

}

### Subroutine : create_stock_count_variant           ###
# usage        :                                  #
# description  : creates a manual stock count request       #
# parameters   :  variant id, location     #
# returns      :   nothing                               #

sub create_stock_count_variant :Export() {

    my ( $dbh, $var_id, $location, $category ) = @_;

    my $qry = "INSERT INTO stock_count_variant VALUES (?, (select id from location where location = ?), (select id from stock_count_category where category = ?), null)";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $var_id, $location, $category );

}

### Subroutine : set_last_count_date           ###
# usage        :                                  #
# description  : sets the last counted date of a variant       #
# parameters   :  variant id, location     #
# returns      :   nothing                               #

sub set_last_count_date :Export() {

    my ( $dbh, $var_id, $location ) = @_;

    my $qry = "UPDATE stock_count_variant SET last_count = current_timestamp WHERE variant_id = ? AND location_id = (select id from location where location = ?)";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $var_id, $location );

}

### Subroutine : get_stock_count           ###
# usage        :                                  #
# description  : get stock count data       #
# parameters   :  stock count id     #
# returns      :   id, variant id, location id, group id, date, operator id, expected quantity, counted quantity, round, status        #

sub get_stock_count :Export() {

    my ( $dbh, $id ) = @_;

    my $qry = "select * from stock_count where id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute( $id );

    return $sth->fetchrow_hashref();

}

### Subroutine : get_stock_count_variances           ###
# usage        :                                  #
# description  : get all outstanding stock count variances       #
# parameters   :  nothing     #
# returns      :   stock count id, variant id, location id, expected qty, counted qty, date of count, sku, operator name       #

sub get_stock_count_variances :Export() {

    my ( $dbh, $sort_by ) = @_;

    my $qry = "select sc.id, sc.variant_id, l.id as location_id, l.location, sc.expected_quantity, sc.counted_quantity, sc.counted_quantity - sc.expected_quantity as variance, to_char(sc.date, 'DD-MM-YYYY  HH24:MI') as display_date, v.product_id || '-' || sku_padding(v.size_id) as sku, v.legacy_sku, op.name as operator, sco.origin
               from stock_count sc
                left join stock_count_origin sco on sc.origin_id = sco.id,
                location l, variant v, operator op
               where sc.stock_count_status_id = 2
               and sc.variant_id = v.id
               and sc.location_id = l.id
               and sc.operator_id = op.id";

    if ($sort_by) {
        $qry .= " order by $sort_by asc";
    }
    else {
        $qry .= " order by sc.counted_quantity, sc.date asc";
    }

    my $sth = $dbh->prepare($qry);
    $sth->execute( );

    my %data;

    my $loop = 1;

    while ( my $row = $sth->fetchrow_hashref() ) {
        $data{$loop} = $row;

        $loop++;
    }

    return \%data;

}

### Subroutine : get_stock_count_variances_count                      ###
# usage        : $scalar = get_stock_count_variances_count($dbh)        #
# description  : Counts the Number of Variances that need to be         #
#                looked at. For use in the sidenav of the Perpetual     #
#                Inventory section.                                     #
# parameters   : Database Handle                                        #
# returns      : The number in the list                                 #

sub get_stock_count_variances_count :Export() {

    my ( $dbh ) = @_;

    my $qry =<<QRY
SELECT COUNT(*) AS variance_count
FROM stock_count sc
WHERE sc.stock_count_status_id = 2
QRY
;

    my $sth = $dbh->prepare($qry);
    $sth->execute();
    my $count = $sth->fetchrow_hashref();

    return $count->{variance_count};
}

### Subroutine : get_stock_count_list           ###
# usage        :                                  #
# description  : get list of stock counts by date range       #
# parameters   :  start date, end date, sort by field     #
# returns      :   stock count id, variant id, location id, expected qty, counted qty, date of count, sku, operator name       #

sub get_stock_count_list :Export() {

    my ( $dbh, $start, $end, $sort_by ) = @_;

    my %data = ();
    my %sort_data = ();

    my $qry = "select sc.group_id, sc.variant_id, l.id as location_id, l.location, sc.expected_quantity, sc.counted_quantity, sc.counted_quantity - sc.expected_quantity as variance, to_char(sc.date, 'DD-MM-YYYY  HH24:MI') as display_date, to_char(sc.date, 'YYYYMMDDHH24:MI') as date_sort, v.product_id || '-' || sku_padding(v.size_id) as sku, v.product_id || sku_padding(v.size_id) as sku_sort, v.legacy_sku, op.name as operator, scs.status, sco.origin
               from stock_count sc
                left join stock_count_origin sco on sc.origin_id = sco.id,
                stock_count_status scs, location l, variant v, operator op
               where sc.stock_count_status_id in (3,4) -- status of Accepted or Declined only
               and sc.date between ? and ?
               and sc.stock_count_status_id = scs.id
               and sc.variant_id = v.id
               and sc.location_id = l.id
               and sc.operator_id = op.id
               order by sc.date asc";

    my $sth = $dbh->prepare($qry);
    $sth->execute($start, $end);

    while ( my $row = $sth->fetchrow_hashref() ) {
        $data{ $row->{group_id} } = $row;
    }

    # sort results
    if (!$sort_by) {
        $sort_by = 'display_date';
    }

    my $loop = 1;

    foreach my $group_id ( sort { $data{$a}{$sort_by} cmp $data{$b}{$sort_by} } keys %data ) {
        $sort_data{$loop} = $data{$group_id};
        $loop++;
    }


    return \%sort_data;

}


### Subroutine : get_stock_count_group           ###
# usage        :                                  #
# description  : get all stock counts from a group       #
# parameters   :  stock count id     #
# returns      :   round, stock count id, variant id, expected qty, counted qty, date of count, sku, operator name       #

sub get_stock_count_group :Export() {

    my ( $dbh, $count_id ) = @_;

    my $qry = "select sc.round, sc.id, sc.variant_id, sc.expected_quantity, sc.counted_quantity, to_char(sc.date, 'DD-MM-YYYY  HH24:MI') as display_date, l.location, v.product_id || '-' || sku_padding(v.size_id) as sku, op.name as operator
               from stock_count sc, location l, variant v, operator op
               where sc.group_id = (select group_id from stock_count where id = ?)
               and sc.variant_id = v.id
               and sc.location_id = l.id
               and sc.operator_id = op.id";
    my $sth = $dbh->prepare($qry);
    $sth->execute($count_id);

    my %data;

    while ( my $row = $sth->fetchrow_hashref() ) {
        $data{$$row{round}} = $row;
    }

    return \%data;

}

### Subroutine : get_stock_count_setting           ###
# usage        :                                  #
# description  : returns true or false if auto stock counting on for picking and returns putaway       #
# parameters   :  type of counting     #
# returns      :   true or false       #

sub get_stock_count_setting :Export(:DEFAULT) {

    my ( $dbh, $type ) = @_;

    my %qry = (
        "picking" => "select pick_counting from stock_count_control",
        "returns" => "select return_counting from stock_count_control"
    );

    my $sth = $dbh->prepare($qry{$type});
    $sth->execute();

    my $row = $sth->fetchrow_arrayref();

    return $row->[0];

}

### Subroutine : set_stock_count_setting           ###
# usage        :                                  #
# description  : update the stock count settings       #
# parameters   :  picking control, returns control     #
# returns      :        #

sub set_stock_count_setting :Export() {

    my ( $dbh, $pick, $return ) = @_;

    my $qry = "update stock_count_control set pick_counting = ?, return_counting = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute($pick, $return);

}

### Subroutine : get_stock_count_summary           ###
# usage        :                                  #
# description  :        #
# parameters   :      #
# returns      :        #

sub get_stock_count_summary :Export() {

    my ( $dbh, $start, $end ) = @_;

    my $qry = "select * from stock_count_summary where start_date = ? and end_date = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute($start, $end);

    my $row = $sth->fetchrow_hashref();

    return $row;

}

### Subroutine : get_stock_count_category_summary           ###
# usage        :                                  #
# description  :        #
# parameters   :      #
# returns      :        #

sub get_stock_count_category_summary :Export() {

    my ( $dbh, $start, $end ) = @_;

    my $qry = "select scc.id as category_id, scc.category, sccs.* from stock_count_category scc left join stock_count_category_summary sccs on sccs.stock_count_category_id = scc.id and sccs.start_date = ? and sccs.end_date = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute($start, $end);

    my %data;

    while ( my $row = $sth->fetchrow_hashref() ) {
        $data{$$row{category_id}} = $row;
    }

    return \%data;

}

### Subroutine : get_category_summary                                  ###
# usage        : $hash_ptr = get_category_summary($dbh)                  #
# description  : Gets the counts for each stock count request category,  #
#                including Total, Todo & Done                            #
# parameters   : A Database Handle                                       #
# returns      : A Hash of Totals for each category                      #

sub get_category_summary :Export() {

    my ( $dbh ) = @_;

    my %data;

    # Set up counts for Manual Category in-case there arn't any Manuals created so far
    $data{5}{total} = 0;
    $data{5}{not_done} = 0;

    # get TOTAL count category figures
    # Categories B,C & D are counted per SKU
    # Categories A & Manual are just Total Counts
    my $qry = "
       SELECT scc.id,
              scc.category,
              COUNT(DISTINCT scv.variant_id) AS total_count
       FROM stock_count_category scc
       LEFT JOIN stock_count_variant scv ON scc.id = scv.stock_count_category_id
       WHERE scc.category in ('B', 'C', 'D')
       GROUP BY 1,2
      UNION
       SELECT scc.id,
              scc.category,
              COUNT(scv.variant_id) AS total_count
        FROM stock_count_category scc
        LEFT JOIN stock_count_variant scv ON scc.id = scv.stock_count_category_id
        WHERE scc.category in ('A', 'Manual')
        GROUP BY 1,2
    ";
    my $sth = $dbh->prepare($qry);
    $sth->execute();

    while ( my $row = $sth->fetchrow_hashref() ) {

        $data{$row->{id}}{total} = $row->{total_count};
        $data{$row->{id}}{not_done} = 0;
    }


    # get NOT DONE count category figures
    # Categories B,C & D are counted per SKU
    # Categories A & Manual are just Total Counts
    $qry = "
        SELECT scc.id,
               scc.category,
               COUNT(DISTINCT scv.variant_id) AS total_notdone
        FROM stock_count_category scc
        LEFT JOIN stock_count_variant scv ON scc.id = scv.stock_count_category_id
        WHERE scc.category in ('B', 'C', 'D')
        AND scv.last_count IS NULL
        GROUP BY 1,2
       UNION
        SELECT scc.id,
               scc.category,
               COUNT(scv.variant_id) AS total_notdone
        FROM stock_count_category scc
        LEFT JOIN stock_count_variant scv ON scc.id = scv.stock_count_category_id
        WHERE scc.category in ('A', 'Manual')
        AND scv.last_count IS NULL
        GROUP BY 1,2
    ";
    $sth = $dbh->prepare($qry);
    $sth->execute();

    while ( my $row = $sth->fetchrow_hashref() ) {
        $data{$row->{id}}{not_done} = $row->{total_notdone};
    }

    # Go round each key and work out the difference between total and not_done
    foreach ( keys %data ) {
        $data{$_}{done} = $data{$_}{total} - $data{$_}{not_done};
    }

    return \%data;
}

### Subroutine : get_count_summary                         ###
# usage        : $hash_ptr = get_count_summary(              #
#                     $dbh,                                  #
#                     $start,                                #
#                     $end                                   #
#                  );                                        #
# description  : Gets summary of Stock Count Requests        #
#                for a date range                            #
# parameters   : Database Handle, Start Date & End Date      #
# returns      : A Hash of Summary Data                      #

sub get_count_summary :Export() {

    my ( $dbh, $start, $end ) = @_;

    my %summary;

    $summary{counted} = 0;
    $summary{not_counted} = 0;

    # Count the Total Completed Counts
    my $qry = "SELECT COUNT(*) AS completed FROM stock_count_variant WHERE last_count IS NOT NULL";
    my $sth = $dbh->prepare($qry);
    $sth->execute();
    my $row = $sth->fetchrow_arrayref();
    $summary{counted} = $row->[0];

    # Count the Total NOT Completed Counts
    $qry = "SELECT COUNT(*) AS not_completed FROM stock_count_variant WHERE last_count IS NULL";
    $sth = $dbh->prepare($qry);
    $sth->execute();
    $row = $sth->fetchrow_arrayref();
    $summary{not_counted} = $row->[0];

    $summary{variances} = 0;
    $summary{total_expected} = 0;
    $summary{error} = 0;

    ### hash to filter out duplicates
    my %got = ();

    $qry = "
     SELECT variant_id,
            location_id,
            expected_quantity - counted_quantity AS variance,
            expected_quantity,
            group_id
     FROM stock_count
     WHERE date BETWEEN ? AND ?
     AND stock_count_status_id = 3
     ORDER BY date DESC
    ";
    $sth = $dbh->prepare($qry);
    $sth->execute($start, $end);

    while ( my $row = $sth->fetchrow_arrayref() ) {
        if (!$got{$row->[4]}){

            ## make all variances positive
            if ($row->[2] < 0){ $row->[2] = $row->[2] * -1; }

            $summary{variances} += $row->[2];
            $summary{total_expected} += $row->[3];

            $got{$row->[4]} = 1;
        }
    }

    if ($summary{total_expected} > 0){
        $summary{error} = d2(($summary{variances} / $summary{total_expected}) * 100);
    }

    return \%summary;
}

### Subroutine : get_category_list                                     ###
# usage        : $hash_ptr = get_category_list(                          #
#                     $dbh,                                              #
#                     $category_id,                                      #
#                     $sort_column                                       #
#                  );                                                    #
# description  : Gets a stock count list based on the category           #
#                passed in, also can sort by any column by passing in    #
#                the column name to sort by.                             #
# parameters   : Database Handle, Category Id, Column Name to Sort By    #
# returns      : A Pointer to a Hash containing the details of the list  #

sub get_category_list :Export() {

    my ( $dbh, $cat_id, $sort_by ) = @_;

    my $qry = "
        SELECT        v.id AS variant_id,
                        v.product_id,
                        v.product_id || '-' || sku_padding(v.size_id) AS sku,
                        v.legacy_sku,
                        d.designer,
                        pt.product_type,
                        UPPER(ss.short_name || ' ' || s.size) AS designer_size,
                        l.location,
                        q.quantity
        FROM        stock_count_variant scv,
                        variant v,
                        product p,
                        designer d,
                        product_type pt,
                        size s,
                        product_attribute pa LEFT JOIN size_scheme ss ON pa.size_scheme_id = ss.id,
                        location l,
                        quantity q
        WHERE        scv.stock_count_category_id = ?
        AND                scv.last_count IS NULL
        AND                scv.variant_id = v.id
        AND                scv.location_id = l.id
        AND                scv.variant_id = q.variant_id
        AND                scv.location_id = q.location_id
        AND                v.product_id = p.id
        AND                p.designer_id = d.id
        AND                p.id = pa.product_id
        AND                p.product_type_id = pt.id
        AND                v.designer_size_id = s.id
        AND             q.status_id = ?
    ";

    if ($sort_by){
        $qry.= "ORDER BY $sort_by ASC";
    }

    my $sth = $dbh->prepare($qry);
    $sth->execute($cat_id,$FLOW_STATUS__MAIN_STOCK__STOCK_STATUS);

    my %data;
    my $ordering = 1;

    while ( my $row = $sth->fetchrow_hashref() ) {
        $data{$ordering} = $row;

        $ordering++;
    }

    return \%data;
}

### Subroutine : get_category_name                          ###
# usage        : $scalar = get_category_name(                 #
#                     $dbh,                                   #
#                     $category_id                            #
#                  );                                         #
# description  : Gets the name of a stock count category      #
#                given the Id.                                #
# parameters   : Database Handle, Category Id                 #
# returns      : A Scalar containing the name of the Category #

sub get_category_name :Export() {
    my ( $dbh, $cat_id ) = @_;

    my $qry = "SELECT category FROM stock_count_category WHERE id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute($cat_id);

    my $row = $sth->fetchrow_arrayref();

    return $row->[0];
}

### Subroutine : is_cancelled
# usage        : if ( is_cancelled( { dbh => $dbh, type => stock_order_id, id => 12345 } ) ) {
# description  : checks if an order is cancelled
# parameters   : type => [ stock_order_id, purchase_order_id, product_id, null ], id => $id
# returns      : 1 = cancelled, 0 = live
# notes        : danger! cancelled means ALL product orders

sub is_cancelled :Export() {

    my $p = shift;

    my $qry1 = qq{
select count(id) as cancelled_count
from stock_order
where cancel = true
};

    if ( $p->{type} eq 'purchase_order_id' ) {
        $qry1 .= qq{ and purchase_order_id = ? };
    }
    elsif ( $p->{type} eq 'product_id' ) {
        $qry1 .= qq{ and product_id = ? };
    }
    else {
        $qry1 .= qq{ and id = ? };
    }

    my $sth1 = $p->{dbh}->prepare( $qry1 );

    $sth1->execute( $p->{id} );

    my $row1 = $sth1->fetchrow_hashref();

    my $qry2 = qq{
select count(id) as not_cancelled_count
from stock_order
where cancel <> true
};

    if ( $p->{type} eq 'purchase_order_id' ) {
        $qry2 .= qq{ and purchase_order_id = ? };
    }
    elsif ( $p->{type} eq 'product_id' ) {
        $qry2 .= qq{ and product_id = ? };
    }
    else {
        $qry2 .= qq{ and id = ? };
    }

    my $sth2 = $p->{dbh}->prepare( $qry2 );

    $sth2->execute( $p->{id} );

    my $row2 = $sth2->fetchrow_hashref();

#    die "cancelled_count: " . $row1->{cancelled_count} . " not_cancelled_count: " . $row2->{not_cancelled_count};

    if ( $row1->{cancelled_count} > 0 and $row2->{not_cancelled_count} == 0 ) {

        return 1;

    }
    else {

        return 0;

    }

}


### Subroutine : confirm_stock_order       ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub confirm_stock_order :Export() {

    my $p = shift;

    return 2 if $#{$p->{stock_order_ids}} < 0;

    my $ph;

    foreach my $so_id ( @{$p->{stock_order_ids}} ) {
        $ph .= " $so_id,";
    }

    chop $ph;

    my $qry = qq{
update stock_order set
confirmed = true
where id in ( $ph )
};

    my $sth = $p->{dbh}->prepare( $qry );

    $sth->execute();

    $sth->finish;

    return 1;

}

### Subroutine : unconfirm_stock_order     ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub unconfirm_stock_order :Export() {

    my $p = shift;

    return 2 if $#{$p->{stock_order_ids}} < 0;

    my $ph;

    foreach my $so_id ( @{$p->{stock_order_ids}} ) {
        $ph .= " $so_id,";
    }

    chop $ph;

    my $qry = qq{
update stock_order set
confirmed = false
where id in ( $ph )
};

    my $sth = $p->{dbh}->prepare( $qry );

    $sth->execute( );

    $sth->finish;

    return 1;

}


### Subroutine : set_stock_summary                ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub set_stock_summary :Export() {

    my ( $dbh, $args ) = @_;

    foreach my $field ( qw(product_id channel_id field value) ) {
        if (!$args->{$field}) {
            die 'No '.$field.' defined for set_stock_summary()';
        }
    }

    # create record
    my $qry = qq{ UPDATE product.stock_summary SET $args->{field} = ? WHERE product_id = ? AND channel_id = ? };
    my $sth = $dbh->prepare( $qry );
    $sth->execute( $args->{value}, $args->{product_id}, $args->{channel_id} );

    return;
}


### Subroutine : get_dead_stock_list           ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_dead_stock_list :Export() {
    my ( $dbh ) = @_;

    my $qry = qq{
            SELECT c.name as sales_channel, v.product_id, v.product_id || '-' || sku_padding(v.size_id) as sku, d.designer, pa.name, l.location, q.id as quantity_id, q.quantity, q.channel_id
            FROM quantity q
                INNER JOIN channel c ON q.channel_id = c.id
                INNER JOIN location l ON q.location_id = l.id
                INNER JOIN variant v ON q.variant_id = v.id
                INNER JOIN product p ON v.product_id = p.id
                INNER JOIN designer d ON p.designer_id = d.id
                INNER JOIN product_attribute pa ON p.id = pa.product_id
            WHERE q.status_id = $FLOW_STATUS__DEAD_STOCK__STOCK_STATUS
        };

    my $sth = $dbh->prepare($qry);
    $sth->execute();

    my %list;
    while ( my $row = $sth->fetchrow_hashref() ) {
        $list{ $row->{sales_channel} }{ $row->{quantity_id} } = $row;
    }

    return \%list;

}


### Subroutine : get_dead_stock           ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_dead_stock :Export() {
    my ( $dbh, $quantity_id ) = @_;

    my $qry = qq{
            SELECT c.name as sales_channel, v.id as variant_id, v.product_id, v.product_id || '-' || sku_padding(v.size_id) as sku, d.designer, pa.name, l.location, q.id as quantity_id, q.quantity, q.channel_id
            FROM quantity q
                INNER JOIN channel c ON q.channel_id = c.id
                INNER JOIN location l ON q.location_id = l.id
                INNER JOIN variant v ON q.variant_id = v.id
                INNER JOIN product p ON v.product_id = p.id
                INNER JOIN designer d ON p.designer_id = d.id
                INNER JOIN product_attribute pa ON p.id = pa.product_id
            WHERE q.status_id = $FLOW_STATUS__DEAD_STOCK__STOCK_STATUS
            AND q.id = ?
        };

    my $sth = $dbh->prepare($qry);
    $sth->execute( $quantity_id );

    return $sth->fetchrow_hashref();

}
sub _get_location {
    my ($schema,$args_ref)=@_;

    if (blessed($args_ref->{location})
        && $args_ref->{location}->isa('XTracker::Schema::Result::Public::Location'))
    {
        return $args_ref->{location};
    }

    return $schema->resultset('Public::Location')->get_location($args_ref);
}


=head2 get_transit_stock

Retrieves all the stock that is currently in transit.
Transit is a state in which stock will exist just after it came out of IWS/PRL
and is being prepared to go into XT

=over 4

=item Arguments: $dbh

=item Return Value: \%row_list

=back

=cut

sub get_transit_stock :Export(:DEFAULT) {
    my ( $dbh ) = @_;

    my $qry
        = qq{SELECT
                q.id AS quantity_id,
                q.variant_id,
                q.location_id,
                q.quantity,
                q.channel_id,
                qd.details AS reason,
                v.size_id,
                v.designer_size_id,
                v.legacy_sku,
                v.product_id,
                s.size,
                d.designer,
                pa.name,
                sku_padding(v.size_id) as sku_size,
                ch.name as sales_channel
            FROM quantity q
            INNER JOIN channel ch ON (q.channel_id = ch.id)
            INNER JOIN location l ON (q.location_id = l.id)
            INNER JOIN variant v ON (q.variant_id = v.id)
            INNER JOIN size s ON (v.size_id = s.id)
            INNER JOIN product p ON (v.product_id = p.id)
            INNER JOIN designer d ON (p.designer_id = d.id)
            INNER JOIN product_attribute pa ON (v.product_id = pa.product_id)
            LEFT JOIN quantity_details qd ON (qd.quantity_id = q.id)
            WHERE q.status_id in (
                $FLOW_STATUS__IN_TRANSIT_FROM_IWS__STOCK_STATUS,
                $FLOW_STATUS__IN_TRANSIT_FROM_PRL__STOCK_STATUS
            )
            GROUP BY q.id, q.variant_id, q.location_id, q.quantity, q.channel_id, qd.details, v.size_id, v.designer_size_id, v.legacy_sku, v.product_id, s.size, d.designer, pa.name, ch.name
        };

    my $sth = $dbh->prepare($qry);
    $sth->execute();

    my %list;
    my $loop = 1;

    while ( my $row = $sth->fetchrow_hashref() ) {
        $list{ $row->{sales_channel} }{ $loop } = $row;
        $loop++;
    }

    return \%list;

}

=head2 putaway_via_variant_and_quantity

Updates stock in XT and on the website in to the specified location, and
performs related logging functions. Arguments (required unless specified):

* schema => DBI schema

* channel => DBIC channel object

* variant => DBIC variant object

* location => DBIC location object

* operator => DBIC operator object - optional, defaults to /Application/

* notes => String - related notes - optional, defaults to "Stock putaway"

* quantity => Quantity of variant to putaway

* stock_action => Stock action constant, to be used in "log_stock"

* pws_stock_action => PWS (public web site) stock action, to be used in "log_pws_stock"

Updates are done inside a transaction. Throws if unsuccessful

=cut

sub putaway_via_variant_and_quantity {

    my ( %params ) = validated_hash(
        \@_,
        schema   => { does => duck_type('has resultset', [qw/resultset/] )},
        channel  => { isa => 'XTracker::Schema::Result::Public::Channel' },
        variant  => { isa => 'XTracker::Schema::Result::Public::Variant' },
        location => { isa => 'XTracker::Schema::Result::Public::Location' },
        operator => {
            isa      => 'XTracker::Schema::Result::Public::Operator',
            optional => 1,
        },
        notes           => { default => "Stock putaway" },
        quantity        => { isa => 'Num' },
        stock_action    => { isa => 'Str' },
        pws_stock_action=> { isa => 'Str' },
    );

    # Default the operator to the application if needed
    $params{'operator'} //=
        $params{'schema'}->resultset("Public::Operator")->find(
            $APPLICATION_OPERATOR_ID
        );

    # This code has been lifted in its entirity from the old XTWMS recode code,
    # which according to git was written by Paulo, updated by Natasha, and then
    # had some bits added by cwright. Don't blame me except for the indentation,
    # and comments.
    # --PSe 2012-08-27

    # The stock manager operates over a separate DB connection. We're going to
    # store a copy of it outside the main DB's transaction block so we can roll
    # it back if stuff didn't go to plan...
    my $stock_manager;

    my $error;

    try { $params{'schema'}->txn_do(sub {

        # Set the outer-scope stock_manager. This way we can roll it back if
        # something lower down dies.
        $stock_manager = XTracker::WebContent::StockManagement->new_stock_manager({
            schema     => $params{'schema'},
            channel_id => $params{'channel'}->id,
        });

        # Update the quantity table, XT's internal representation of stock levels.
        # But only bother if the quantity is > 0
        $params{'schema'}->resultset('Public::Quantity')->move_stock({
            variant  => $params{'variant'}->id,
            channel  => $params{'channel'}->id,
            quantity => $params{'quantity'},
            from     => undef,
            to => {
                location => $params{'location'},
                status   => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
            },
            log_location_as => $params{'operator'},
        }) if $params{'quantity'} > 0;

        # Write the change to XT's log
        XTracker::Database::Logging::log_stock($params{'schema'}->storage->dbh, {
            "variant_id"  => $params{'variant'}->id,
            "action"      => $params{stock_action},
            "quantity"    => $params{'quantity'},
            "operator_id" => $params{'operator'}->id,
            "notes"       => $params{'notes'},
            "channel_id"  => $params{'channel'}->id,
        });

        # Update the stock on the website, via whichever mechanism is appropriate
        $stock_manager->stock_update(
            quantity_change => $params{quantity},
            variant_id      => $params{'variant'}->id,
            skip_non_live   => 1,
            operator_id     => $params{'operator'}->id,
            notes           => $params{'notes'},
            pws_action_id   => $params{pws_stock_action},
        );

        $stock_manager->commit();

    }); } catch {
        $stock_manager->rollback();
        die $_;
    };

    return 1;
}

1;

__END__

