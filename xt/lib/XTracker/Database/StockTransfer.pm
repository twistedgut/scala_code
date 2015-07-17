package XTracker::Database::StockTransfer;

use strict;
use warnings;

use Readonly;
use Perl6::Export::Attrs;

use XTracker::Database::Utilities;
use XTracker::Constants::FromDB qw(
    :flow_status
    :return_item_status
    :shipment_class
    :shipment_item_status
    :stock_transfer_status
    :stock_transfer_type
    :variant_type
);
use NAP::DC::Barcode::Container;

### Subroutine : create_stock_transfer          ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub create_stock_transfer :Export(:DEFAULT) {

    my ( $dbh, $type, $status, $var_id, $channel_id , $info) = @_;

    my $insqry = qq{
INSERT INTO stock_transfer
VALUES ( default, current_timestamp, ?, ?, ?, ? , ?)
    };

    my $inssth = $dbh->prepare($insqry);

    $inssth->execute($type, $status, $var_id, $channel_id, $info);
    my $stock_transfer_id = last_insert_id( $dbh, 'stock_transfer_id_seq' );

    return $stock_transfer_id;
}

### Subroutine : get_stock_transfer             ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_stock_transfer :Export(:DEFAULT) {

    my ( $dbh, $id ) = @_;

    my $qry = "SELECT st.id, st.date, t.type, st.type_id, st.status_id, st.variant_id, st.channel_id, st.info, t.type, s.status, ch.business_id, ch.name AS sales_channel
                FROM stock_transfer st, stock_transfer_status s, stock_transfer_type t, channel ch
                WHERE st.id = ?
                AND st.type_id = t.id
                AND st.status_id = s.id
                AND st.channel_id = ch.id";
    my $sth = $dbh->prepare($qry);
    $sth->execute($id);

    my $data = $sth->fetchrow_hashref();

    return $data;

}


### Subroutine : set_stock_transfer_status      ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub set_stock_transfer_status :Export(:DEFAULT) {

    my ( $dbh, $id, $status ) = @_;

    my $qry
        = "UPDATE stock_transfer SET status_id = ? WHERE id = ?";

    my $sth = $dbh->prepare($qry);
    $sth->execute($status, $id);

}


### Subroutine : get_stock_transfer_returns                      ###
# usage        : $hash_ptr = get_stock_transfer_returns(           #
#                        $dbh,                                     #
#                        $args_ref = { type,id }                   #
#                   );                                             #
# description  : Gets a Channelised list of Sample Stock Returns.  #
# parameters   : Database Handle, Type = all, product_id - by      #
#                a product Id or variant_id by a variant Id,       #
#                Id - the Id of either the product or variant.     #
# returns      : A HASH with the sales channel as the key.         #

sub get_stock_transfer_returns :Export() {
    my ( $dbh, $p ) = @_;

    my $clause = {
        all        => '',
        product_id => 'AND p.id = ? limit 1',
        variant_id => 'AND v.id = ? limit 1',
    };

    my $qry = qq{
SELECT        r.rma_number,
                TO_CHAR(rsl.date, 'DD-MM-YY HH24:MI') AS date,
                ris.status,
                si.shipment_id,
                si.variant_id,
                v.product_id,
                sku_padding(v.size_id) as size_id,
                p.legacy_sku,
                ch.name AS sales_channel
FROM        return r,
                shipment s,
                link_stock_transfer__shipment lsts,
                stock_transfer st,
                channel ch,
                return_status_log rsl,
                return_item ri,
                return_item_status ris,
                shipment_item si,
                variant v,
                product p,
                location l,
                quantity q
WHERE        r.shipment_id = s.id
AND                s.id = lsts.shipment_id
AND                st.id = lsts.stock_transfer_id
AND                st.channel_id = ch.id
AND                s.shipment_class_id = 7
AND                r.return_status_id in (1, 2)
AND                r.id = rsl.return_id
AND                rsl.return_status_id = 1
AND                s.id = si.shipment_id
AND                si.variant_id = v.id
AND                si.id = ri.shipment_item_id
AND                ri.return_item_status_id = ris.id
AND                v.product_id = p.id
AND                q.status_id = $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS
AND                l.id = q.location_id
AND                q.variant_id = v.id
AND                ri.return_item_status_id != $RETURN_ITEM_STATUS__CANCELLED
$clause->{$p->{type}}
ORDER BY rsl.date asc
};

    my $sth = $dbh->prepare( $qry );

    $p->{type} eq 'all' ? $sth->execute() : $sth->execute( $p->{id} );

    return results_channel_list($sth);
}


### Subroutine : get_pending_stock_transfers                     ###
# usage        : $hash_ptr = get_pending_stock_transfers(          #
#                      $dbh                                        #
#                   );                                             #
# description  : Get the a list of pending Stock Requests.         #
# parameters   : Database Handle                                   #
# returns      : A Channelised HASH of HASHes                      #

