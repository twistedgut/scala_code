package XTracker::Schema::Result::Public::VirtualProductSaleableQuantity;
use strict;
use warnings;
use base qw/DBIx::Class::Core/;

# This is a virtual view to allow running arbitrary SQL through a custom resultsource.
# Because it needs some bind values, you probably shouldn't be using it directly - it
# is called by the method:
# XTracker::Schema::Result::Public::Product::get_saleable_item_quantity(), so
# use that instead.

use XTracker::Constants::FromDB qw(
    :flow_status
    :reservation_status
    :shipment_item_status
);

__PACKAGE__->table_class('DBIx::Class::ResultSource::View');

__PACKAGE__->table('NONE'); # seems silly that you have to provide a table name
__PACKAGE__->add_columns(qw/sales_channel
                            variant_id
                            quantity
                        /);

# do not attempt to deploy() this view
__PACKAGE__->result_source_instance->is_virtual(1);

# calculated as : total stock - (reservations + ordered not picked)
__PACKAGE__->result_source_instance->view_definition(qq[
    SELECT sales_channel, variant_id, sum(quantity) AS quantity
        FROM (

            SELECT ch.name AS sales_channel, v.id AS variant_id, 0 AS quantity
            FROM super_variant v, channel ch
            WHERE v.product_id = ?
            GROUP BY ch.name, variant_id

            UNION ALL

            SELECT ch.name AS sales_channel, q.variant_id, sum( q.quantity ) AS quantity
            FROM quantity q, super_variant v, channel ch
            WHERE q.status_id = $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS
                AND q.variant_id = v.id
                AND v.product_id = ?
                AND q.channel_id = ch.id
            GROUP BY ch.name, q.variant_id

            UNION ALL

            SELECT ch.name AS sales_channel, r.variant_id, -count(r.*) AS quantity
            FROM reservation r, super_variant v, channel ch
            WHERE r.variant_id = v.id
                AND v.product_id = ?
                AND r.status_id = $RESERVATION_STATUS__UPLOADED
                AND r.channel_id = ch.id
            GROUP BY ch.name, r.variant_id

            UNION ALL

            SELECT ch.name AS sales_channel, v.id AS variant_id, -count(si.*) AS quantity
            FROM shipment_item si, super_variant v, shipment s, link_orders__shipment link, orders o, channel ch
            WHERE (si.variant_id = v.id or si.voucher_variant_id = v.id )
                AND v.product_id = ?
                AND si.shipment_item_status_id IN ($SHIPMENT_ITEM_STATUS__NEW, $SHIPMENT_ITEM_STATUS__SELECTED)
                AND si.shipment_id = s.id
                AND s.id = link.shipment_id
                AND link.orders_id = o.id
                AND o.channel_id = ch.id
            GROUP BY ch.name, v.id

            UNION ALL

            SELECT ch.name AS sales_channel, v.id AS variant_id, -count(si.*) AS quantity
            FROM shipment_item si, super_variant v, shipment s, link_stock_transfer__shipment link, stock_transfer st, channel ch
            WHERE (si.variant_id = v.id or si.voucher_variant_id = v.id )
                AND v.product_id = ?
                AND si.shipment_item_status_id IN ($SHIPMENT_ITEM_STATUS__NEW, $SHIPMENT_ITEM_STATUS__SELECTED)
                AND si.shipment_id = s.id
                AND s.id = link.shipment_id
                AND link.stock_transfer_id = st.id
                AND st.channel_id = ch.id
            GROUP BY ch.name, v.id
        ) AS saleable
    GROUP BY sales_channel, variant_id
]);

1;
