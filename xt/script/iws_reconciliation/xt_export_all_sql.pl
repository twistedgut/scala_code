#!/opt/xt/xt-perl/bin/perl

use strict;
use warnings;

use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );

use XTracker::Constants::FromDB qw(
    :flow_status
    :stock_order_type
    :stock_process_type
    :stock_process_status
    :return_item_status
    :shipment_class
    :product_channel_transfer_status
    :shipment_item_status
);

# we rely on the data we're generating being well-behaved,
# as far as CSV-ness is concerned
print qq{
SELECT channel || ',' || sku || ',' || status || ',' || unavailable || ',' || allocated || ',' || available
FROM (
    SELECT channel,
           sku,
           status,
           SUM(unavailable_returns + unavailable_quantities)  AS unavailable,
           SUM(allocated_pre_picked + allocated_post_picked)  AS allocated,
           SUM(available - allocated_pre_picked)              AS available
    FROM (

        -- unavailable goods in
        SELECT UPPER(c.name) AS channel,
               v.product_id || '-' || sku_padding(v.size_id) AS sku,
               CASE
               WHEN sp.type_id = $STOCK_PROCESS_TYPE__FAULTY                 THEN 'FAULTY'
               WHEN sp.type_id = $STOCK_PROCESS_TYPE__DEAD                   THEN 'DEAD'
               -- XXX TODO check which pieces we actually send pre_advice for
               WHEN sp.type_id IN ($STOCK_PROCESS_TYPE__RTV,
                                   $STOCK_PROCESS_TYPE__RTV_NON_DASH_FAULTY,
                                   $STOCK_PROCESS_TYPE__RTV_CUSTOMER_REPAIR,
                                   $STOCK_PROCESS_TYPE__RTV_FIXED)           THEN 'RTV'
               WHEN so.type_id IN ($STOCK_ORDER_TYPE__REPLACEMENT,
                                   $STOCK_ORDER_TYPE__MAIN)                  THEN 'MAIN'
               ELSE UPPER(spt.type)
               END AS status,
               SUM(sp.quantity) AS unavailable_quantities,
               0 AS unavailable_returns,
               0 AS available,
               0   AS allocated_pre_picked,
               0   AS allocated_post_picked
          FROM stock_process sp
          JOIN stock_process_type spt ON sp.type_id=spt.id
          JOIN link_delivery_item__stock_order_item lds ON sp.delivery_item_id=lds.delivery_item_id
                                                       AND sp.status_id IN (
                                                           $STOCK_PROCESS_STATUS__APPROVED,
                                                           $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED
                                                       )
                                                       AND sp.complete=FALSE
          JOIN stock_order_item si ON lds.stock_order_item_id=si.id
          JOIN variant v           ON si.variant_id=v.id
          JOIN stock_order so      ON si.stock_order_id=so.id
          JOIN purchase_order po   ON so.purchase_order_id=po.id
          JOIN channel c           ON po.channel_id=c.id
         WHERE so.type_id != $STOCK_ORDER_TYPE__SAMPLE -- vendor samples, IWS doesn't see these
         GROUP BY channel,
                  sku,
                  status,
                  unavailable_returns,
                  available,
                  allocated_pre_picked,
                  allocated_post_picked

    UNION

        -- unavailable voucher goods in
        SELECT UPPER(c.name) AS channel,
               v.voucher_product_id || '-' || sku_padding(999) AS sku,
               CASE
               WHEN sp.type_id = $STOCK_PROCESS_TYPE__FAULTY                 THEN 'FAULTY'
               WHEN sp.type_id = $STOCK_PROCESS_TYPE__DEAD                   THEN 'DEAD'
               -- XXX TODO check which pieces we actually send pre_advice for
               WHEN sp.type_id IN ($STOCK_PROCESS_TYPE__RTV,
                                   $STOCK_PROCESS_TYPE__RTV_NON_DASH_FAULTY,
                                   $STOCK_PROCESS_TYPE__RTV_CUSTOMER_REPAIR,
                                   $STOCK_PROCESS_TYPE__RTV_FIXED)           THEN 'RTV'
               WHEN so.type_id IN ($STOCK_ORDER_TYPE__REPLACEMENT,
                                   $STOCK_ORDER_TYPE__MAIN)                  THEN 'MAIN'
               ELSE UPPER(spt.type)
               END AS status,
               SUM(sp.quantity) AS unavailable_quantities,
               0 AS unavailable_returns,
               0 AS available,
               0   AS allocated_pre_picked,
               0   AS allocated_post_picked
          FROM stock_process sp
          JOIN stock_process_type spt ON sp.type_id=spt.id
          JOIN link_delivery_item__stock_order_item lds ON sp.delivery_item_id=lds.delivery_item_id
                                                       AND sp.status_id IN (
                                                           $STOCK_PROCESS_STATUS__APPROVED,
                                                           $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED
                                                       )
                                                       AND sp.complete=FALSE
          JOIN stock_order_item si ON lds.stock_order_item_id=si.id
          JOIN voucher.variant v   ON si.voucher_variant_id=v.id
          JOIN stock_order so      ON si.stock_order_id=so.id
          JOIN voucher.purchase_order po ON so.purchase_order_id=po.id
          JOIN channel c           ON po.channel_id=c.id
         WHERE so.type_id != $STOCK_ORDER_TYPE__SAMPLE -- vendor samples, IWS doesn't see these
         GROUP BY channel,
                  sku,
                  status,
                  unavailable_returns,
                  available,
                  allocated_pre_picked,
                  allocated_post_picked


    UNION

        -- unavailable returns
        SELECT UPPER(c.name) AS channel,
               v.product_id || '-' || sku_padding(v.size_id) AS sku,
               CASE
               WHEN ri.return_item_status_id IN (
                        $RETURN_ITEM_STATUS__FAILED_QC__DASH__AWAITING_DECISION,
                        $RETURN_ITEM_STATUS__FAILED_QC__DASH__REJECTED,
                        $RETURN_ITEM_STATUS__FAILED_QC__DASH__ACCEPTED
               ) THEN 'FAULTY'
               ELSE   'MAIN'
               END AS status,
               0 AS unavailable_quantities,
               COUNT(ri.id) AS unavailable_returns,
               0 AS available,
               0 AS allocated_pre_picked,
               0 AS allocated_post_picked
          FROM link_delivery_item__return_item ldr
          JOIN return_item ri ON ldr.return_item_id=ri.id
                             AND ri.return_item_status_id IN (
                                     $RETURN_ITEM_STATUS__FAILED_QC__DASH__ACCEPTED,
                                     $RETURN_ITEM_STATUS__FAILED_QC__DASH__REJECTED,
                                     $RETURN_ITEM_STATUS__FAILED_QC__DASH__AWAITING_DECISION,
                                     $RETURN_ITEM_STATUS__PASSED_QC
                             )
          JOIN variant v ON ri.variant_id=v.id
          JOIN channel c ON c.id=get_product_channel_id(v.product_id)
         GROUP BY channel,
                  sku,
                  status,
                  available,
                  unavailable_quantities,
                  allocated_pre_picked,
                  allocated_post_picked
    UNION
    (
        -- available product stock
        SELECT UPPER(c.name) AS channel,
               v.product_id || '-' || sku_padding(v.size_id) AS sku,
               CASE
               WHEN fs.id =   $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS          THEN 'MAIN'
               WHEN fs.id =   $FLOW_STATUS__DEAD_STOCK__STOCK_STATUS          THEN 'DEAD'
               WHEN fs.id IN ($FLOW_STATUS__QUARANTINE__STOCK_STATUS,
                              $FLOW_STATUS__RTV_GOODS_IN__STOCK_STATUS)       THEN 'FAULTY'
               WHEN fs.id IN ($FLOW_STATUS__RTV_TRANSFER_PENDING__STOCK_STATUS,
                              $FLOW_STATUS__RTV_PROCESS__STOCK_STATUS,
                              $FLOW_STATUS__RTV_WORKSTATION__STOCK_STATUS)    THEN 'RTV'
               ELSE UPPER(fs.name)
               END AS status,
               0 AS unavailable_quantities,
               0 AS unavailable_returns,
               SUM(q.quantity) AS available,
               0   AS allocated_pre_picked,
               0   AS allocated_post_picked
          FROM variant v
          JOIN quantity q     ON v.id=q.variant_id
          JOIN flow.status fs ON fs.id=q.status_id
          JOIN channel c      ON q.channel_id=c.id
          JOIN location l     ON q.location_id=l.id
         -- IWS does not do samples in phase 1, nor faulty, nor RTV
         WHERE fs.id IN ($FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
                         $FLOW_STATUS__DEAD_STOCK__STOCK_STATUS)
           AND (
                 SUBSTRING(l.location FROM 1 FOR 2) IN ('01','02')
                 OR l.location = 'IWS'
               )
           AND l.location not in ('011U999A','011U999B','011U999C')
         GROUP BY channel,
                  sku,
                  status,
                  unavailable_quantities,
                  unavailable_returns,
                  allocated_pre_picked,
                  allocated_post_picked

    UNION ALL

        -- available gift vouchers
        SELECT UPPER(c.name) AS channel,
               v.voucher_product_id || '-999' AS sku,
               'MAIN' AS status,
               0 AS unavailable_quantities,
               0 AS unavailable_returns,
               SUM(q.quantity) AS available,
               0   AS allocated_pre_picked,
               0   AS allocated_post_picked
          FROM voucher.variant v
          JOIN quantity q     ON v.id=q.variant_id
          JOIN flow.status fs ON fs.id=q.status_id
          JOIN channel c      ON q.channel_id=c.id
         GROUP BY channel,
                  sku,
                  status,
                  unavailable_quantities,
                  unavailable_returns,
                  allocated_pre_picked,
                  allocated_post_picked
    )
    UNION
    (
        -- allocated pre-picked product stock
        SELECT UPPER(c.name) AS channel,
               v.product_id || '-' || sku_padding(v.size_id) AS sku,
               CASE s.shipment_class_id
               WHEN $SHIPMENT_CLASS__RTV_SHIPMENT THEN 'RTV'
               ELSE                                    'MAIN' -- we ship samples from main
               END AS status,
               0 AS unavailable_quantities,
               0 AS unavailable_returns,
               0 AS available,
               COUNT(si.id) AS allocated_pre_picked,
               0 AS allocated_post_picked
         FROM shipment_item si
            JOIN shipment s                ON si.shipment_id=s.id
            JOIN variant v                 ON si.variant_id=v.id
            LEFT OUTER JOIN link_stock_transfer__shipment as lsts on s.id = lsts.shipment_id
            LEFT OUTER JOIN stock_transfer st         ON lsts.stock_transfer_id=st.id
            LEFT OUTER JOIN link_orders__shipment los ON si.shipment_id=los.shipment_id
            LEFT OUTER JOIN orders o                  ON los.orders_id=o.id
            JOIN channel c                 ON coalesce(o.channel_id, st.channel_id) = c.id
         WHERE si.shipment_item_status_id IN (
               $SHIPMENT_ITEM_STATUS__SELECTED
         )
         AND s.shipment_class_id != $SHIPMENT_CLASS__RTV_SHIPMENT
         GROUP BY channel,
                  sku,
                  status,
                  unavailable_quantities,
                  unavailable_returns,
                  available,
                  allocated_post_picked
    UNION ALL

        -- allocated pre-picked voucher stock
        SELECT UPPER(c.name) AS channel,
               v.voucher_product_id || '-999' AS sku,
               'MAIN' AS status,
               0 AS unavailable_quantities,
               0 AS unavailable_returns,
               0 AS available,
               COUNT(si.id) AS allocated_pre_picked,
               0 AS allocated_post_picked
          FROM shipment_item si
          JOIN shipment s                ON si.shipment_id=s.id
          JOIN voucher.variant v         ON si.variant_id=v.id
          JOIN link_orders__shipment los ON si.shipment_id=los.shipment_id
          JOIN orders o                  ON los.orders_id=o.id
          JOIN channel c                 ON o.channel_id=c.id
         WHERE si.shipment_item_status_id IN (
             $SHIPMENT_ITEM_STATUS__SELECTED
        )
         AND s.shipment_class_id != $SHIPMENT_CLASS__RTV_SHIPMENT
         GROUP BY channel,
                  sku,
                  status,
                  unavailable_quantities,
                  unavailable_returns,
                  available,
                  allocated_post_picked
    )
    UNION
    (
        -- allocated post-picked product stock
        SELECT UPPER(c.name) AS channel,
               v.product_id || '-' || sku_padding(v.size_id) AS sku,
               CASE s.shipment_class_id
               WHEN $SHIPMENT_CLASS__RTV_SHIPMENT THEN 'RTV'
               ELSE                                    'MAIN' -- we ship samples from main
               END AS status,
               0 AS unavailable_quantities,
               0 AS unavailable_returns,
               0 AS available,
               0 AS allocated_pre_picked,
               COUNT(si.id) AS allocated_post_picked
          FROM shipment_item si
          JOIN shipment s                ON si.shipment_id=s.id
          JOIN variant v                 ON si.variant_id=v.id
          LEFT OUTER JOIN link_stock_transfer__shipment as lsts on s.id = lsts.shipment_id
          LEFT OUTER JOIN stock_transfer st         ON lsts.stock_transfer_id=st.id
          LEFT OUTER JOIN link_orders__shipment los ON si.shipment_id=los.shipment_id
          LEFT OUTER JOIN orders o                  ON los.orders_id=o.id
          JOIN channel c                 ON coalesce(o.channel_id, st.channel_id) = c.id
         WHERE si.shipment_item_status_id IN (
             $SHIPMENT_ITEM_STATUS__PICKED,
             $SHIPMENT_ITEM_STATUS__CANCEL_PENDING,
             $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION
        )
         AND s.shipment_class_id != $SHIPMENT_CLASS__RTV_SHIPMENT
         GROUP BY channel,
                  sku,
                  status,
                  unavailable_quantities,
                  unavailable_returns,
                  available,
                  allocated_pre_picked

    UNION ALL

        -- allocated post-picked voucher stock
        SELECT UPPER(c.name) AS channel,
               v.voucher_product_id || '-999' AS sku,
               'MAIN' AS status,
               0 AS unavailable_quantities,
               0 AS unavailable_returns,
               0 AS available,
               0 AS allocated_pre_picked,
               COUNT(si.id) AS allocated_post_picked
          FROM shipment_item si
          JOIN shipment s                ON si.shipment_id=s.id
          JOIN voucher.variant v         ON si.variant_id=v.id
          JOIN link_orders__shipment los ON si.shipment_id=los.shipment_id
          JOIN orders o                  ON los.orders_id=o.id
          JOIN channel c                 ON o.channel_id=c.id
         WHERE si.shipment_item_status_id IN (
             $SHIPMENT_ITEM_STATUS__PICKED,
             $SHIPMENT_ITEM_STATUS__CANCEL_PENDING,
             $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION
        )
         AND s.shipment_class_id != $SHIPMENT_CLASS__RTV_SHIPMENT
         GROUP BY channel,
                  sku,
                  status,
                  unavailable_quantities,
                  unavailable_returns,
                  available,
                  allocated_pre_picked
    )
    ) AS foo
WHERE status IN ('MAIN','DEAD')
GROUP BY channel,
         sku,
         status
ORDER BY sku,
         channel
) AS bar
     ;
};

1;

__END__

=head1 Introduction

This script creates a file of XTracker stock information,
intended to be inhaled by the WMS/XT reconciliation tool.

=head2 Output format

Its output is a series of records of tab-separated values,
with each record terminated by a newline.

Every record has a value in each column, and the columns are:

=over 4

=item channel

=item SKU

=item status

=item count of unavailable items

=item count of allocated items

=item count of available items

=back

Each channel/SKU/status combination occurs only once in the output,
and the records are guaranteed to be sorted by SKU in increasing
numerical order.

This output format should be congruent with the equivalent
export from WMS (although that might not be sorted).

=cut




