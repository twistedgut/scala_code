package XTracker::Database::OrderProcess;

use strict;
use warnings;
use Carp;

use Perl6::Export::Attrs;

use XTracker::Constants::FromDB qw/
    :shipment_item_status
    :reservation_status
/;
use XTracker::Database;
use XTracker::Database::Utilities;
use XTracker::DBEncode 'decode_db';

sub get_allocated_details :Export() {

    my ( $dbh, $args_ref ) = @_;

    my $type = $args_ref->{type};
    my $id   = $args_ref->{id};

    my %clause = ( 'product_id' => ' in ( select id from super_variant where product_id = ? )',
                   'variant_id' => ' = ?',
                 );

    ### orders
    my $qry = "select to_char(s.date, 'DD-MM-YYYY') as date,
                      to_char(s.date, 'HH24:MI') as time,
                      to_char(s.date, 'YYYYMMDDHH24:MI') as datesort,
                      v.product_id, v.legacy_sku, sku_padding(v.size_id) as size_id,
                      s.id as shipment_id,
                      sis.status as status,
                      los.orders_id,
                      oa.first_name,
                      oa.last_name,
                      'System' as operator, si.id as item_id,
                      c.name as sales_channel
              from shipment s, shipment_item si,
                    link_orders__shipment los,
                    variant v, shipment_item_status sis, order_address oa,
                    orders o, channel c
               where si.shipment_item_status_id IN (
                     $SHIPMENT_ITEM_STATUS__NEW,
                     $SHIPMENT_ITEM_STATUS__SELECTED,
                     $SHIPMENT_ITEM_STATUS__PICKED,
                     $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION
               )
               and si.variant_id $clause{$type}
               and si.variant_id = v.id
               and si.shipment_item_status_id = sis.id
               and si.shipment_id = s.id
               and s.shipment_address_id = oa.id
               and s.id = los.shipment_id
               and o.id = los.orders_id
               and o.channel_id = c.id
               union
               -- Vouchers
               select to_char(s.date, 'DD-MM-YYYY') as date,
                      to_char(s.date, 'HH24:MI') as time,
                      to_char(s.date, 'YYYYMMDDHH24:MI') as datesort,
                      v.product_id, v.legacy_sku, sku_padding(v.size_id) as size_id,
                      s.id as shipment_id,
                      sis.status as status,
                      los.orders_id,
                      oa.first_name,
                      oa.last_name,
                      'System' as operator, si.id as item_id,
                      c.name as sales_channel
              from shipment s, shipment_item si,
                    link_orders__shipment los,
                    super_variant v, shipment_item_status sis, order_address oa,
                    orders o, channel c
               where si.shipment_item_status_id IN (
                     $SHIPMENT_ITEM_STATUS__NEW,
                     $SHIPMENT_ITEM_STATUS__SELECTED,
                     $SHIPMENT_ITEM_STATUS__PICKED
               )
               and si.voucher_variant_id $clause{$type}
               and si.voucher_variant_id = v.id
               and si.shipment_item_status_id = sis.id
               and si.shipment_id = s.id
               and s.shipment_address_id = oa.id
               and s.id = los.shipment_id
               and o.id = los.orders_id
               and o.channel_id = c.id
               union
               select to_char(r.date_uploaded, 'DD-MM-YYYY') as date,
                      to_char(r.date_uploaded, 'HH24:MI') as time,
                      to_char(r.date_uploaded, 'YYYYMMDDHH24:MI') as datesort,
                      v.product_id, v.legacy_sku, sku_padding(v.size_id) as size_id,
                      0 as shipment_id,
                      'Reserved' as status,
                      0 as orders_id,
                      c.first_name,
                      c.last_name,
                      op.name as operator, 0 as item_id,
                      ch.name as sales_channel
               from reservation r, variant v, operator op, customer c,channel ch
               where r.variant_id $clause{$type}
               and r.status_id = $RESERVATION_STATUS__UPLOADED
               and r.variant_id = v.id
               and r.operator_id = op.id
               and r.customer_id = c.id
               and r.channel_id = ch.id
               union
               select to_char(ci.date, 'DD-MM-YYYY') as date,
                      to_char(ci.date, 'HH24:MI') as time,
                      to_char(ci.date, 'YYYYMMDDHH24:MI') as datesort,
                      v.product_id, v.legacy_sku, sku_padding(v.size_id) as size_id,
                      s.id as shipment_id,
                      sis.status as status,
                      los.orders_id,
                      oa.first_name,
                      oa.last_name,
                      op.name as operator, si.id as item_id,
                      c.name as sales_channel
               from cancelled_item ci, variant v, shipment s,
                    link_orders__shipment los,
                    shipment_item si, shipment_item_status sis, shipment_item_status_log sisl, operator op, order_address oa,
                    orders o, channel c
               where si.variant_id $clause{$type}
               and si.shipment_item_status_id = $SHIPMENT_ITEM_STATUS__CANCEL_PENDING
               and si.id = ci.shipment_item_id
               and si.shipment_id = s.id
               and s.id = los.shipment_id
               and o.id = los.orders_id
               and o.channel_id = c.id
               and s.shipment_address_id = oa.id
               and si.variant_id = v.id
               and si.id = sisl.shipment_item_id
               and sisl.shipment_item_status_id = sis.id
               and sisl.shipment_item_status_id = $SHIPMENT_ITEM_STATUS__CANCEL_PENDING
               and sisl.operator_id = op.id
               -- Vouchers
               union
               select to_char(ci.date, 'DD-MM-YYYY') as date,
                      to_char(ci.date, 'HH24:MI') as time,
                      to_char(ci.date, 'YYYYMMDDHH24:MI') as datesort,
                      v.product_id, v.legacy_sku, sku_padding(v.size_id) as size_id,
                      s.id as shipment_id,
                      sis.status as status,
                      los.orders_id,
                      oa.first_name,
                      oa.last_name,
                      op.name as operator, si.id as item_id,
                      c.name as sales_channel
               from cancelled_item ci, super_variant v, shipment s,
                    link_orders__shipment los,
                    shipment_item si, shipment_item_status sis, shipment_item_status_log sisl, operator op, order_address oa,
                    orders o, channel c
               where si.voucher_variant_id $clause{$type}
               and si.shipment_item_status_id = $SHIPMENT_ITEM_STATUS__CANCEL_PENDING
               and si.id = ci.shipment_item_id
               and si.shipment_id = s.id
               and s.id = los.shipment_id
               and o.id = los.orders_id
               and o.channel_id = c.id
               and s.shipment_address_id = oa.id
               and si.voucher_variant_id = v.id
               and si.id = sisl.shipment_item_id
               and sisl.shipment_item_status_id = sis.id
               and sisl.shipment_item_status_id = $SHIPMENT_ITEM_STATUS__CANCEL_PENDING
               and sisl.operator_id = op.id";


    my $sth = $dbh->prepare($qry);
    $sth->execute( $id, $id, $id, $id, $id );

    my $results = results_channel_list($sth);
    for my $sales_channel (keys %$results) {
        for my $result (@{ $results->{$sales_channel} }) {
            $result->{$_} = decode_db($result->{$_}) for (qw(
                first_name
                last_name
            ));
        }
    }
    return $results;
}

1;