sub get_pending_stock_transfers :Export() {

 my ( $dbh ) = @_;

    my $qry = qq{
SELECT        DISTINCT st.id,
                TO_CHAR(st.date, 'DD-MM-YYYY  HH24:MI') AS date,
                v.product_id,
                sku_padding(v.size_id) as size_id,
                v.legacy_sku,
                dis.status,
                v.id AS variant_id,
                stt.type AS reason,
                d.designer,
                CASE WHEN pch.upload_date IS NOT NULL THEN TO_CHAR(pch.upload_date, 'DD-MM-YYYY') ELSE '' END AS upload_date,
                ch.name AS sales_channel,
                info
FROM stock_transfer_type stt,
                stock_transfer st
                        LEFT JOIN stock_order_item soi ON st.variant_id = soi.variant_id
                        LEFT JOIN link_delivery_item__stock_order_item ldi_soi ON soi.id = ldi_soi.stock_order_item_id
                        LEFT JOIN delivery_item di ON ldi_soi.delivery_item_id = di.id
                        LEFT JOIN delivery_item_status dis ON di.status_id = dis.id,
                variant v,
                product p,
        product_channel pch,
                designer d,
                channel ch
WHERE st.type_id != $STOCK_TRANSFER_TYPE__SAMPLE_RETURN
AND st.status_id = $STOCK_TRANSFER_STATUS__REQUESTED
AND st.variant_id = v.id
AND st.type_id = stt.id
AND v.product_id = p.id
AND p.designer_id = d.id
AND st.channel_id = ch.id
AND p.id = pch.product_id
AND ch.id = pch.channel_id
};

    my $sth = $dbh->prepare($qry);
    $sth->execute();

    my %data;

    while ( my $row = $sth->fetchrow_hashref() ) {
        $data{ $$row{sales_channel} }{ $$row{id} } = $row;
    }

    return \%data;
}


### Subroutine : get_stock_transfer_shipments                         ###
# usage        : $hash_ptr = get_stock_transfer_shipments(              #
#                       $dbh,                                           #
#                       $args_ref = { type }                            #
#                   );                                                  #
# description  : Returns a Channelised HASH of stock transfer shipments #
#                for either Main Stock or Samples.                      #
# parameters   : Database Handle, Type = Vendor - to list Main Stock    #
#                any other type will list Sample stock.                 #
# returns      : Channelised HASH of HASHes.                            #

sub get_stock_transfer_shipments :Export() {

    my ( $dbh, $args_ref ) = @_;

    if (!defined $args_ref->{status_list}) {
        die "No 'status_list' passed into get_stock_transfer_shipments";
    }

    my $vars = join(",", map { '?' } @{$args_ref->{status_list}});

    my $qry = qq{
SELECT        s.id,
                TO_CHAR(s.date, 'DD-MM-YYYY  HH24:MI') AS date,
                v.legacy_sku,
                v.product_id,
                sku_padding(v.size_id) as size_id,
        si.container_id,
                sis.status,
                s.outward_airway_bill,
                d.designer,
                p.note,
                p.style_number AS name,
                vt.type AS variant_type,
                stt.type AS reason,
                ch.name AS sales_channel,
                ch.id AS channel_id,
                pc.live,
                st.info,
                TO_CHAR(pc.upload_date, 'DD-MM-YYYY') AS upload_date
FROM        shipment s,
                shipment_item si,
                variant v,
                product p,
                designer d,
                variant_type vt,
                shipment_item_status sis,
                link_stock_transfer__shipment lsts,
                stock_transfer st,
                stock_transfer_type stt,
                channel ch,
                product_channel pc
WHERE        s.shipment_class_id = $SHIPMENT_CLASS__TRANSFER_SHIPMENT
AND                s.shipment_status_id IN ( $vars )
AND                s.delivered IS FALSE
AND                s.id = si.shipment_id
AND                si.shipment_item_status_id = sis.id
AND                si.variant_id = v.id
AND                s.id = lsts.shipment_id
AND                st.id = lsts.stock_transfer_id
AND                st.type_id = stt.id
AND                v.product_id = p.id
AND                p.designer_id = d.id
AND                v.type_id = vt.id
AND                st.channel_id = ch.id
AND                p.id = pc.product_id
AND                ch.id = pc.channel_id
AND                v.type_id = $VARIANT_TYPE__STOCK
ORDER BY s.id
};

    my $sth = $dbh->prepare($qry);

    $sth->execute(@{$args_ref->{status_list}});

    my %shipments;
    while ( my $row = $sth->fetchrow_hashref() ) {

        # make sure we use instance of Barcode class as container
        $row->{container_id} &&= NAP::DC::Barcode::Container->new_from_id(
            $row->{container_id},
        );

        $shipments{ $row->{sales_channel} } //= [];
        push @{ $shipments{ $row->{sales_channel} } }, $row;
    }

    return \%shipments;
}

1;
