BEGIN;

/*DROP views in use*/
DROP VIEW IF EXISTS njiv_1st_sold_out CASCADE;
DROP VIEW IF EXISTS njiv_1st_sold_out_outnet CASCADE;
DROP VIEW IF EXISTS njiv_cancellations CASCADE;
DROP VIEW IF EXISTS njiv_cancellations_outnet CASCADE;
DROP VIEW IF EXISTS njiv_daily_totals CASCADE;
DROP VIEW IF EXISTS njiv_daily_totals_outnet CASCADE;
DROP VIEW IF EXISTS njiv_daily_totals_2 CASCADE;
DROP VIEW IF EXISTS njiv_daily_totals_2_outnet CASCADE;
DROP VIEW IF EXISTS njiv_daily_totals_currency_2 CASCADE;
DROP VIEW IF EXISTS njiv_daily_totals_currency_2_outnet CASCADE;
DROP VIEW IF EXISTS njiv_daily_ukl CASCADE;
DROP VIEW IF EXISTS njiv_daily_ukl_outnet CASCADE;
DROP VIEW IF EXISTS njiv_ftbc_gross_orders CASCADE;
DROP VIEW IF EXISTS njiv_ftbc_gross_orders_outnet CASCADE;
DROP VIEW IF EXISTS njiv_ftbc_gross_sales CASCADE;
DROP VIEW IF EXISTS njiv_ftbc_gross_sales_outnet CASCADE;
DROP VIEW IF EXISTS njiv_ftbc_merch_cancellations CASCADE;
DROP VIEW IF EXISTS njiv_ftbc_merch_cancellations_outnet CASCADE;
DROP VIEW IF EXISTS njiv_ftbc_merch_returns CASCADE;
DROP VIEW IF EXISTS njiv_ftbc_merch_returns_outnet CASCADE;
DROP VIEW IF EXISTS njiv_gross_order_totals_currency CASCADE;
DROP VIEW IF EXISTS njiv_gross_order_totals_currency_outnet CASCADE;
DROP VIEW IF EXISTS njiv_master_free_stock CASCADE;
DROP VIEW IF EXISTS njiv_master_free_stock_outnet CASCADE;
DROP VIEW IF EXISTS njiv_master_product_attributes CASCADE;
DROP VIEW IF EXISTS njiv_master_product_attributes_outnet CASCADE;
DROP VIEW IF EXISTS njiv_merch_sales_season CASCADE;
DROP VIEW IF EXISTS njiv_merch_sales_season_outnet CASCADE;
DROP VIEW IF EXISTS njiv_merchandising CASCADE;
DROP VIEW IF EXISTS njiv_merchandising_outnet CASCADE;
DROP VIEW IF EXISTS njiv_net_sales CASCADE;
DROP VIEW IF EXISTS njiv_net_sales_outnet CASCADE;
DROP VIEW IF EXISTS njiv_orders CASCADE;
DROP VIEW IF EXISTS njiv_orders_outnet CASCADE;
DROP VIEW IF EXISTS njiv_preorder_returns_dispatchdate CASCADE;
DROP VIEW IF EXISTS njiv_preorder_returns_dispatchdate_outnet CASCADE;
DROP VIEW IF EXISTS njiv_prod_orders CASCADE;
DROP VIEW IF EXISTS njiv_prod_orders_outnet CASCADE;
DROP VIEW IF EXISTS njiv_product_ordered_qty CASCADE;
DROP VIEW IF EXISTS njiv_product_ordered_qty_outnet CASCADE;
DROP VIEW IF EXISTS njiv_pws_log_stock_reporting CASCADE;
DROP VIEW IF EXISTS njiv_pws_log_stock_reporting_outnet CASCADE;
DROP VIEW IF EXISTS njiv_returns CASCADE;
DROP VIEW IF EXISTS njiv_returns_outnet CASCADE;
DROP VIEW IF EXISTS njiv_rm_cancellations CASCADE;
DROP VIEW IF EXISTS njiv_rm_cancellations_outnet CASCADE;
DROP VIEW IF EXISTS njiv_rm_daily_totals_currency CASCADE;
DROP VIEW IF EXISTS njiv_rm_daily_totals_currency_outnet CASCADE;
DROP VIEW IF EXISTS njiv_rm_daily_totals_currency_dispatch CASCADE;
DROP VIEW IF EXISTS njiv_rm_daily_totals_currency_dispatch_outnet CASCADE;
DROP VIEW IF EXISTS njiv_rm_returns CASCADE;
DROP VIEW IF EXISTS njiv_rm_returns_outnet CASCADE;
DROP VIEW IF EXISTS njiv_stock_by_location CASCADE;
DROP VIEW IF EXISTS njiv_stock_by_location_outnet CASCADE;
DROP VIEW IF EXISTS njiv_variant_free_stock CASCADE;
DROP VIEW IF EXISTS njiv_variant_free_stock_outnet CASCADE;
DROP VIEW IF EXISTS vw_sale_orders CASCADE;
DROP VIEW IF EXISTS vw_sale_orders_outnet CASCADE;
DROP VIEW IF EXISTS njiv_master_product_attributes_orig CASCADE;


/*Drop suspected unused views - 1st Time */
DROP VIEW IF EXISTS njiv_cancellations_old CASCADE;
DROP VIEW IF EXISTS njiv_cl_intl CASCADE;
DROP VIEW IF EXISTS njiv_current_product_on_stock CASCADE;
DROP VIEW IF EXISTS njiv_customer_by_shipping_country CASCADE;
DROP VIEW IF EXISTS njiv_daily_totals_currency CASCADE;
DROP VIEW IF EXISTS njiv_daily_totals_ship CASCADE;
DROP VIEW IF EXISTS njiv_designer_season_live_on_order CASCADE;
DROP VIEW IF EXISTS njiv_first_orders CASCADE;
DROP VIEW IF EXISTS njiv_ftbc_gross_orders2 CASCADE;
DROP VIEW IF EXISTS njiv_ftbc_gross_sales_old CASCADE;
DROP VIEW IF EXISTS njiv_gross_order_totals2 CASCADE;
DROP VIEW IF EXISTS njiv_gross_order_totals3 CASCADE;
DROP VIEW IF EXISTS njiv_gross_rm_daily_totals_curency CASCADE;
DROP VIEW IF EXISTS njiv_gross_rm_daily_totals_currency CASCADE;
DROP VIEW IF EXISTS njiv_jc_pricing CASCADE;
DROP VIEW IF EXISTS njiv_master_product_attributes_new CASCADE;
DROP VIEW IF EXISTS njiv_master_product_attributes2 CASCADE;
DROP VIEW IF EXISTS njiv_master_product_attributes3 CASCADE;
DROP VIEW IF EXISTS njiv_md_orders CASCADE;
DROP VIEW IF EXISTS "njiv_mpa_MDind" CASCADE;
DROP VIEW IF EXISTS "njiv_mpa_OSP" CASCADE;
DROP VIEW IF EXISTS "njiv_mpa_osp" CASCADE;
DROP VIEW IF EXISTS njiv_mpa_schema1 CASCADE;
DROP VIEW IF EXISTS njiv_orders_old CASCADE;
DROP VIEW IF EXISTS njiv_product_free_stock CASCADE;
DROP VIEW IF EXISTS njiv_product_stock_2 CASCADE;
DROP VIEW IF EXISTS njiv_returns_old CASCADE;
DROP VIEW IF EXISTS njiv_rm_intl2 CASCADE;
DROP VIEW IF EXISTS njiv_shipment_items_promo CASCADE;
DROP VIEW IF EXISTS njiv_variant_on_order CASCADE;
DROP VIEW IF EXISTS todaysday CASCADE;
DROP VIEW IF EXISTS upload_date_maybe CASCADE;


/*Drop suspected unused views - 2nd time and Onwards*/
DROP VIEW IF EXISTS xon_njiv_cancellations_old CASCADE;
DROP VIEW IF EXISTS xon_njiv_cl_intl CASCADE;
DROP VIEW IF EXISTS xon_njiv_current_product_on_stock CASCADE;
DROP VIEW IF EXISTS xon_njiv_customer_by_shipping_country CASCADE;
DROP VIEW IF EXISTS xon_njiv_daily_totals_currency CASCADE;
DROP VIEW IF EXISTS xon_njiv_daily_totals_ship CASCADE;
DROP VIEW IF EXISTS xon_njiv_designer_season_live_on_order CASCADE;
DROP VIEW IF EXISTS xon_njiv_first_orders CASCADE;
DROP VIEW IF EXISTS xon_njiv_ftbc_gross_orders2 CASCADE;
DROP VIEW IF EXISTS xon_njiv_ftbc_gross_sales_old CASCADE;
DROP VIEW IF EXISTS xon_njiv_gross_order_totals2 CASCADE;
DROP VIEW IF EXISTS xon_njiv_gross_order_totals3 CASCADE;
DROP VIEW IF EXISTS xon_njiv_gross_rm_daily_totals_curency CASCADE;
DROP VIEW IF EXISTS xon_njiv_gross_rm_daily_totals_currency CASCADE;
DROP VIEW IF EXISTS xon_njiv_jc_pricing CASCADE;
DROP VIEW IF EXISTS xon_njiv_master_product_attributes_new CASCADE;
DROP VIEW IF EXISTS xon_njiv_master_product_attributes2 CASCADE;
DROP VIEW IF EXISTS xon_njiv_master_product_attributes3 CASCADE;
DROP VIEW IF EXISTS xon_njiv_md_orders CASCADE;
DROP VIEW IF EXISTS xon_njiv_mpa_mdind CASCADE;
DROP VIEW IF EXISTS xon_njiv_mpa_osp CASCADE;
DROP VIEW IF EXISTS xon_njiv_mpa_schema1 CASCADE;
DROP VIEW IF EXISTS xon_njiv_orders_old CASCADE;
DROP VIEW IF EXISTS xon_njiv_product_free_stock CASCADE;
DROP VIEW IF EXISTS xon_njiv_product_stock_2 CASCADE;
DROP VIEW IF EXISTS xon_njiv_returns_old CASCADE;
DROP VIEW IF EXISTS xon_njiv_rm_intl2 CASCADE;
DROP VIEW IF EXISTS xon_njiv_shipment_items_promo CASCADE;
DROP VIEW IF EXISTS xon_njiv_variant_on_order CASCADE;
DROP VIEW IF EXISTS xon_todaysday CASCADE;
DROP VIEW IF EXISTS xon_upload_date_maybe CASCADE;




/*DROP tables in use*/
DROP TABLE IF EXISTS mtbl_1st_sold_out;
DROP TABLE IF EXISTS mtbl_cancellations;
DROP TABLE IF EXISTS mtbl_daily_totals;
DROP TABLE IF EXISTS mtbl_daily_totals_2;
DROP TABLE IF EXISTS mtbl_daily_totals_currency_2;
DROP TABLE IF EXISTS mtbl_daily_ukl;
DROP TABLE IF EXISTS mtbl_ftbc_gross_orders;
DROP TABLE IF EXISTS mtbl_ftbc_gross_sales;
DROP TABLE IF EXISTS mtbl_ftbc_merch_cancellations;
DROP TABLE IF EXISTS mtbl_ftbc_merch_returns;
DROP TABLE IF EXISTS mtbl_gross_order_totals_currency;
DROP TABLE IF EXISTS mtbl_master_free_stock;
DROP TABLE IF EXISTS mtbl_master_product_attributes;
DROP TABLE IF EXISTS mtbl_merch_sales_season;
DROP TABLE IF EXISTS mtbl_net_sales;
DROP TABLE IF EXISTS mtbl_orders;
DROP TABLE IF EXISTS mtbl_preorder_returns_dispatchdate;
DROP TABLE IF EXISTS mtbl_prod_orders;
DROP TABLE IF EXISTS mtbl_product_ordered_qty;
DROP TABLE IF EXISTS mtbl_pws_log_stock_reporting;
DROP TABLE IF EXISTS mtbl_returns;
DROP TABLE IF EXISTS mtbl_rm_cancellations;
DROP TABLE IF EXISTS mtbl_rm_daily_totals_currency;
DROP TABLE IF EXISTS mtbl_rm_daily_totals_currency_dispatch;
DROP TABLE IF EXISTS mtbl_rm_returns;
DROP TABLE IF EXISTS mtbl_stock_by_location;
DROP TABLE IF EXISTS mtbl_variant_free_stock;
DROP TABLE IF EXISTS mtbl_merchandising;
DROP TABLE IF EXISTS mtbl_1st_sold_out_outnet;
DROP TABLE IF EXISTS mtbl_cancellations_outnet;
DROP TABLE IF EXISTS mtbl_daily_totals_outnet;
DROP TABLE IF EXISTS mtbl_daily_totals_2_outnet;
DROP TABLE IF EXISTS mtbl_daily_totals_currency_2_outnet;
DROP TABLE IF EXISTS mtbl_daily_ukl_outnet;
DROP TABLE IF EXISTS mtbl_ftbc_gross_orders_outnet;
DROP TABLE IF EXISTS mtbl_ftbc_gross_sales_outnet;
DROP TABLE IF EXISTS mtbl_ftbc_merch_cancellations_outnet;
DROP TABLE IF EXISTS mtbl_ftbc_merch_returns_outnet;
DROP TABLE IF EXISTS mtbl_gross_order_totals_currency_outnet;
DROP TABLE IF EXISTS mtbl_master_free_stock_outnet;
DROP TABLE IF EXISTS mtbl_master_product_attributes_outnet;
DROP TABLE IF EXISTS mtbl_merch_sales_season_outnet;
DROP TABLE IF EXISTS mtbl_net_sales_outnet;
DROP TABLE IF EXISTS mtbl_orders_outnet;
DROP TABLE IF EXISTS mtbl_preorder_returns_dispatchdate_outnet;
DROP TABLE IF EXISTS mtbl_prod_orders_outnet;
DROP TABLE IF EXISTS mtbl_product_ordered_qty_outnet;
DROP TABLE IF EXISTS mtbl_pws_log_stock_reporting_outnet;
DROP TABLE IF EXISTS mtbl_returns_outnet;
DROP TABLE IF EXISTS mtbl_rm_cancellations_outnet;
DROP TABLE IF EXISTS mtbl_rm_daily_totals_currency_outnet;
DROP TABLE IF EXISTS mtbl_rm_daily_totals_currency_dispatch_outnet;
DROP TABLE IF EXISTS mtbl_rm_returns_outnet;
DROP TABLE IF EXISTS mtbl_stock_by_location_outnet;
DROP TABLE IF EXISTS mtbl_variant_free_stock_outnet;
DROP TABLE IF EXISTS mtbl_merchandising_outnet;
DROP TABLE IF EXISTS mtbl_mpa_intl;
DROP TABLE IF EXISTS mtbl_sale_orders;
DROP TABLE IF EXISTS mtbl_sale_orders_outnet;


/*******************************************************************NAP*************************************************************************/



/*CREATE OR REPLACE Used Views*/
-------------------------------------------------
CREATE OR REPLACE VIEW njiv_1st_sold_out AS
SELECT p.id AS product_id, min(pw.date) AS date
FROM product p
LEFT JOIN variant v ON p.id = v.product_id
LEFT JOIN log_pws_stock pw ON v.id = pw.variant_id
WHERE pw.balance = 0 and pw.channel_id = 1
AND pw.pws_action_id <> 14
GROUP BY p.id;

ALTER TABLE njiv_1st_sold_out OWNER TO postgres;

-------------------------------------------------


CREATE OR REPLACE VIEW njiv_cancellations AS
SELECT
tmp.date_ts,
tmp.date,
tmp.order_id,
tmp.order_nr,
tmp.customer_id,
tmp.is_customer_number,
tmp.currency,
tmp.country,
sum(tmp.unit_count) AS unit_count,
sum(tmp.merchandise_sales_value) AS merchandise_sales_value,
sum(tmp.tax_value) AS tax_value,
sum(tmp.duties_value) AS duties_value,
sum(tmp.shipping_value) AS shipping_value,
sum(tmp.gift_credit_redeemed) AS gift_credit_redeemed,
sum(tmp.store_credit_redeemed) AS store_credit_redeemed,
sum(tmp.gross_sales_value) + sum(tmp.total) AS total_order_value,
tmp.first_order,
max(tmp.whole_order) AS max

FROM

(

	SELECT o.date AS date_ts,
	date_trunc('day'::text, o.date) AS date,
	o.id AS order_id,
	o.order_nr,
	o.customer_id,
	cu.is_customer_number,
	c.currency,
	oa.country,
	count(si.variant_id) AS unit_count,
	sum(si.unit_price) AS merchandise_sales_value,
	sum(si.tax) AS tax_value,
	sum(si.duty) AS duties_value,
	sum(si.unit_price + si.tax + si.duty) AS gross_sales_value,
	0 AS shipping_value,
	0 AS gift_credit_redeemed,
	0 AS store_credit_redeemed,
	0 AS total,
	CASE WHEN (3 IN ( SELECT order_flag.flag_id FROM orders, order_flag WHERE o.id = orders.id AND orders.id = order_flag.orders_id))
	     THEN 'Y'::text
	     ELSE 'N'::text
     	     END AS first_order,
	'N'::text AS whole_order

	FROM orders o
	LEFT JOIN customer cu ON o.customer_id = cu.id
	JOIN link_orders__shipment los On o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id
	JOIN shipment_item si ON s.id = si.shipment_id AND s.shipment_class_id = 1 AND (si.shipment_item_status_id = ANY (ARRAY[9, 10]))
	JOIN currency c ON o.currency_id = c.id
	JOIN order_address oa ON o.invoice_address_id = oa.id

	WHERE
	si.variant_id <> 49285 AND si.variant_id <> 67158 AND si.variant_id <> 73652
	AND o.channel_id = 1

	GROUP BY
	o.date,
	date_trunc('day'::text, o.date),
	o.id,
	o.order_nr,
	o.customer_id,
	cu.is_customer_number,
	c.currency,
	oa.country,
	CASE WHEN (3 IN ( SELECT order_flag.flag_id FROM orders, order_flag WHERE o.id = orders.id AND orders.id = order_flag.orders_id))
     	     THEN 'Y'::text
     	     ELSE 'N'::text
     	     END

UNION

	SELECT o.date AS date_ts,
	date_trunc('day'::text, o.date) AS date,
	o.id AS order_id,
	o.order_nr,
	o.customer_id,
	cu.is_customer_number,
	c.currency,
	oa.country,
	0 AS unit_count,
	0 AS merchandise_sales_value,
	0 AS tax_value,
	0 AS duties_value,
	0 AS gross_sales_value,
	sum(s.shipping_charge) AS shipping_value,
	sum(s.gift_credit) AS gift_credit_redeemed,
	sum(s.store_credit) AS store_credit_redeemed,
	sum(s.shipping_charge + s.gift_credit + s.store_credit) AS total,
	CASE WHEN (3 IN ( SELECT order_flag.flag_id FROM orders, order_flag WHERE o.id = orders.id AND orders.id = order_flag.orders_id))
     	     THEN 'Y'::text
     	     ELSE 'N'::text
     	     END AS first_order,
	'Y'::text AS whole_order

	FROM orders o
	LEFT JOIN customer cu ON o.customer_id = cu.id
	JOIN link_orders__shipment los ON o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id AND s.shipment_class_id = 1 AND s.shipment_status_id = 5
	JOIN currency c ON o.currency_id = c.id
	JOIN order_address oa ON o.invoice_address_id = oa.id

	WHERE
	o.channel_id = 1

	GROUP BY
	o.date,
	date_trunc('day'::text, o.date),
	o.id,
	o.order_nr,
	o.customer_id,
	cu.is_customer_number,
	c.currency,
	oa.country,
	CASE WHEN (3 IN ( SELECT order_flag.flag_id FROM orders, order_flag WHERE o.id = orders.id AND orders.id = order_flag.orders_id))
     	     THEN 'Y'::text
     	     ELSE 'N'::text
	     END

) tmp


GROUP BY
tmp.date_ts,
tmp.order_nr,
tmp.date,
tmp.order_id,
tmp.customer_id,
tmp.is_customer_number,
tmp.currency,
tmp.country,
tmp.first_order

ORDER BY
tmp.date_ts,
tmp.order_nr;

ALTER TABLE njiv_cancellations OWNER TO postgres;
-------------------------------------------------


CREATE OR REPLACE VIEW njiv_daily_totals AS
SELECT

tmp.date,
sum(tmp.order_count) AS order_count,
sum(tmp.merchandise_sales_value) AS merchandise_sales_value,
sum(tmp.tax_value) AS tax_value,
sum(tmp.duties_value) AS duties_value,
sum(tmp.gross_sales_value) AS gross_sales_value,
sum(tmp.shipping_value) AS shipping_value,
sum(tmp.gift_credit_redeemed) AS gift_credit_redeemed,
sum(tmp.store_credit_redeemed) AS store_credit_redeemed,
sum(tmp.total) AS gross_shipping_total,
sum(tmp.new_order_count) AS new_order_count,
sum(tmp.new_merchandise_sales_value) AS new_merchandise_sales_value,
sum(tmp.new_tax_value) AS new_tax_value,
sum(tmp.new_duties_value) AS new_duties_value,
sum(tmp.new_gross_sales_value) AS new_gross_sales_value,
sum(tmp.new_shipping_value) AS new_shipping_value,
sum(tmp.new_gift_credit_redeemed) AS new_gift_credit_redeemed,
sum(tmp.new_store_credit_redeemed) AS new_store_credit_redeemed,
sum(tmp.new_total) AS new_gross_shipping_total

FROM
(((
	SELECT
	date_trunc('day'::text, o.date) AS date,
	count(DISTINCT o.order_nr) AS order_count,
	sum(si.unit_price / scr.from_gbp) AS merchandise_sales_value,
	sum(si.tax / scr.from_gbp) AS tax_value,
	sum(si.duty / scr.from_gbp) AS duties_value,
	sum((si.unit_price + si.tax + si.duty) / scr.from_gbp) AS gross_sales_value,
	0 AS shipping_value,
	0 AS gift_credit_redeemed,
	0 AS store_credit_redeemed,
	0 AS total,
	0 AS new_order_count,
	0 AS new_merchandise_sales_value,
	0 AS new_tax_value,
	0 AS new_duties_value,
	0 AS new_gross_sales_value,
	0 AS new_shipping_value,
	0 AS new_gift_credit_redeemed,
	0 AS new_store_credit_redeemed,
	0 AS new_total

	FROM
	orders o
	JOIN link_orders__shipment los ON o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id AND s.shipment_class_id = 1
	JOIN shipment_item si ON s.id = si.shipment_id
	JOIN nji_lookup_fx_rates scr ON o.currency_id = scr.currency_id AND o.date > scr.valid_from AND (scr.valid_to IS NULL OR o.date < valid_to)

	WHERE
	si.variant_id <> 49285 AND si.variant_id <> 67158 AND si.variant_id <> 73652
   	AND o.channel_id = 1

	GROUP BY
	date_trunc('day'::text, o.date)

UNION
	SELECT date_trunc('day'::text, o.date) AS date,
	0 AS order_count,
	0 AS merchandise_sales_value,
	0 AS tax_value,
	0 AS duties_value,
	0 AS gross_sales_value,
	sum(s.shipping_charge / scr.from_gbp) AS shipping_value,
	sum(s.gift_credit / scr.from_gbp) AS gift_credit_redeemed,
	sum(s.store_credit / scr.from_gbp) AS store_credit_redeemed,
	sum((s.shipping_charge + s.gift_credit + s.store_credit) / scr.from_gbp) AS total,
	0 AS new_order_count,
	0 AS new_merchandise_sales_value,
	0 AS new_tax_value,
	0 AS new_duties_value,
	0 AS new_gross_sales_value,
	0 AS new_shipping_value,
	0 AS new_gift_credit_redeemed,
	0 AS new_store_credit_redeemed,
	0 AS new_total

	FROM
	orders o
	JOIN link_orders__shipment los ON o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id AND s.shipment_class_id = 1
	JOIN nji_lookup_fx_rates scr ON o.currency_id = scr.currency_id AND o.date > scr.valid_from AND (scr.valid_to IS NULL OR o.date < valid_to)

        WHERE
	o.channel_id = 1

	GROUP BY date_trunc('day'::text, o.date)
	)

UNION


	SELECT
	date_trunc('day'::text, o.date) AS date,
	0 AS order_count,
	0 AS merchandise_sales_value,
	0 AS tax_value,
	0 AS duties_value,
	0 AS gross_sales_value,
	0 AS shipping_value,
	0 AS gift_credit_redeemed,
	0 AS store_credit_redeemed,
	0 AS total, count(DISTINCT o.order_nr) AS new_order_count,
	sum(si.unit_price / scr.from_gbp) AS new_merchandise_sales_value,
	sum(si.tax / scr.from_gbp) AS new_tax_value,
	sum(si.duty / scr.from_gbp) AS new_duties_value,
	sum((si.unit_price + si.tax + si.duty) / scr.from_gbp) AS new_gross_sales_value,
	0 AS new_shipping_value,
	0 AS new_gift_credit_redeemed,
	0 AS new_store_credit_redeemed,
	0 AS new_total


	FROM
	orders o
	JOIN link_orders__shipment los ON o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id AND s.shipment_class_id = 1
	JOIN shipment_item si ON s.id = si.shipment_id
	JOIN order_flag of on o.id = of.orders_id AND of.flag_id = 3
	JOIN nji_lookup_fx_rates scr ON o.currency_id = scr.currency_id AND o.date > scr.valid_from AND (scr.valid_to IS NULL OR o.date < valid_to)




	WHERE
	si.variant_id <> 49285 AND si.variant_id <> 67158 AND si.variant_id <> 73652
	AND o.channel_id = 1

        GROUP BY
	date_trunc('day'::text, o.date)
	)

UNION
	SELECT
	date_trunc('day'::text, o.date) AS date,
	0 AS order_count,
	0 AS merchandise_sales_value,
	0 AS tax_value,
	0 AS duties_value,
	0 AS gross_sales_value,
	0 AS shipping_value,
	0 AS gift_credit_redeemed,
	0 AS store_credit_redeemed,
	0 AS total,
	0 AS new_order_count,
	0 AS new_merchandise_sales_value,
	0 AS new_tax_value,
	0 AS new_duties_value,
	0 AS new_gross_sales_value,
	sum(s.shipping_charge / scr.from_gbp) AS new_shipping_value,
	sum(s.gift_credit / scr.from_gbp) AS new_gift_credit_redeemed,
	sum(s.store_credit / scr.from_gbp) AS new_store_credit_redeemed,
	sum((s.shipping_charge + s.gift_credit + s.store_credit) / scr.from_gbp) AS new_total

	FROM
	orders o
	JOIN link_orders__shipment los ON o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id AND s.shipment_class_id = 1
	JOIN order_flag of on o.id = of.orders_id AND of.flag_id = 3
	JOIN nji_lookup_fx_rates scr ON o.currency_id = scr.currency_id AND o.date > scr.valid_from AND (scr.valid_to IS NULL OR o.date < valid_to)


	WHERE
	o.channel_id = 1

	GROUP BY
	date_trunc('day'::text, o.date)
	) tmp

GROUP BY tmp.date;
ALTER TABLE njiv_daily_totals OWNER TO postgres;
-------------------------------------------------

CREATE OR REPLACE VIEW njiv_daily_totals_2 AS
SELECT

tmp.date,
sum(tmp.order_count) AS order_count,
sum(tmp.units) AS units,
sum(tmp.merchandise_sales_value) AS merchandise_sales_value,
sum(tmp.tax_value) AS tax_value,
sum(tmp.duties_value) AS duties_value,
sum(tmp.gross_sales_value) AS gross_sales_value,
sum(tmp.shipping_value) AS shipping_value,
sum(tmp.gift_credit_redeemed) AS gift_credit_redeemed,
sum(tmp.store_credit_redeemed) AS store_credit_redeemed,
sum(tmp.total) AS gross_shipping_total,
sum(tmp.new_order_count) AS new_order_count,
sum(tmp.new_units) AS new_units,
sum(tmp.new_merchandise_sales_value) AS new_merchandise_sales_value,
sum(tmp.new_tax_value) AS new_tax_value,
sum(tmp.new_duties_value) AS new_duties_value,
sum(tmp.new_gross_sales_value) AS new_gross_sales_value,
sum(tmp.new_shipping_value) AS new_shipping_value,
sum(tmp.new_gift_credit_redeemed) AS new_gift_credit_redeemed,
sum(tmp.new_store_credit_redeemed) AS new_store_credit_redeemed,
sum(tmp.new_total) AS new_gross_shipping_total

FROM
(((

	SELECT
	date_trunc('day'::text, o.date) AS date,
	count(DISTINCT o.order_nr) AS order_count,
	count(si.id) AS units,
	sum(si.unit_price / scr.from_gbp) AS merchandise_sales_value,
	sum(si.tax / scr.from_gbp) AS tax_value,
	sum(si.duty / scr.from_gbp) AS duties_value,
	sum((si.unit_price + si.tax + si.duty) / scr.from_gbp) AS gross_sales_value,
	0 AS shipping_value,
	0 AS gift_credit_redeemed,
	0 AS store_credit_redeemed,
	0 AS total,
	0 AS new_order_count,
	0 AS new_units,
	0 AS new_merchandise_sales_value,
	0 AS new_tax_value,
	0 AS new_duties_value,
	0 AS new_gross_sales_value,
	0 AS new_shipping_value,
	0 AS new_gift_credit_redeemed,
	0 AS new_store_credit_redeemed,
	0 AS new_total

	FROM
	orders o
	JOIN link_orders__shipment los ON o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id AND s.shipment_class_id = 1
	JOIN shipment_item si ON s.id = si.shipment_id
	JOIN nji_lookup_fx_rates scr ON o.currency_id = scr.currency_id AND o.date > scr.valid_from AND (scr.valid_to IS NULL OR o.date < valid_to)

	WHERE
	si.variant_id <> 49285 AND si.variant_id <> 67158 AND si.variant_id <> 73652
   	AND o.channel_id = 1

	GROUP BY
	date_trunc('day'::text, o.date)


UNION
	SELECT date_trunc('day'::text, o.date) AS date,
	0 AS order_count,
	0 AS units,
	0 AS merchandise_sales_value,
	0 AS tax_value,
	0 AS duties_value,
	0 AS gross_sales_value,
	sum(s.shipping_charge / scr.from_gbp) AS shipping_value,
	sum(s.gift_credit / scr.from_gbp) AS gift_credit_redeemed,
	sum(s.store_credit / scr.from_gbp) AS store_credit_redeemed,
	sum((s.shipping_charge + s.gift_credit + s.store_credit) / scr.from_gbp) AS total,
	0 AS new_order_count,
	0 AS new_units,
	0 AS new_merchandise_sales_value,
	0 AS new_tax_value,
	0 AS new_duties_value,
	0 AS new_gross_sales_value,
	0 AS new_shipping_value,
	0 AS new_gift_credit_redeemed,
	0 AS new_store_credit_redeemed,
	0 AS new_total

	FROM
	orders o
	JOIN link_orders__shipment los ON o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id AND s.shipment_class_id = 1
	JOIN nji_lookup_fx_rates scr ON o.currency_id = scr.currency_id AND o.date > scr.valid_from AND (scr.valid_to IS NULL OR o.date < valid_to)

        WHERE
	o.channel_id = 1

	GROUP BY date_trunc('day'::text, o.date)
	)


UNION

	SELECT
	date_trunc('day'::text, o.date) AS date,
	0 AS order_count,
	0 as units,
	0 AS merchandise_sales_value,
	0 AS tax_value,
	0 AS duties_value,
	0 AS gross_sales_value,
	0 AS shipping_value,
	0 AS gift_credit_redeemed,
	0 AS store_credit_redeemed,
	0 AS total,
	count(DISTINCT o.order_nr) AS new_order_count,
	count(si.id) AS new_units,
	sum(si.unit_price / scr.from_gbp) AS new_merchandise_sales_value,
	sum(si.tax / scr.from_gbp) AS new_tax_value,
	sum(si.duty / scr.from_gbp) AS new_duties_value,
	sum((si.unit_price + si.tax + si.duty) / scr.from_gbp) AS new_gross_sales_value,
	0 AS new_shipping_value,
	0 AS new_gift_credit_redeemed,
	0 AS new_store_credit_redeemed,
	0 AS new_total


	FROM
	orders o
	JOIN link_orders__shipment los ON o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id AND s.shipment_class_id = 1
	JOIN shipment_item si ON s.id = si.shipment_id
	JOIN order_flag of on o.id = of.orders_id AND of.flag_id = 3
	JOIN nji_lookup_fx_rates scr ON o.currency_id = scr.currency_id AND o.date > scr.valid_from AND (scr.valid_to IS NULL OR o.date < valid_to)


	WHERE
	si.variant_id <> 49285 AND si.variant_id <> 67158 AND si.variant_id <> 73652
	AND o.channel_id = 1

        GROUP BY
	date_trunc('day'::text, o.date)
	)


UNION
	SELECT
	date_trunc('day'::text, o.date) AS date,
	0 AS order_count,
	0 as units,
	0 AS merchandise_sales_value,
	0 AS tax_value,
	0 AS duties_value,
	0 AS gross_sales_value,
	0 AS shipping_value,
	0 AS gift_credit_redeemed,
	0 AS store_credit_redeemed,
	0 AS total,
	0 AS new_order_count,
	0 as new_units,
	0 AS new_merchandise_sales_value,
	0 AS new_tax_value,
	0 AS new_duties_value,
	0 AS new_gross_sales_value,
	sum(s.shipping_charge / scr.from_gbp) AS new_shipping_value,
	sum(s.gift_credit / scr.from_gbp) AS new_gift_credit_redeemed,
	sum(s.store_credit / scr.from_gbp) AS new_store_credit_redeemed,
	sum((s.shipping_charge + s.gift_credit + s.store_credit) / scr.from_gbp) AS new_total

	FROM
	orders o
	JOIN link_orders__shipment los ON o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id AND s.shipment_class_id = 1
	JOIN order_flag of on o.id = of.orders_id AND of.flag_id = 3
	JOIN nji_lookup_fx_rates scr ON o.currency_id = scr.currency_id AND o.date > scr.valid_from AND (scr.valid_to IS NULL OR o.date < valid_to)


	WHERE
	o.channel_id = 1

	GROUP BY
	date_trunc('day'::text, o.date)
	) tmp

  GROUP BY tmp.date;
ALTER TABLE njiv_daily_totals_2 OWNER TO postgres;
---------------------------------------------------

CREATE OR REPLACE VIEW njiv_daily_totals_currency_2 AS
SELECT
tmp.date,
tmp.currency,
sum(tmp.order_count) AS order_count,
sum(tmp.units) AS units,
sum(tmp.merchandise_sales_value) AS merchandise_sales_value,
sum(tmp.tax_value) AS tax_value,
sum(tmp.duties_value) AS duties_value,
sum(tmp.gross_sales_value) AS gross_sales_value,
sum(tmp.shipping_value) AS shipping_value,
sum(tmp.gift_credit_redeemed) AS gift_credit_redeemed,
sum(tmp.store_credit_redeemed) AS store_credit_redeemed,
sum(tmp.total) AS gross_shipping_total,
sum(tmp.new_order_count) AS new_order_count,
sum(tmp.new_units) AS new_units,
sum(tmp.new_merchandise_sales_value) AS new_merchandise_sales_value,
sum(tmp.new_tax_value) AS new_tax_value,
sum(tmp.new_duties_value) AS new_duties_value,
sum(tmp.new_gross_sales_value) AS new_gross_sales_value,
sum(tmp.new_shipping_value) AS new_shipping_value,
sum(tmp.new_gift_credit_redeemed) AS new_gift_credit_redeemed,
sum(tmp.new_store_credit_redeemed) AS new_store_credit_redeemed,
sum(tmp.new_total) AS new_gross_shipping_total

FROM
(((

	SELECT
	date_trunc('day'::text, o.date) AS date,
	c.currency,
	count(DISTINCT o.order_nr) AS order_count,
	count(si.id) AS units,
	sum(si.unit_price) AS merchandise_sales_value,
	sum(si.tax) AS tax_value,
	sum(si.duty) AS duties_value,
	sum(si.unit_price + si.tax + si.duty) AS gross_sales_value,
	0 AS shipping_value,
	0 AS gift_credit_redeemed,
	0 AS store_credit_redeemed,
	0 AS total,
	0 AS new_order_count,
	0 AS new_units,
	0 AS new_merchandise_sales_value,
	0 AS new_tax_value,
	0 AS new_duties_value,
	0 AS new_gross_sales_value,
	0 AS new_shipping_value,
	0 AS new_gift_credit_redeemed,
	0 AS new_store_credit_redeemed,
	0 AS new_total

	FROM
	orders o
	JOIN link_orders__shipment los ON o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id AND s.shipment_class_id = 1
	JOIN shipment_item si ON s.id = si.shipment_id
	JOIN currency c ON o.currency_id = c.id

	WHERE
	si.variant_id <> 49285 AND si.variant_id <> 67158 AND si.variant_id <> 73652
   	AND o.channel_id = 1

	GROUP BY
	date_trunc('day'::text, o.date), c.currency

UNION
	SELECT date_trunc('day'::text, o.date) AS date,
	c.currency,
	0 AS order_count,
	0 AS units,
	0 AS merchandise_sales_value,
	0 AS tax_value,
	0 AS duties_value,
	0 AS gross_sales_value,
	sum(s.shipping_charge) AS shipping_value,
	sum(s.gift_credit) AS gift_credit_redeemed,
	sum(s.store_credit) AS store_credit_redeemed,
	sum(s.shipping_charge + s.gift_credit + s.store_credit) AS total,
	0 AS new_order_count,
	0 AS new_units,
	0 AS new_merchandise_sales_value,
	0 AS new_tax_value,
	0 AS new_duties_value,
	0 AS new_gross_sales_value,
	0 AS new_shipping_value,
	0 AS new_gift_credit_redeemed,
	0 AS new_store_credit_redeemed,
	0 AS new_total

	FROM
	orders o
	JOIN link_orders__shipment los ON o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id AND s.shipment_class_id = 1
	JOIN currency c ON o.currency_id = c.id

        WHERE
	o.channel_id = 1

	GROUP BY date_trunc('day'::text, o.date),c.currency
	)

UNION
	SELECT
	date_trunc('day'::text, o.date) AS date,
	c.currency,
	0 AS order_count,
	0 as units,
	0 AS merchandise_sales_value,
	0 AS tax_value,
	0 AS duties_value,
	0 AS gross_sales_value,
	0 AS shipping_value,
	0 AS gift_credit_redeemed,
	0 AS store_credit_redeemed,
	0 AS total,
	count(DISTINCT o.order_nr) AS new_order_count,
	count(si.id) AS new_units,
	sum(si.unit_price) AS new_merchandise_sales_value,
	sum(si.tax) AS new_tax_value,
	sum(si.duty) AS new_duties_value,
	sum(si.unit_price + si.tax + si.duty) AS new_gross_sales_value,
	0 AS new_shipping_value,
	0 AS new_gift_credit_redeemed,
	0 AS new_store_credit_redeemed,
	0 AS new_total


	FROM
	orders o
	JOIN link_orders__shipment los ON o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id AND s.shipment_class_id = 1
	JOIN shipment_item si ON s.id = si.shipment_id
	JOIN order_flag of on o.id = of.orders_id AND of.flag_id = 3
	JOIN currency c ON o.currency_id = c.id


	WHERE
	si.variant_id <> 49285 AND si.variant_id <> 67158 AND si.variant_id <> 73652
	AND o.channel_id = 1

        GROUP BY
	date_trunc('day'::text, o.date), c.currency
	)

UNION
	SELECT
	date_trunc('day'::text, o.date) AS date,
	c.currency,
	0 AS order_count,
	0 as units,
	0 AS merchandise_sales_value,
	0 AS tax_value,
	0 AS duties_value,
	0 AS gross_sales_value,
	0 AS shipping_value,
	0 AS gift_credit_redeemed,
	0 AS store_credit_redeemed,
	0 AS total,
	0 AS new_order_count,
	0 as new_units,
	0 AS new_merchandise_sales_value,
	0 AS new_tax_value,
	0 AS new_duties_value,
	0 AS new_gross_sales_value,
	sum(s.shipping_charge) AS new_shipping_value,
	sum(s.gift_credit) AS new_gift_credit_redeemed,
	sum(s.store_credit) AS new_store_credit_redeemed,
	sum(s.shipping_charge + s.gift_credit + s.store_credit) AS new_total

	FROM
	orders o
	JOIN link_orders__shipment los ON o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id AND s.shipment_class_id = 1
	JOIN order_flag of on o.id = of.orders_id AND of.flag_id = 3
	JOIN currency c ON o.currency_id = c.id


	WHERE
	o.channel_id = 1

	GROUP BY
	date_trunc('day'::text, o.date), c.currency
	) tmp

  GROUP BY tmp.date, tmp.currency;
ALTER TABLE njiv_daily_totals_currency_2 OWNER TO postgres;
-----------------------------------------------------------

CREATE OR REPLACE VIEW njiv_daily_ukl AS 
SELECT date_trunc('day'::text, o.date) AS date_trunc, count(DISTINCT o.order_nr) AS count, sum(pp.uk_landed_cost) AS total_ukl

FROM 
orders o 
JOIN link_orders__shipment los ON o.id = los.orders_id
JOIN shipment s on los.shipment_id = s.id AND s.shipment_class_id = 1
JOIN shipment_item si ON s.id = si.shipment_id
JOIN variant v ON si.variant_id = v.id
JOIN product p ON v.product_id = p.id
JOIN price_purchase pp ON p.id = pp.product_id

WHERE
si.variant_id <> 49285 AND si.variant_id <> 67158 AND si.variant_id <> 73652
AND o.channel_id = 1


GROUP BY date_trunc('day'::text, o.date);
ALTER TABLE njiv_daily_ukl OWNER TO postgres;


------------------------------------------------------------
CREATE OR REPLACE VIEW njiv_ftbc_gross_orders AS 
SELECT 
ftbc1.date, 
count(ftbc1.order_id) AS order_count, 
ftbc1.currency, 
sum(ftbc1.first_order) AS first_orders, 
sum(ftbc1.ftbc_unit_count) AS ftbc_units, 
sum(ftbc1.units) AS total_units


FROM ( 
	SELECT date_trunc('day'::text, o.date) AS date, o.id AS order_id, o.order_nr, c.currency, 
	sum(CASE WHEN p.season_id = 39 THEN 1 ELSE 0 END) AS ftbc_unit_count, 
        CASE WHEN (3 IN ( SELECT order_flag.flag_id FROM orders, order_flag WHERE o.id = orders.id AND orders.id = order_flag.orders_id)) 
		THEN 1
                ELSE 0
                END AS first_order, 
	count(si.id) AS units, 
	sum(si.unit_price) AS merchandise_sales_value, 
	sum(si.tax) AS tax_value, 
	sum(si.duty) AS duties_value, 
	sum(si.unit_price + si.tax + si.duty) AS gross_sales_value
        
	FROM orders o
      	JOIN link_orders__shipment los ON o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id AND s.shipment_class_id = 1
	JOIN shipment_item si ON s.id = si.shipment_id
	JOIN currency c ON o.currency_id = c.id
	JOIN variant v ON si.variant_id = v.id
	JOIN product p ON v.product_id = p.id

	WHERE 
	o.channel_id = 1
  
	GROUP BY 
	date_trunc('day'::text, o.date), 
	o.id, 
	o.order_nr, 
	c.currency, 
	CASE WHEN (3 IN ( SELECT order_flag.flag_id FROM orders, order_flag WHERE o.id = orders.id AND orders.id = order_flag.orders_id)) 
	     THEN 1
	     ELSE 0
	END) ftbc1
  
WHERE 
ftbc1.ftbc_unit_count = ftbc1.units

GROUP BY 
ftbc1.date, ftbc1.currency

ORDER BY 
ftbc1.date, ftbc1.currency;

ALTER TABLE njiv_ftbc_gross_orders OWNER TO postgres;
----------------------------------------------------

CREATE OR REPLACE VIEW njiv_ftbc_gross_sales AS
SELECT
date_trunc('day'::text, o.date) AS date,
c.currency,
count(DISTINCT o.order_nr) AS containsftbc_order_count,
count(si.id) AS ftbc_units,
sum(si.unit_price) AS ftbc_merchandise_sales_value,
sum(si.tax) AS ftbc_tax_value,
sum(si.duty) AS ftbc_duties_value,
sum(si.unit_price + si.tax + si.duty) AS ftbc_gross_sales_value,
sum(pp.uk_landed_cost) AS ftbc_ukl

FROM orders o
JOIN link_orders__shipment los ON o.id = los.orders_id
JOIN shipment s ON los.shipment_id = s.id AND s.shipment_class_id = 1
JOIN shipment_item si ON s.id = si.shipment_id
JOIN currency c ON o.currency_id = c.id
JOIN variant v ON si.variant_id = v.id
JOIN product p ON v.product_id = p.id AND p.season_id = 39
JOIN price_purchase pp ON p.id = pp.product_id

WHERE
o.channel_id = 1

GROUP BY date_trunc('day'::text, o.date), c.currency;
ALTER TABLE njiv_ftbc_gross_sales OWNER TO postgres;

----------------------------------------------------

CREATE OR REPLACE VIEW njiv_ftbc_merch_cancellations AS
SELECT 
o.date AS date_ts, 
date_trunc('day'::text, o.date) AS date, 
o.id AS order_id, 
o.order_nr, 
o.customer_id, 
cu.is_customer_number, 
c.currency, 
count(si.variant_id) AS unit_count, 
sum(si.unit_price) AS merchandise_sales_value, 
sum(si.tax) AS tax_value, 
sum(si.duty) AS duties_value, 
sum(si.unit_price + si.tax + si.duty) AS gross_sales_value

FROM orders o
LEFT JOIN customer cu ON o.customer_id = cu.id
JOIN link_orders__shipment los ON o.id = los.orders_id
JOIN shipment s ON los.shipment_id = s.id AND s.shipment_class_id = 1
JOIN shipment_item si ON s.id = si.shipment_id AND (si.shipment_item_status_id = ANY (ARRAY[9, 10]))
JOIN currency c ON o.currency_id = c.id
JOIN variant v ON si.variant_id = v.id
JOIN product p ON v.product_id = p.id AND p.season_id = 39

WHERE 
o.channel_id = 1

GROUP BY o.date, date_trunc('day'::text, o.date), o.id, o.order_nr, o.customer_id, cu.is_customer_number, c.currency;

ALTER TABLE njiv_ftbc_merch_cancellations OWNER TO postgres;

-----------------------------------------------------

CREATE OR REPLACE VIEW njiv_ftbc_merch_returns AS 
SELECT 
o.date AS date_ts, 
date_trunc('day'::text, o.date) AS date, 
o.id AS order_id, 
o.order_nr, 
o.customer_id, 
cu.is_customer_number, 
c.currency, 
count(si.variant_id) AS unit_count, 
sum(si.unit_price) AS merchandise_sales_value, 
sum(si.tax) AS tax_value, sum(si.duty) AS duties_value, 
sum(si.unit_price + si.tax + si.duty) AS gross_sales_value

FROM orders o
LEFT JOIN customer cu ON o.customer_id = cu.id
JOIN link_orders__shipment los ON o.id = los.orders_id
JOIN shipment s ON los.shipment_id = s.id
JOIN shipment_item si ON s.id = si.shipment_id
JOIN currency c ON o.currency_id = c.id
JOIN return_item ri ON si.id = ri.shipment_item_id AND ri.return_type_id = 1
JOIN variant v ON si.variant_id = v.id
JOIN product p ON v.product_id = p.id AND p.season_id = 39

WHERE 
(ri.return_item_status_id = ANY (ARRAY[5, 6, 7])) AND 
o.channel_id = 1 

GROUP BY o.date, date_trunc('day'::text, o.date), o.id, o.order_nr, o.customer_id, cu.is_customer_number, c.currency;

ALTER TABLE njiv_ftbc_merch_returns OWNER TO postgres;
-------------------------------------------------

CREATE OR REPLACE VIEW njiv_gross_order_totals_currency AS
SELECT 
tmp.date_ts, 
tmp.date, 
tmp.order_id, 
tmp.order_nr, 
tmp.currency, 
sum(tmp.unit_count) AS unit_count, 
sum(tmp.merchandise_sales_value) AS merchandise_sales_value, 
sum(tmp.tax_value) AS tax_value, 
sum(tmp.duties_value) AS duties_value, 
sum(tmp.shipping_value) AS shipping_value, 
sum(tmp.gift_credit_redeemed) AS gift_credit_redeemed, 
sum(tmp.store_credit_redeemed) AS store_credit_redeemed, 
sum(tmp.gross_sales_value) + sum(tmp.total) AS total_order_value, 
tmp.first_order

FROM ( 
	SELECT 
	o.date AS date_ts, 
	date_trunc('day'::text, o.date) AS date, 
	o.id AS order_id, 
	o.order_nr, 
	c.currency, 
	count(si.variant_id) AS unit_count, 
	sum(si.unit_price) AS merchandise_sales_value, 
	sum(si.tax) AS tax_value, 
	sum(si.duty) AS duties_value, 
	sum(si.unit_price + si.tax + si.duty) AS gross_sales_value, 
	0 AS shipping_value, 
	0 AS gift_credit_redeemed, 0 AS store_credit_redeemed, 0 AS total, 
        CASE WHEN (3 IN ( SELECT order_flag.flag_id FROM orders, order_flag WHERE o.id = orders.id AND orders.id = order_flag.orders_id)) 
	     THEN 'Y'::text
             ELSE 'N'::text
             END AS first_order
        
	FROM 
	orders o 
	JOIN link_orders__shipment los ON o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id AND s.shipment_class_id = 1
	JOIN shipment_item si ON s.id = si.shipment_id 
	JOIN currency c ON o.currency_id = c.id
        
	WHERE si.variant_id <> 49285 AND si.variant_id <> 67158 AND si.variant_id <> 73652 and 
	o.channel_id = 1
        
	GROUP BY 
	o.date, 
	date_trunc('day'::text, o.date), 
	o.id, 
	o.order_nr, 
	c.currency, 
        CASE WHEN (3 IN ( SELECT order_flag.flag_id FROM orders, order_flag WHERE o.id = orders.id AND orders.id = order_flag.orders_id)) 
	     THEN 'Y'::text
             ELSE 'N'::text
             END

UNION 
        SELECT 
	o.date AS date_ts, 
	date_trunc('day'::text, o.date) AS date, 
	o.id AS order_id, 
	o.order_nr, 
	c.currency, 
	0 AS unit_count, 
	0 AS merchandise_sales_value, 
	0 AS tax_value, 
	0 AS duties_value, 
	0 AS gross_sales_value, 
	sum(s.shipping_charge) AS shipping_value, 
	sum(s.gift_credit) AS gift_credit_redeemed, 
	sum(s.store_credit) AS store_credit_redeemed, 
	sum(s.shipping_charge + s.gift_credit + s.store_credit) AS total, 
        CASE WHEN (3 IN ( SELECT order_flag.flag_id FROM orders, order_flag WHERE o.id = orders.id AND orders.id = order_flag.orders_id)) 
	     THEN 'Y'::text
             ELSE 'N'::text
             END AS first_order
        

	FROM
	orders o 
	JOIN link_orders__shipment los ON o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id AND s.shipment_class_id = 1
	JOIN currency c ON o.currency_id = c.id

	WHERE 
	o.channel_id = 1
        
	GROUP BY 
	o.date, 
	date_trunc('day'::text, o.date), 
	o.id, 
	o.order_nr, 
	c.currency, 
        CASE WHEN (3 IN ( SELECT order_flag.flag_id FROM orders, order_flag WHERE o.id = orders.id AND orders.id = order_flag.orders_id)) 
	     THEN 'Y'::text
             ELSE 'N'::text
             END
	) tmp

GROUP BY tmp.date_ts, tmp.order_nr, tmp.date, tmp.order_id, tmp.currency, tmp.first_order
ORDER BY tmp.date_ts, tmp.order_nr;

ALTER TABLE njiv_gross_order_totals_currency OWNER TO postgres;

-------------------------------------------------

CREATE OR REPLACE VIEW njiv_master_free_stock AS
SELECT saleable.product_id, saleable.legacy_sku, sum(saleable.quantity) AS quantity
   FROM ((((


	SELECT
	p.id as product_id,
	p.legacy_sku,
	sum(q.quantity) AS quantity

	FROM
	quantity q
	JOIN variant v ON q.variant_id = v.id
	JOIN product p ON v.product_id = p.id

	WHERE
	NOT q.location_id IN (SELECT location.id FROM location location WHERE location.type_id <> 1)
	AND q.channel_id = 1

	GROUP BY
	p.id, p.legacy_sku

UNION ALL

        SELECT
	p.id as product_id,
	p.legacy_sku,
	- count(*) AS quantity

        FROM
	reservation r
	JOIN variant v ON r.variant_id = v.id and r.status_id = 2
	JOIN product p ON v.product_id = p.id

        WHERE r.channel_id = 1

	GROUP BY p.id, p.legacy_sku
	)

UNION ALL

        SELECT
	p.id as product_id,
	p.legacy_sku,
	- count(*) AS quantity

	FROM
	orders o
	JOIN link_orders__shipment los ON o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id
	JOIN shipment_item si ON s.id = si.shipment_id AND si.shipment_item_status_id < 3
        join variant v on si.variant_id = v.id
        join product p on v.product_id = p.id

	WHERE o.channel_id = 1
        GROUP BY p.id, p.legacy_sku
	)

UNION ALL

	SELECT
	p.id as product_id,
	p.legacy_sku,
	- count(*) AS quantity

	FROM
	orders o
	JOIN link_orders__shipment los ON o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id
	JOIN shipment_item si ON s.id = si.shipment_id AND si.shipment_item_status_id = 10
	JOIN cancelled_item ci on si.id = ci.shipment_item_id AND ci.adjusted = 0
	JOIN variant v on si.variant_id = v.id
	JOIN product p on v.product_id = p.id

	WHERE  o.channel_id = 1

	GROUP BY p.id, p.legacy_sku
	) 

UNION ALL
	SELECT
	p.id as product_id,
	p.legacy_sku,
	- count(*) AS quantity

	FROM
	stock_transfer o
	JOIN link_stock_transfer__shipment los ON o.id = los.stock_transfer_id
	JOIN shipment s ON los.shipment_id = s.id
	JOIN shipment_item si ON s.id = si.shipment_id AND si.shipment_item_status_id < 3
        join variant v on si.variant_id = v.id
        join product p on v.product_id = p.id

	WHERE o.channel_id = 1
        GROUP BY p.id, p.legacy_sku
        ) saleable

GROUP BY saleable.product_id, saleable.legacy_sku;

ALTER TABLE njiv_master_free_stock OWNER TO postgres;


-------------------------------------------------
CREATE OR REPLACE VIEW njiv_master_product_attributes AS
SELECT
p.id AS product_id,
s.season,
d.designer,
dep.department,
c.classification,
pt.product_type,
st.sub_type,
pa.name,
pdc.visible,
pdc.live,
p.style_number,
p.legacy_sku,
pa.description,
col.colour,
p.hs_code_id,
cf.colour_filter AS mastercolor,
pdc.upload_date,
sum(po.ordered) AS ordered_quantity,
pp.uk_landed_cost,
round(pd.price * scr.conversion_rate, 3) AS original_selling_price,
CASE WHEN md.id is not null
	THEN round(pd.price * scr.conversion_rate * ((100::numeric - md.percentage) / 100::numeric), 3)
	ELSE round(pd.price * scr.conversion_rate, 3)
    	END AS selling_price,
pac.category AS markdown_category,
md.percentage

FROM product p
LEFT JOIN price_default pd ON pd.product_id = p.id
LEFT JOIN price_adjustment md ON (md.product_id = p.id AND md.date_start <= now()::date AND md.date_finish > now()::date )
LEFT JOIN price_adjustment_category pac ON md.category_id = pac.id
LEFT JOIN sub_type st ON p.sub_type_id = st.id
LEFT JOIN hs_code hs ON p.hs_code_id = hs.id
LEFT JOIN product_type pt ON p.product_type_id = pt.id
LEFT JOIN classification c ON p.classification_id = c.id
LEFT JOIN designer d ON p.designer_id = d.id
LEFT JOIN colour col ON p.colour_id = col.id
LEFT JOIN filter_colour_mapping fcm ON p.colour_id = fcm.colour_id
LEFT JOIN legacy_attributes la ON p.id = la.product_id
JOIN season s ON p.season_id = s.id
JOIN product_attribute pa ON p.id = pa.product_id
JOIN product_department dep ON pa.product_department_id = dep.id
JOIN price_purchase pp ON p.id = pp.product_id
JOIN sales_conversion_rate scr ON pd.currency_id = scr.source_currency
JOIN colour_filter cf ON fcm.filter_colour_id = cf.id
LEFT JOIN product_channel pdc on p.id = pdc.product_id
LEFT JOIN (select product_id, ordered from product.stock_summary where channel_id = 1) po on p.id = po.product_id

WHERE scr.destination_currency = 1
AND 'now'::text::date > scr.date_start
AND (scr.date_finish IS NULL OR 'now'::text::date < scr.date_finish)
AND pdc.channel_id = 1


GROUP BY p.id,
s.season,
d.designer,
dep.department, c.classification, pt.product_type, st.sub_type, pa.name, pdc.visible, pdc.live, p.style_number, p.legacy_sku, pa.description, col.colour, 

p.hs_code_id, cf.colour_filter, pdc.upload_date, pp.uk_landed_cost, round(pd.price * scr.conversion_rate, 3),

CASE WHEN md.id is not null THEN round(pd.price * scr.conversion_rate * ((100::numeric - md.percentage) / 100::numeric), 3)
ELSE round(pd.price * scr.conversion_rate, 3)
END,
pac.category,
md.percentage;
ALTER TABLE njiv_master_product_attributes OWNER TO postgres;
-------------------------------------------------

CREATE OR REPLACE VIEW njiv_merch_sales_season AS
SELECT 
date_trunc('day'::text, o.date) AS date, 
c.currency, 
se.season, 
count(si.id) AS units, 
sum(si.unit_price) AS merchandise_sales_value, 
sum(si.tax) AS tax_value, 
sum(si.duty) AS duties_value, 
sum(si.unit_price + si.tax + si.duty) AS gross_sales_value

FROM 
orders o 
JOIN link_orders__shipment los ON o.id = los.orders_id
JOIN shipment s ON los.shipment_id = s.id AND s.shipment_class_id = 1
JOIN shipment_item si ON s.id = si.shipment_id 
JOIN variant v on si.variant_id = v.id
JOIN product p on v.product_id = p.id
JOIN season se on p.season_id = se.id
JOIN currency c ON o.currency_id = c.id


WHERE 
si.variant_id <> 49285 AND si.variant_id <> 67158 AND si.variant_id <> 73652 AND 
o.channel_id = 1

GROUP BY date_trunc('day'::text, o.date), c.currency, se.season;
ALTER TABLE njiv_merch_sales_season OWNER TO postgres;

-------------------------------------------------

CREATE OR REPLACE VIEW njiv_net_sales AS

(
SELECT 
date_trunc('day'::text, o.date) AS date, 
'Order' AS action, 
c.id AS customer_id,
c.is_customer_number, 
o.id AS orders_id, 
o.order_nr, 
o.currency_id, 
oa2.country AS shipping_country, 
oa.country AS billing_country, 
v.product_id, 
CASE WHEN md.id IS NOT NULL 
     THEN round(pd.price * scr.conversion_rate * ((100::numeric - md.percentage) / 100::numeric), 3)
     ELSE round(pd.price * scr.conversion_rate, 3)
     END AS selling_price, 
1 AS order_units, 
si.unit_price AS order_merch_value, 
pp.uk_landed_cost AS order_cost_value, 
0 AS cancel_units, 
0 AS cancel_merch_value, 
0 AS cancel_cost_value, 
0 AS return_units, 
0 AS return_merch_value, 
0 AS return_cost_value, 
1 AS net_units, 
si.unit_price AS net_merch_value, 
pp.uk_landed_cost AS net_cost_value


FROM orders o
   JOIN link_orders__shipment los ON o.id = los.orders_id
   JOIN shipment s ON los.shipment_id = s.id AND s.shipment_class_id = 1
   JOIN shipment_item si ON s.id = si.shipment_id
   JOIN variant v ON si.variant_id = v.id
   JOIN product p ON v.product_id = p.id
   JOIN customer c on c.id = o.customer_id
   JOIN order_address oa on o.invoice_address_id = oa.id
   JOIN order_address oa2 on s.shipment_address_id = oa2.id
   LEFT JOIN price_default pd ON pd.product_id = p.id
   LEFT JOIN price_adjustment md ON md.product_id = p.id AND md.date_start <= now()::date AND md.date_finish > now()::date
   JOIN sales_conversion_rate scr ON pd.currency_id = scr.source_currency
   JOIN price_purchase pp ON p.id = pp.product_id


WHERE 
scr.destination_currency = 1 AND 'now'::text::date > scr.date_start AND (scr.date_finish IS NULL OR 'now'::text::date < scr.date_finish)
AND o.channel_id = 1

UNION ALL

SELECT 
date_trunc('day'::text, sisl.date) AS date, 
'cancel' AS action, 
c.id AS customer_id, 
c.is_customer_number, 
o.id AS orders_id, 
o.order_nr, 
o.currency_id, 
oa2.country AS shipping_country, 
oa.country AS billing_country, 
v.product_id, 
CASE WHEN md.id IS NOT NULL 
     THEN round(pd.price * scr.conversion_rate * ((100::numeric - md.percentage) / 100::numeric), 3)
     ELSE round(pd.price * scr.conversion_rate, 3)
     END AS selling_price,
0 AS order_units, 
0 AS order_merch_value, 
0 AS order_cost_value, 
1 AS cancel_units, 
si.unit_price AS cancel_merch_value, 
pp.uk_landed_cost AS cancel_cost_value, 
0 AS return_units, 
0 AS return_merch_value, 
0 AS return_cost_value, 
(-1) AS net_units, 
- si.unit_price AS net_merch_value, 
- pp.uk_landed_cost AS net_cost_value


FROM 

orders o
   JOIN link_orders__shipment los ON o.id = los.orders_id
   JOIN shipment s ON los.shipment_id = s.id AND s.shipment_class_id = 1
   JOIN shipment_item si ON s.id = si.shipment_id
   JOIN variant v ON si.variant_id = v.id
   JOIN product p ON v.product_id = p.id
   JOIN customer c on c.id = o.customer_id
   JOIN order_address oa on o.invoice_address_id = oa.id
   JOIN order_address oa2 on s.shipment_address_id = oa2.id
   LEFT JOIN price_default pd ON pd.product_id = p.id
   LEFT JOIN price_adjustment md ON md.product_id = p.id AND md.date_start <= now()::date AND md.date_finish > now()::date
   JOIN sales_conversion_rate scr ON pd.currency_id = scr.source_currency
   JOIN price_purchase pp ON p.id = pp.product_id
   JOIN shipment_item_status_log sisl on si.id = sisl.shipment_item_id AND sisl.shipment_item_status_id = 10


WHERE 
scr.destination_currency = 1 AND 'now'::text::date > scr.date_start AND (scr.date_finish IS NULL OR 'now'::text::date < scr.date_finish)
AND o.channel_id = 1)
UNION ALL
SELECT 
date_trunc('day'::text, risl.date) AS date, 
'return' AS action, 
c.id AS customer_id,
c.is_customer_number, 
o.id AS orders_id, 
o.order_nr, 
o.currency_id, 
oa2.country AS shipping_country, 
oa.country AS billing_country, 
v.product_id, 
CASE WHEN md.id IS NOT NULL 
     THEN round(pd.price * scr.conversion_rate * ((100::numeric - md.percentage) / 100::numeric), 3)
     ELSE round(pd.price * scr.conversion_rate, 3)
     END AS selling_price,
0 AS order_units, 
0 AS order_merch_value, 
0 AS order_cost_value,
0 AS cancel_units, 
0 AS cancel_merch_value, 
0 AS cancel_cost_value, 
1 AS return_units, 
si.unit_price AS return_merch_value, 
pp.uk_landed_cost AS return_cost_value, 
(-1) AS net_units, 
- si.unit_price AS net_merch_value, 
- pp.uk_landed_cost AS net_cost_value


FROM 
orders o
   JOIN link_orders__shipment los ON o.id = los.orders_id
   JOIN shipment s ON los.shipment_id = s.id
   JOIN shipment_item si ON s.id = si.shipment_id
   JOIN variant v ON si.variant_id = v.id
   JOIN product p ON v.product_id = p.id
   JOIN customer c on c.id = o.customer_id
   JOIN order_address oa on o.invoice_address_id = oa.id
   JOIN order_address oa2 on s.shipment_address_id = oa2.id
   LEFT JOIN price_default pd ON pd.product_id = p.id
   LEFT JOIN price_adjustment md ON md.product_id = p.id AND md.date_start <= now()::date AND md.date_finish > now()::date
   JOIN sales_conversion_rate scr ON pd.currency_id = scr.source_currency
   JOIN price_purchase pp ON p.id = pp.product_id
   JOIN return_item ri on si.id = ri.shipment_item_id AND ri.return_type_id = 1
   JOIN return_item_status_log risl on ri.id = risl.return_item_id AND risl.return_item_status_id = 7


WHERE 
scr.destination_currency = 1 AND 'now'::text::date > scr.date_start AND (scr.date_finish IS NULL OR 'now'::text::date < scr.date_finish)
AND o.channel_id = 1;

ALTER TABLE njiv_net_sales OWNER TO postgres;


-------------------------------------------------
CREATE OR REPLACE VIEW njiv_orders AS 
SELECT 
tmp.date_ts, 
tmp.date, 
tmp.order_id, 
tmp.order_nr, 
tmp.customer_id, 
tmp.is_customer_number, 
tmp.currency_id, 
tmp.currency, 
tmp.country, 
sum(tmp.unit_count) AS unit_count, 
sum(tmp.merchandise_sales_value) AS merchandise_sales_value, 
sum(tmp.tax_value) AS tax_value, 
sum(tmp.duties_value) AS duties_value, 
sum(tmp.shipping_value) AS shipping_value, 
sum(tmp.gift_credit_redeemed) AS gift_credit_redeemed, 
sum(tmp.store_credit_redeemed) AS store_credit_redeemed, 
sum(tmp.gross_sales_value) + sum(tmp.total) AS total_order_value, tmp.first_order
FROM 
( 
	SELECT 
	o.date AS date_ts, 
	date_trunc('day'::text, o.date) AS date, 
	o.id AS order_id, 
	o.order_nr, 
	o.customer_id, 
	cu.is_customer_number, 
	o.currency_id, 
	c.currency, 
	oa.country, 
	count(si.variant_id) AS unit_count, 
	sum(si.unit_price) AS merchandise_sales_value, 
	sum(si.tax) AS tax_value, 
	sum(si.duty) AS duties_value, 
	sum(si.unit_price + si.tax + si.duty) AS gross_sales_value, 
	0 AS shipping_value, 
	0 AS gift_credit_redeemed, 
	0 AS store_credit_redeemed, 0 AS total, 
        CASE WHEN (3 IN ( SELECT order_flag.flag_id FROM orders, order_flag WHERE o.id = orders.id AND orders.id = order_flag.orders_id)) 
	     THEN 'Y'::text
             ELSE 'N'::text
             END AS first_order
        
	FROM 
	orders o 
	JOIN link_orders__shipment los on o.id = los.orders_id
	JOIN shipment s on los.shipment_id = s.id AND s.shipment_class_id = 1
	JOIN shipment_item si on s.id = si.shipment_id
	JOIN currency c on o.currency_id = c.id
	JOIN order_address oa on o.invoice_address_id = oa.id     	
	LEFT JOIN customer cu ON o.customer_id = cu.id
     
	WHERE 
	si.variant_id <> 49285 AND si.variant_id <> 67158 AND si.variant_id <> 73652
	AND o.channel_id = 1
     
	GROUP BY 
	o.date, 
	date_trunc('day'::text, o.date), 
	o.id, 
	o.order_nr, 
	o.customer_id, 
	cu.is_customer_number, 
	o.currency_id, 
	c.currency, 
	oa.country, 
        CASE WHEN (3 IN ( SELECT order_flag.flag_id FROM orders, order_flag WHERE o.id = orders.id AND orders.id = order_flag.orders_id)) 
             THEN 'Y'::text
             ELSE 'N'::text
             END
UNION 
	SELECT o.date AS date_ts, 
	date_trunc('day'::text, o.date) AS date, 
	o.id AS order_id, 
	o.order_nr, 
	o.customer_id, 
	cu.is_customer_number, 
	o.currency_id, 
	c.currency, 
	oa.country, 
	0 AS unit_count, 
	0 AS merchandise_sales_value, 
	0 AS tax_value, 
	0 AS duties_value, 
	0 AS gross_sales_value, 
	sum(s.shipping_charge) AS shipping_value, 
	sum(s.gift_credit) AS gift_credit_redeemed, 
	sum(s.store_credit) AS store_credit_redeemed, 
	sum(s.shipping_charge + s.gift_credit + s.store_credit) AS total, 
        CASE WHEN (3 IN ( SELECT order_flag.flag_id FROM orders, order_flag WHERE o.id = orders.id AND orders.id = order_flag.orders_id)) 
	     THEN 'Y'::text
             ELSE 'N'::text
             END AS first_order
        
	FROM 
	orders o 
	JOIN link_orders__shipment los on o.id = los.orders_id
	JOIN shipment s on los.shipment_id = s.id AND s.shipment_class_id = 1
	JOIN currency c on o.currency_id = c.id
	JOIN order_address oa on o.invoice_address_id = oa.id     	
	LEFT JOIN customer cu ON o.customer_id = cu.id


     	WHERE 
	o.channel_id = 1
  
	GROUP BY 
	o.date, 
	date_trunc('day'::text, o.date), 
	o.id, 
	o.order_nr, 
	o.customer_id, 
	cu.is_customer_number, 
	o.currency_id, 
	c.currency, 
	oa.country, 
        CASE WHEN (3 IN ( SELECT order_flag.flag_id FROM orders, order_flag WHERE o.id = orders.id AND orders.id = order_flag.orders_id)) 
	     THEN 'Y'::text
             ELSE 'N'::text
             END
) tmp
GROUP BY 
tmp.date_ts, tmp.order_nr, tmp.date, tmp.order_id, tmp.customer_id, tmp.is_customer_number, tmp.currency_id, tmp.currency, tmp.country, tmp.first_order

ORDER BY tmp.date_ts, tmp.order_nr;

ALTER TABLE njiv_orders OWNER TO postgres;


-------------------------------------------------
CREATE OR REPLACE VIEW njiv_preorder_returns_dispatchdate AS

SELECT 
sisl.date AS date_ts, 
date_trunc('day'::text, sisl.date) AS date, 
o.id AS order_id, 
o.order_nr, 
o.customer_id, 
cu.is_customer_number, 
c.currency, 
oa.country, 
count(si.variant_id) AS unit_count, 
sum(si.unit_price) AS merchandise_sales_value, 
sum(si.tax) AS tax_value, 
sum(si.duty) AS duties_value, 
sum(si.unit_price + si.tax + si.duty) AS gross_sales_value, 
0 AS shipping_value, 
0 AS gift_credit_redeemed, 
0 AS store_credit_redeemed, 
0 AS total, 
CASE WHEN (3 IN ( SELECT order_flag.flag_id FROM orders, order_flag WHERE o.id = orders.id AND orders.id = order_flag.orders_id)) 
     THEN 'Y'::text
     ELSE 'N'::text
     END AS first_order

FROM orders o
LEFT JOIN customer cu ON o.customer_id = cu.id
JOIN link_orders__shipment los ON o.id = los.orders_id
JOIN shipment s ON los.shipment_id = s.id
JOIN shipment_item si ON s.id = si.shipment_id
JOIN currency c ON o.currency_id = c.id
JOIN order_address oa ON o.invoice_address_id = oa.id
JOIN return_item ri ON si.id = ri.shipment_item_id
JOIN order_flag of ON o.id = of.orders_id
LEFT JOIN shipment_item_status_log sisl ON si.id = sisl.shipment_item_id

WHERE (ri.return_item_status_id = ANY (ARRAY[5, 6, 7])) AND ri.return_type_id = 1 AND of.flag_id = 45 AND sisl.shipment_item_status_id = 4
AND o.channel_id = 1

GROUP BY sisl.date, date_trunc('day'::text, sisl.date), o.id, o.order_nr, o.customer_id, cu.is_customer_number, c.currency, oa.country, 
CASE
    WHEN (3 IN ( SELECT order_flag.flag_id
       FROM orders, order_flag
      WHERE o.id = orders.id AND orders.id = order_flag.orders_id)) THEN 'Y'::text
    ELSE 'N'::text
END;
ALTER TABLE njiv_preorder_returns_dispatchdate OWNER TO postgres;
-------------------------------------------------

CREATE OR REPLACE VIEW njiv_prod_orders AS 
 
SELECT so.product_id, sum(soi.quantity) AS qty

FROM 
purchase_order po 
JOIN stock_order so on so.purchase_order_id = po.id
JOIN stock_order_item soi on so.id = soi.stock_order_id

WHERE so.type_id = 1 and po.channel_id = 1
GROUP BY so.product_id;


ALTER TABLE njiv_prod_orders OWNER TO postgres;
-------------------------------------------------

CREATE OR REPLACE VIEW njiv_product_ordered_qty AS 

SELECT 
po.product_id, 
po.qty AS ordered_quantity, 
round(po.qty::numeric * pp.uk_landed_cost, 2) AS cost_ordered

FROM 
njiv_prod_orders po
JOIN price_purchase pp on po.product_id = pp.product_id;


ALTER TABLE njiv_product_ordered_qty OWNER TO postgres;

-------------------------------------------------
CREATE OR REPLACE VIEW njiv_pws_log_stock_reporting AS 
SELECT 
p.id AS product_id, 
v.id AS variant_id, 
pa."action", 
pw.pws_action_id, 
pw.quantity, 
date_trunc('day'::text, pw.date) AS date, 
date_trunc('day'::text, fso.date) AS first_sold_out_date, 
CASE WHEN pw.pws_action_id = 11 OR pw.pws_action_id = 10 OR pw.pws_action_id = 7 OR pw.pws_action_id = 8 OR pw.pws_action_id = 9 OR pw.pws_action_id = 12     

     THEN pw.quantity::bigint
     ELSE 0::bigint
     END AS uploadunits, 
CASE WHEN pw.pws_action_id = 2 OR pw.pws_action_id = 3 OR pw.pws_action_id = 4 OR pw.pws_action_id = 5 THEN (pw.quantity * -1)::bigint
     ELSE 0::bigint
     END AS salesunits, 
CASE WHEN pw.pws_action_id = 11 OR pw.pws_action_id = 10 OR pw.pws_action_id = 7 OR pw.pws_action_id = 1 OR pw.pws_action_id = 8 OR pw.pws_action_id = 9 OR 

pw.pws_action_id = 12 OR pw.pws_action_id = 13 
     THEN pw.quantity::bigint
     ELSE 0::bigint
     END AS uploadamendedunits, 
CASE WHEN pw.pws_action_id = 11 OR pw.pws_action_id = 10 OR pw.pws_action_id = 7 OR pw.pws_action_id = 8 OR pw.pws_action_id = 9 OR pw.pws_action_id = 12     

 THEN pw.quantity::bigint::numeric::double precision * mpa.uk_landed_cost::double precision
     ELSE 0::bigint::numeric::double precision
     END AS uploadcost, 
CASE WHEN pw.pws_action_id = 2 OR pw.pws_action_id = 3 OR pw.pws_action_id = 4 OR pw.pws_action_id = 5 
     THEN (pw.quantity * -1)::bigint::numeric::double precision * mpa.uk_landed_cost::double precision
     ELSE 0::bigint::numeric::double precision
     END AS salescost, 
CASE WHEN pw.pws_action_id = 11 OR pw.pws_action_id = 10 OR pw.pws_action_id = 7 OR pw.pws_action_id = 1 OR pw.pws_action_id = 8 OR pw.pws_action_id = 9 OR 

pw.pws_action_id = 12 OR pw.pws_action_id = 13 
     THEN pw.quantity::bigint::numeric::double precision * mpa.uk_landed_cost::double precision
     ELSE 0::bigint::numeric::double precision
     END AS uploadamendedcost,
mpa.season, 
mpa.designer, 
mpa.classification, 
mpa.product_type, 
mpa.sub_type, 
mpa.name, 
mpa.visible, 
mpa.live, 
mpa.style_number, 
mpa.legacy_sku, 
mpa.description, 
mpa.colour, 
mpa.mastercolor, 
mpa.original_selling_price, 
mpa.uk_landed_cost, 
mpa.selling_price, 
mpa.upload_date

FROM product p
LEFT JOIN njiv_1st_sold_out fso ON p.id = fso.product_id
JOIN njiv_master_product_attributes mpa ON p.id = mpa.product_id 
JOIN variant v ON p.id = v.product_id 
JOIN log_pws_stock pw ON v.id = pw.variant_id and pw.channel_id = 1
JOIN pws_action pa ON pw.pws_action_id = pa.id; 

ALTER TABLE njiv_pws_log_stock_reporting OWNER TO postgres;


-------------------------------------------------

CREATE OR REPLACE VIEW njiv_returns AS
SELECT o.date AS date_ts, 
date_trunc('day'::text, o.date) AS date, 
o.id AS order_id, 
o.order_nr, 
o.customer_id, 
cu.is_customer_number, 
c.currency, 
oa.country, 
count(si.variant_id) AS unit_count, 
sum(si.unit_price) AS merchandise_sales_value, 
sum(si.tax) AS tax_value, 
sum(si.duty) AS duties_value, 
sum(si.unit_price + si.tax + si.duty) AS gross_sales_value, 
0 AS shipping_value, 
0 AS gift_credit_redeemed, 
0 AS store_credit_redeemed, 
0 AS total, 
CASE WHEN (3 IN ( SELECT order_flag.flag_id FROM orders, order_flag WHERE o.id = orders.id AND orders.id = order_flag.orders_id)) 
     THEN 'Y'::text
     ELSE 'N'::text
     END AS first_order, 'N'::text AS whole_order

FROM orders o
JOIN link_orders__shipment los ON o.id = los.orders_id
JOIN shipment s ON los.shipment_id = s.id
JOIN shipment_item si ON s.id = si.shipment_id
JOIN currency c ON o.currency_id = c.id
JOIN order_address oa ON o.invoice_address_id = oa.id
JOIN return_item ri ON si.id = ri.shipment_item_id AND (ri.return_item_status_id = ANY (ARRAY[5, 6, 7])) AND ri.return_type_id = 1
LEFT JOIN customer cu ON o.customer_id = cu.id

WHERE si.variant_id <> 49285 AND si.variant_id <> 67158 AND si.variant_id <> 73652 
AND o.channel_id = 1

GROUP BY 
o.date, 
date_trunc('day'::text, o.date), 
o.id, o.order_nr, 
o.customer_id, 
cu.is_customer_number, 
c.currency, 
oa.country, 
   CASE
       WHEN (3 IN ( SELECT order_flag.flag_id
          FROM orders, order_flag
         WHERE o.id = orders.id AND orders.id = order_flag.orders_id)) THEN 'Y'::text
       ELSE 'N'::text
   END;
ALTER TABLE njiv_returns OWNER TO postgres;



-------------------------------------------------
CREATE OR REPLACE VIEW njiv_rm_cancellations AS 
 SELECT tmp.date_ts, tmp.date, tmp.order_id, tmp.order_nr, tmp.customer_id, tmp.is_customer_number, tmp.currency, tmp.country, sum(tmp.unit_count) AS 

unit_count, sum(tmp.merchandise_sales_value) AS merchandise_sales_value, sum(tmp.tax_value) AS tax_value, sum(tmp.duties_value) AS duties_value, 

sum(tmp.shipping_value) AS shipping_value, sum(tmp.gift_credit_redeemed) AS gift_credit_redeemed, sum(tmp.store_credit_redeemed) AS store_credit_redeemed, 

sum(tmp.gross_sales_value) + sum(tmp.total) AS total_order_value, tmp.first_order, max(tmp.whole_order) AS max
   FROM ( SELECT o.date AS date_ts, date_trunc('day'::text, o.date) AS date, o.id AS order_id, o.order_nr, o.customer_id, cu.is_customer_number, c.currency, 

oa.country, count(si.variant_id) AS unit_count, sum(si.unit_price) AS merchandise_sales_value, sum(si.tax) AS tax_value, sum(si.duty) AS duties_value, 

sum(si.unit_price + si.tax + si.duty) AS gross_sales_value, 0 AS shipping_value, 0 AS gift_credit_redeemed, 0 AS store_credit_redeemed, 0 AS total, 
                CASE
                    WHEN (3 IN ( SELECT order_flag.flag_id
                       FROM orders, order_flag
                      WHERE o.id = orders.id AND orders.id = order_flag.orders_id)) THEN 'Y'::text
                    ELSE 'N'::text
                END AS first_order, 'N'::text AS whole_order
           FROM orders o
      LEFT JOIN customer cu ON o.customer_id = cu.id
   JOIN link_orders__shipment los ON o.id = los.orders_id
   JOIN shipment s ON los.shipment_id = s.id
   JOIN shipment_item si ON s.id = si.shipment_id AND s.shipment_class_id = 1 AND (si.shipment_item_status_id = ANY (ARRAY[9, 10]))
   JOIN currency c ON o.currency_id = c.id
   JOIN order_address oa ON o.invoice_address_id = oa.id
   JOIN order_flag of on o.id = of.orders_id and of.flag_id = 45

WHERE si.variant_id <> 49285 AND si.variant_id <> 67158 AND si.variant_id <> 73652 AND o.channel_id = 1
  GROUP BY o.date, date_trunc('day'::text, o.date), o.id, o.order_nr, o.customer_id, cu.is_customer_number, c.currency, oa.country, 
CASE
    WHEN (3 IN ( SELECT order_flag.flag_id
       FROM orders, order_flag
      WHERE o.id = orders.id AND orders.id = order_flag.orders_id)) THEN 'Y'::text
    ELSE 'N'::text
END
UNION 
         SELECT o.date AS date_ts, date_trunc('day'::text, o.date) AS date, o.id AS order_id, o.order_nr, o.customer_id, cu.is_customer_number, c.currency, 

oa.country, 0 AS unit_count, 0 AS merchandise_sales_value, 0 AS tax_value, 0 AS duties_value, 0 AS gross_sales_value, sum(s.shipping_charge) AS 

shipping_value, sum(s.gift_credit) AS gift_credit_redeemed, sum(s.store_credit) AS store_credit_redeemed, sum(s.shipping_charge + s.gift_credit + 

s.store_credit) AS total, 
                CASE
                    WHEN (3 IN ( SELECT order_flag.flag_id
                       FROM orders, order_flag
                      WHERE o.id = orders.id AND orders.id = order_flag.orders_id)) THEN 'Y'::text
                    ELSE 'N'::text
                END AS first_order, 'Y'::text AS whole_order
           FROM orders o
      LEFT JOIN customer cu ON o.customer_id = cu.id
   JOIN link_orders__shipment los ON o.id = los.orders_id
   JOIN shipment s ON los.shipment_id = s.id AND s.shipment_class_id = 1 AND s.shipment_status_id = 5
   JOIN currency c ON o.currency_id = c.id
   JOIN order_address oa ON o.invoice_address_id = oa.id
   JOIN order_flag of on o.id = of.orders_id and of.flag_id = 45

  WHERE o.channel_id = 1
  GROUP BY o.date, date_trunc('day'::text, o.date), o.id, o.order_nr, o.customer_id, cu.is_customer_number, c.currency, oa.country, 
CASE
    WHEN (3 IN ( SELECT order_flag.flag_id
       FROM orders, order_flag
      WHERE o.id = orders.id AND orders.id = order_flag.orders_id)) THEN 'Y'::text
    ELSE 'N'::text
END) tmp
  GROUP BY tmp.date_ts, tmp.order_nr, tmp.date, tmp.order_id, tmp.customer_id, tmp.is_customer_number, tmp.currency, tmp.country, tmp.first_order
  ORDER BY tmp.date_ts, tmp.order_nr;

ALTER TABLE njiv_rm_cancellations OWNER TO postgres;
-------------------------------------------------
CREATE OR REPLACE VIEW njiv_rm_daily_totals_currency AS

SELECT
tmp.date,
tmp.currency,
sum(tmp.order_count) AS order_count,
sum(tmp.units) AS units,
sum(tmp.merchandise_sales_value) AS merchandise_sales_value,
sum(tmp.tax_value) AS tax_value,
sum(tmp.duties_value) AS duties_value,
sum(tmp.gross_sales_value) AS gross_sales_value,
sum(tmp.shipping_value) AS shipping_value,
sum(tmp.gift_credit_redeemed) AS gift_credit_redeemed,
sum(tmp.store_credit_redeemed) AS store_credit_redeemed,
sum(tmp.total) AS gross_shipping_total

FROM
(
	SELECT date_trunc('day'::text, o.date) AS date,
	c.currency,
	count(DISTINCT o.order_nr) AS order_count,
	count(si.id) AS units,
	sum(si.unit_price) AS merchandise_sales_value,
	sum(si.tax) AS tax_value,
	sum(si.duty) AS duties_value,
	sum(si.unit_price + si.tax + si.duty) AS gross_sales_value,
	0 AS shipping_value,
	0 AS gift_credit_redeemed,
	0 AS store_credit_redeemed,
	0 AS total,
	0 AS new_order_count,
	0 AS new_units,
	0 AS new_merchandise_sales_value,
	0 AS new_tax_value,
	0 AS new_duties_value,
	0 AS new_gross_sales_value,
	0 AS new_shipping_value,
	0 AS new_gift_credit_redeemed,
	0 AS new_store_credit_redeemed,
	0 AS new_total

	FROM
	orders o
	JOIN link_orders__shipment los ON o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id AND s.shipment_class_id = 1
	JOIN shipment_item si ON s.id = si.shipment_id
	JOIN currency c ON o.currency_id = c.id
	JOIN order_flag of ON o.id = of.orders_id AND of.flag_id = 45

	WHERE si.variant_id <> 49285 AND si.variant_id <> 67158 AND si.variant_id <> 73652
	AND o.channel_id = 1

        GROUP BY date_trunc('day'::text, o.date), c.currency

UNION
        SELECT date_trunc('day'::text, o.date) AS date,
	c.currency,
	0 AS order_count,
	0 AS units,
	0 AS merchandise_sales_value,
	0 AS tax_value,
	0 AS duties_value,
	0 AS gross_sales_value,
	sum(s.shipping_charge) AS shipping_value,
	sum(s.gift_credit) AS gift_credit_redeemed,
	sum(s.store_credit) AS store_credit_redeemed,
	sum(s.shipping_charge + s.gift_credit + s.store_credit) AS total,
	0 AS new_order_count,
	0 AS new_units,
	0 AS new_merchandise_sales_value,
	0 AS new_tax_value,
	0 AS new_duties_value,
	0 AS new_gross_sales_value,
	0 AS new_shipping_value,
	0 AS new_gift_credit_redeemed,
	0 AS new_store_credit_redeemed,
	0 AS new_total

	FROM orders o
	JOIN link_orders__shipment los ON o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id AND s.shipment_class_id = 1
	JOIN currency c ON o.currency_id = c.id
	JOIN order_flag of ON o.id = of.orders_id AND of.flag_id = 45

	WHERE o.channel_id = 1

	GROUP BY date_trunc('day'::text, o.date), c.currency
	) tmp
GROUP BY tmp.date, tmp.currency;

ALTER TABLE njiv_rm_daily_totals_currency OWNER TO postgres;

-------------------------------------------------

CREATE OR REPLACE VIEW njiv_rm_daily_totals_currency_dispatch AS 
 
SELECT 
tmp.date, 
tmp.currency, 
sum(tmp.units) AS units, 
sum(tmp.merchandise_sales_value) AS merchandise_sales_value, 
sum(tmp.tax_value) AS tax_value, 
sum(tmp.duties_value) AS duties_value, 
sum(tmp.gross_sales_value) AS gross_sales_value, 
sum(tmp.shipping_value) AS shipping_value, 
sum(tmp.gift_credit_redeemed) AS gift_credit_redeemed, 
sum(tmp.store_credit_redeemed) AS store_credit_redeemed, 
sum(tmp.total) AS gross_shipping_total

FROM 
	( 
	SELECT date_trunc('day'::text, ssl.date) AS date, 
	c.currency, 
	count(si.id) AS units, 
	sum(si.unit_price) AS merchandise_sales_value, 
	sum(si.tax) AS tax_value, 
	sum(si.duty) AS duties_value, 
	sum(si.unit_price + si.tax + si.duty) AS gross_sales_value, 
	0 AS shipping_value, 
	0 AS gift_credit_redeemed, 
	0 AS store_credit_redeemed, 0 AS total
        
	FROM orders o
      	JOIN link_orders__shipment los ON o.id = los.orders_id
   	JOIN shipment s ON los.shipment_id = s.id
   	JOIN shipment_item si ON s.id = si.shipment_id
   	JOIN currency c ON o.currency_id = c.id
   	JOIN order_flag of ON o.id = of.orders_id
   	JOIN shipment_status_log ssl ON s.id = ssl.shipment_id
  	
	WHERE s.shipment_class_id = 1 AND of.flag_id = 45 AND ssl.shipment_status_id = 4 AND o.channel_id = 1
	GROUP BY date_trunc('day'::text, ssl.date), c.currency
	
UNION 
       SELECT date_trunc('day'::text, ssl.date) AS date, 
	c.currency, 
	0 AS units, 
	0 AS merchandise_sales_value, 
	0 AS tax_value, 
	0 AS duties_value, 
	0 AS gross_sales_value, 
	sum(s.shipping_charge) AS shipping_value, 
	sum(s.gift_credit) AS gift_credit_redeemed, 
	sum(s.store_credit) AS store_credit_redeemed, 
	sum(s.shipping_charge + s.gift_credit + s.store_credit) AS total
        
	FROM orders o
      	JOIN link_orders__shipment los ON o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id
	JOIN currency c ON o.currency_id = c.id
	JOIN order_flag of ON o.id = of.orders_id
	JOIN shipment_status_log ssl ON s.id = ssl.shipment_id
 
	WHERE s.shipment_class_id = 1 AND of.flag_id = 45 AND ssl.shipment_status_id = 4 AND o.channel_id = 1

	GROUP BY date_trunc('day'::text, ssl.date), c.currency
	) tmp

GROUP BY tmp.date, tmp.currency;

ALTER TABLE njiv_rm_daily_totals_currency_dispatch OWNER TO postgres;


-------------------------------------------------
CREATE OR REPLACE VIEW njiv_rm_returns AS 
 
SELECT 
o.date AS date_ts, 
date_trunc('day'::text, o.date) AS date, 
o.id AS order_id, 
o.order_nr, 
o.customer_id, 
cu.is_customer_number, 
c.currency, 
oa.country, 
count(si.variant_id) AS unit_count, 
sum(si.unit_price) AS merchandise_sales_value, 
sum(si.tax) AS tax_value, 
sum(si.duty) AS duties_value, 
sum(si.unit_price + si.tax + si.duty) AS gross_sales_value, 
0 AS shipping_value, 
0 AS gift_credit_redeemed, 
0 AS store_credit_redeemed, 
0 AS total, 
CASE WHEN (3 IN ( SELECT order_flag.flag_id FROM orders, order_flag WHERE o.id = orders.id AND orders.id = order_flag.orders_id)) 
     THEN 'Y'::text
     ELSE 'N'::text
     END AS first_order

FROM 
orders o
LEFT JOIN customer cu ON o.customer_id = cu.id
JOIN link_orders__shipment los ON o.id = los.orders_id
JOIN shipment s ON los.shipment_id = s.id
JOIN shipment_item si ON s.id = si.shipment_id
JOIN currency c ON o.currency_id = c.id
JOIN order_address oa ON o.invoice_address_id = oa.id
JOIN return_item ri ON si.id = ri.shipment_item_id
JOIN order_flag of ON o.id = of.orders_id


WHERE (ri.return_item_status_id = ANY (ARRAY[5, 6, 7])) AND ri.return_type_id = 1 AND of.flag_id = 45 AND o.channel_id = 1

GROUP BY 
o.date, 
date_trunc('day'::text, o.date), 
o.id, 
o.order_nr, 
o.customer_id, 
cu.is_customer_number, 
c.currency, 
oa.country, 
CASE WHEN (3 IN ( SELECT order_flag.flag_id FROM orders, order_flag WHERE o.id = orders.id AND orders.id = order_flag.orders_id)) 
     THEN 'Y'::text
     ELSE 'N'::text
     END;

ALTER TABLE njiv_rm_returns OWNER TO postgres;



-------------------------------------------------
CREATE OR REPLACE VIEW njiv_stock_by_location AS
SELECT lt.type, p.id as product_id, sum(q.quantity) AS quantity

FROM quantity q
JOIN variant v ON q.variant_id = v.id
JOIN product p ON v.product_id = p.id
JOIN location loc ON q.location_id = loc.id
JOIN location_type lt ON loc.type_id = lt.id

WHERE q.channel_id = 1

GROUP BY lt.type, p.id

UNION

SELECT 'GoodsIn' AS type, v.product_id, sum(sp.quantity) AS quantity

FROM
stock_process sp
JOIN delivery_item di ON sp.delivery_item_id = di.id
JOIN link_delivery_item__stock_order_item ldi_soi ON di.id = ldi_soi.delivery_item_id
JOIN stock_order_item soi ON ldi_soi.stock_order_item_id = soi.id
JOIN stock_order so ON so.id = soi.stock_order_id
LEFT JOIN purchase_order po ON so.purchase_order_id = po.id AND po.channel_id = 1
JOIN variant v ON soi.variant_id = v.id

WHERE di.cancel = false AND di.status_id < 4

GROUP BY v.product_id;

ALTER TABLE njiv_stock_by_location OWNER TO postgres;

-------------------------------------------------
CREATE OR REPLACE VIEW njiv_variant_free_stock AS 
SELECT 
saleable.variant_id, 
saleable.legacy_sku, 
saleable.season,
sum(saleable.quantity) AS quantity
FROM 
((((
	SELECT 
	v.id AS variant_id, 
	v.legacy_sku, 
	se.season, 
	sum(q.quantity) AS quantity
        
	FROM 
	quantity q
	JOIN variant v ON q.variant_id = v.id
	JOIN product p on v.product_id = p.id
	JOIN season se on p.season_id = se.id
        
	WHERE 
	NOT (q.location_id IN ( SELECT location.id FROM location WHERE location.type_id <> 1))
	AND q.channel_id = 1 
	
        
	GROUP BY v.id, 
	v.legacy_sku, 
	se.season


UNION ALL 

        SELECT 
	v.id AS variant_id, 
	v.legacy_sku, 
	se.season, 
	- count(*) AS quantity
        
	FROM 
	reservation r
	JOIN variant v ON r.variant_id = v.id AND r.status_id = 2
	JOIN product p on v.product_id = p.id
	JOIN season se on p.season_id = se.id

        WHERE r.channel_id = 1
	
        
	GROUP BY 
	v.id, 
	v.legacy_sku, 
	se.season
	)

UNION ALL 
        
	SELECT 
	v.id AS variant_id, 
	v.legacy_sku, 
	se.season, 
	- count(*) AS quantity
        
	FROM 
	orders o
	JOIN link_orders__shipment los ON o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id
	JOIN shipment_item si ON s.id = si.shipment_id AND si.shipment_item_status_id < 3
	JOIN variant v ON si.variant_id = v.id
	JOIN product p on v.product_id = p.id
	JOIN season se on p.season_id = se.id
        
	WHERE 
	o.channel_id = 1
	
        GROUP BY v.id, v.legacy_sku, se.season
	)

UNION ALL 
         
	SELECT 
	v.id AS variant_id, 
	v.legacy_sku, 
	se.season, 
	- count(*) AS quantity
        
	FROM 

	orders o
	JOIN link_orders__shipment los ON o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id
	JOIN shipment_item si ON s.id = si.shipment_id AND si.shipment_item_status_id = 10
	JOIN cancelled_item ci on si.id = ci.shipment_item_id AND ci.adjusted = 0
	JOIN variant v on si.variant_id = v.id
	JOIN product p on v.product_id = p.id
	JOIN season se on p.season_id = se.id

        WHERE 
	o.channel_id = 1	
        
	GROUP BY v.id, v.legacy_sku, se.season
	) 

UNION ALL 
        
	SELECT 
	v.id AS variant_id, 
	v.legacy_sku, 
	se.season, 
	- count(*) AS quantity
        
	FROM 
	stock_transfer o
	JOIN link_stock_transfer__shipment los ON o.id = los.stock_transfer_id
	JOIN shipment s ON los.shipment_id = s.id
	JOIN shipment_item si ON s.id = si.shipment_id AND si.shipment_item_status_id < 3
	JOIN variant v ON si.variant_id = v.id
	JOIN product p on v.product_id = p.id
	JOIN season se on p.season_id = se.id
        
	WHERE o.channel_id = 1
	
        GROUP BY v.id, v.legacy_sku, se.season
	)
	saleable

GROUP BY saleable.variant_id, saleable.legacy_sku, saleable.season;

ALTER TABLE njiv_variant_free_stock OWNER TO postgres;
-------------------------------------------------

CREATE OR REPLACE VIEW vw_sale_orders AS 
SELECT 
sales.date, 
sales.order_nr, 
sum(sales.item) AS order_items, 
'sale_order'::text AS sale_order

FROM 
	(
	SELECT 
	o.order_nr, 
	o.date, 
	v.product_id, 
	max_date_start.date_start, 1 AS item, 
        CASE WHEN max_date_start.date_start IS NOT NULL
		THEN 1
                ELSE NULL::integer
                END AS sale

        FROM 
	orders o
	JOIN link_orders__shipment los ON o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id
	JOIN shipment_item si ON s.id = si.shipment_id
	JOIN variant v ON si.variant_id = v.id 
	LEFT JOIN 
		(
		SELECT 
		max(pa1.date_start) AS date_start, 
		pa1.product_id
                
		FROM
		price_adjustment pa1
                
		GROUP BY 
		pa1.product_id
		) max_date_start ON v.product_id = max_date_start.product_id

	WHERE
	o.channel_id = 1 AND
	(max_date_start.date_start < o.date::date OR max_date_start.date_start IS NULL)
	) sales

GROUP BY
sales.date,
sales.order_nr

HAVING 
sum(sales.sale) = sum(sales.item);

ALTER TABLE vw_sale_orders OWNER TO postgres;

-------------------------------------------------


/*******************************************************************OUTNET*************************************************************************/



/*CREATE OR REPLACE Used Views*/
-------------------------------------------------
CREATE OR REPLACE VIEW njiv_1st_sold_out_outnet AS
SELECT p.id AS product_id, min(pw.date) AS date
FROM product p
LEFT JOIN variant v ON p.id = v.product_id
LEFT JOIN log_pws_stock pw ON v.id = pw.variant_id
WHERE pw.balance = 0 and pw.channel_id = 3
GROUP BY p.id;

ALTER TABLE njiv_1st_sold_out_outnet OWNER TO postgres;

-------------------------------------------------


CREATE OR REPLACE VIEW njiv_cancellations_outnet AS
SELECT
tmp.date_ts,
tmp.date,
tmp.order_id,
tmp.order_nr,
tmp.customer_id,
tmp.is_customer_number,
tmp.currency,
tmp.country,
sum(tmp.unit_count) AS unit_count,
sum(tmp.merchandise_sales_value) AS merchandise_sales_value,
sum(tmp.tax_value) AS tax_value,
sum(tmp.duties_value) AS duties_value,
sum(tmp.shipping_value) AS shipping_value,
sum(tmp.gift_credit_redeemed) AS gift_credit_redeemed,
sum(tmp.store_credit_redeemed) AS store_credit_redeemed,
sum(tmp.gross_sales_value) + sum(tmp.total) AS total_order_value,
tmp.first_order,
max(tmp.whole_order) AS max

FROM

(

	SELECT o.date AS date_ts,
	date_trunc('day'::text, o.date) AS date,
	o.id AS order_id,
	o.order_nr,
	o.customer_id,
	cu.is_customer_number,
	c.currency,
	oa.country,
	count(si.variant_id) AS unit_count,
	sum(si.unit_price) AS merchandise_sales_value,
	sum(si.tax) AS tax_value,
	sum(si.duty) AS duties_value,
	sum(si.unit_price + si.tax + si.duty) AS gross_sales_value,
	0 AS shipping_value,
	0 AS gift_credit_redeemed,
	0 AS store_credit_redeemed,
	0 AS total,
	CASE WHEN (3 IN ( SELECT order_flag.flag_id FROM orders, order_flag WHERE o.id = orders.id AND orders.id = order_flag.orders_id))
	     THEN 'Y'::text
	     ELSE 'N'::text
     	     END AS first_order,
	'N'::text AS whole_order

	FROM orders o
	LEFT JOIN customer cu ON o.customer_id = cu.id
	JOIN link_orders__shipment los On o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id
	JOIN shipment_item si ON s.id = si.shipment_id AND s.shipment_class_id = 1 AND (si.shipment_item_status_id = ANY (ARRAY[9, 10]))
	JOIN currency c ON o.currency_id = c.id
	JOIN order_address oa ON o.invoice_address_id = oa.id

	WHERE
	si.variant_id <> 49285 AND si.variant_id <> 67158 AND si.variant_id <> 73652
	AND o.channel_id = 3

	GROUP BY
	o.date,
	date_trunc('day'::text, o.date),
	o.id,
	o.order_nr,
	o.customer_id,
	cu.is_customer_number,
	c.currency,
	oa.country,
	CASE WHEN (3 IN ( SELECT order_flag.flag_id FROM orders, order_flag WHERE o.id = orders.id AND orders.id = order_flag.orders_id))
     	     THEN 'Y'::text
     	     ELSE 'N'::text
     	     END

UNION

	SELECT o.date AS date_ts,
	date_trunc('day'::text, o.date) AS date,
	o.id AS order_id,
	o.order_nr,
	o.customer_id,
	cu.is_customer_number,
	c.currency,
	oa.country,
	0 AS unit_count,
	0 AS merchandise_sales_value,
	0 AS tax_value,
	0 AS duties_value,
	0 AS gross_sales_value,
	sum(s.shipping_charge) AS shipping_value,
	sum(s.gift_credit) AS gift_credit_redeemed,
	sum(s.store_credit) AS store_credit_redeemed,
	sum(s.shipping_charge + s.gift_credit + s.store_credit) AS total,
	CASE WHEN (3 IN ( SELECT order_flag.flag_id FROM orders, order_flag WHERE o.id = orders.id AND orders.id = order_flag.orders_id))
     	     THEN 'Y'::text
     	     ELSE 'N'::text
     	     END AS first_order,
	'Y'::text AS whole_order

	FROM orders o
	LEFT JOIN customer cu ON o.customer_id = cu.id
	JOIN link_orders__shipment los ON o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id AND s.shipment_class_id = 1 AND s.shipment_status_id = 5
	JOIN currency c ON o.currency_id = c.id
	JOIN order_address oa ON o.invoice_address_id = oa.id

	WHERE
	o.channel_id = 3

	GROUP BY
	o.date,
	date_trunc('day'::text, o.date),
	o.id,
	o.order_nr,
	o.customer_id,
	cu.is_customer_number,
	c.currency,
	oa.country,
	CASE WHEN (3 IN ( SELECT order_flag.flag_id FROM orders, order_flag WHERE o.id = orders.id AND orders.id = order_flag.orders_id))
     	     THEN 'Y'::text
     	     ELSE 'N'::text
	     END

) tmp


GROUP BY
tmp.date_ts,
tmp.order_nr,
tmp.date,
tmp.order_id,
tmp.customer_id,
tmp.is_customer_number,
tmp.currency,
tmp.country,
tmp.first_order

ORDER BY
tmp.date_ts,
tmp.order_nr;

ALTER TABLE njiv_cancellations_outnet OWNER TO postgres;
-------------------------------------------------


CREATE OR REPLACE VIEW njiv_daily_totals_outnet AS
SELECT

tmp.date,
sum(tmp.order_count) AS order_count,
sum(tmp.merchandise_sales_value) AS merchandise_sales_value,
sum(tmp.tax_value) AS tax_value,
sum(tmp.duties_value) AS duties_value,
sum(tmp.gross_sales_value) AS gross_sales_value,
sum(tmp.shipping_value) AS shipping_value,
sum(tmp.gift_credit_redeemed) AS gift_credit_redeemed,
sum(tmp.store_credit_redeemed) AS store_credit_redeemed,
sum(tmp.total) AS gross_shipping_total,
sum(tmp.new_order_count) AS new_order_count,
sum(tmp.new_merchandise_sales_value) AS new_merchandise_sales_value,
sum(tmp.new_tax_value) AS new_tax_value,
sum(tmp.new_duties_value) AS new_duties_value,
sum(tmp.new_gross_sales_value) AS new_gross_sales_value,
sum(tmp.new_shipping_value) AS new_shipping_value,
sum(tmp.new_gift_credit_redeemed) AS new_gift_credit_redeemed,
sum(tmp.new_store_credit_redeemed) AS new_store_credit_redeemed,
sum(tmp.new_total) AS new_gross_shipping_total

FROM
(((
	SELECT
	date_trunc('day'::text, o.date) AS date,
	count(DISTINCT o.order_nr) AS order_count,
	sum(si.unit_price / scr.from_gbp) AS merchandise_sales_value,
	sum(si.tax / scr.from_gbp) AS tax_value,
	sum(si.duty / scr.from_gbp) AS duties_value,
	sum((si.unit_price + si.tax + si.duty) / scr.from_gbp) AS gross_sales_value,
	0 AS shipping_value,
	0 AS gift_credit_redeemed,
	0 AS store_credit_redeemed,
	0 AS total,
	0 AS new_order_count,
	0 AS new_merchandise_sales_value,
	0 AS new_tax_value,
	0 AS new_duties_value,
	0 AS new_gross_sales_value,
	0 AS new_shipping_value,
	0 AS new_gift_credit_redeemed,
	0 AS new_store_credit_redeemed,
	0 AS new_total

	FROM
	orders o
	JOIN link_orders__shipment los ON o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id AND s.shipment_class_id = 1
	JOIN shipment_item si ON s.id = si.shipment_id
	JOIN nji_lookup_fx_rates scr ON o.currency_id = scr.currency_id AND o.date > scr.valid_from AND (scr.valid_to IS NULL OR o.date < valid_to)

	WHERE
	si.variant_id <> 49285 AND si.variant_id <> 67158 AND si.variant_id <> 73652
   	AND o.channel_id = 3

	GROUP BY
	date_trunc('day'::text, o.date)

UNION
	SELECT date_trunc('day'::text, o.date) AS date,
	0 AS order_count,
	0 AS merchandise_sales_value,
	0 AS tax_value,
	0 AS duties_value,
	0 AS gross_sales_value,
	sum(s.shipping_charge / scr.from_gbp) AS shipping_value,
	sum(s.gift_credit / scr.from_gbp) AS gift_credit_redeemed,
	sum(s.store_credit / scr.from_gbp) AS store_credit_redeemed,
	sum((s.shipping_charge + s.gift_credit + s.store_credit) / scr.from_gbp) AS total,
	0 AS new_order_count,
	0 AS new_merchandise_sales_value,
	0 AS new_tax_value,
	0 AS new_duties_value,
	0 AS new_gross_sales_value,
	0 AS new_shipping_value,
	0 AS new_gift_credit_redeemed,
	0 AS new_store_credit_redeemed,
	0 AS new_total

	FROM
	orders o
	JOIN link_orders__shipment los ON o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id AND s.shipment_class_id = 1
	JOIN nji_lookup_fx_rates scr ON o.currency_id = scr.currency_id AND o.date > scr.valid_from AND (scr.valid_to IS NULL OR o.date < valid_to)

        WHERE
	o.channel_id = 3

	GROUP BY date_trunc('day'::text, o.date)
	)

UNION


	SELECT
	date_trunc('day'::text, o.date) AS date,
	0 AS order_count,
	0 AS merchandise_sales_value,
	0 AS tax_value,
	0 AS duties_value,
	0 AS gross_sales_value,
	0 AS shipping_value,
	0 AS gift_credit_redeemed,
	0 AS store_credit_redeemed,
	0 AS total, count(DISTINCT o.order_nr) AS new_order_count,
	sum(si.unit_price / scr.from_gbp) AS new_merchandise_sales_value,
	sum(si.tax / scr.from_gbp) AS new_tax_value,
	sum(si.duty / scr.from_gbp) AS new_duties_value,
	sum((si.unit_price + si.tax + si.duty) / scr.from_gbp) AS new_gross_sales_value,
	0 AS new_shipping_value,
	0 AS new_gift_credit_redeemed,
	0 AS new_store_credit_redeemed,
	0 AS new_total


	FROM
	orders o
	JOIN link_orders__shipment los ON o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id AND s.shipment_class_id = 1
	JOIN shipment_item si ON s.id = si.shipment_id
	JOIN order_flag of on o.id = of.orders_id AND of.flag_id = 3
	JOIN nji_lookup_fx_rates scr ON o.currency_id = scr.currency_id AND o.date > scr.valid_from AND (scr.valid_to IS NULL OR o.date < valid_to)




	WHERE
	si.variant_id <> 49285 AND si.variant_id <> 67158 AND si.variant_id <> 73652
	AND o.channel_id = 3

        GROUP BY
	date_trunc('day'::text, o.date)
	)

UNION
	SELECT
	date_trunc('day'::text, o.date) AS date,
	0 AS order_count,
	0 AS merchandise_sales_value,
	0 AS tax_value,
	0 AS duties_value,
	0 AS gross_sales_value,
	0 AS shipping_value,
	0 AS gift_credit_redeemed,
	0 AS store_credit_redeemed,
	0 AS total,
	0 AS new_order_count,
	0 AS new_merchandise_sales_value,
	0 AS new_tax_value,
	0 AS new_duties_value,
	0 AS new_gross_sales_value,
	sum(s.shipping_charge / scr.from_gbp) AS new_shipping_value,
	sum(s.gift_credit / scr.from_gbp) AS new_gift_credit_redeemed,
	sum(s.store_credit / scr.from_gbp) AS new_store_credit_redeemed,
	sum((s.shipping_charge + s.gift_credit + s.store_credit) / scr.from_gbp) AS new_total

	FROM
	orders o
	JOIN link_orders__shipment los ON o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id AND s.shipment_class_id = 1
	JOIN order_flag of on o.id = of.orders_id AND of.flag_id = 3
	JOIN nji_lookup_fx_rates scr ON o.currency_id = scr.currency_id AND o.date > scr.valid_from AND (scr.valid_to IS NULL OR o.date < valid_to)


	WHERE
	o.channel_id = 3

	GROUP BY
	date_trunc('day'::text, o.date)
	) tmp

GROUP BY tmp.date;
ALTER TABLE njiv_daily_totals_outnet OWNER TO postgres;
-------------------------------------------------

CREATE OR REPLACE VIEW njiv_daily_totals_2_outnet AS
SELECT

tmp.date,
sum(tmp.order_count) AS order_count,
sum(tmp.units) AS units,
sum(tmp.merchandise_sales_value) AS merchandise_sales_value,
sum(tmp.tax_value) AS tax_value,
sum(tmp.duties_value) AS duties_value,
sum(tmp.gross_sales_value) AS gross_sales_value,
sum(tmp.shipping_value) AS shipping_value,
sum(tmp.gift_credit_redeemed) AS gift_credit_redeemed,
sum(tmp.store_credit_redeemed) AS store_credit_redeemed,
sum(tmp.total) AS gross_shipping_total,
sum(tmp.new_order_count) AS new_order_count,
sum(tmp.new_units) AS new_units,
sum(tmp.new_merchandise_sales_value) AS new_merchandise_sales_value,
sum(tmp.new_tax_value) AS new_tax_value,
sum(tmp.new_duties_value) AS new_duties_value,
sum(tmp.new_gross_sales_value) AS new_gross_sales_value,
sum(tmp.new_shipping_value) AS new_shipping_value,
sum(tmp.new_gift_credit_redeemed) AS new_gift_credit_redeemed,
sum(tmp.new_store_credit_redeemed) AS new_store_credit_redeemed,
sum(tmp.new_total) AS new_gross_shipping_total

FROM
(((

	SELECT
	date_trunc('day'::text, o.date) AS date,
	count(DISTINCT o.order_nr) AS order_count,
	count(si.id) AS units,
	sum(si.unit_price / scr.from_gbp) AS merchandise_sales_value,
	sum(si.tax / scr.from_gbp) AS tax_value,
	sum(si.duty / scr.from_gbp) AS duties_value,
	sum((si.unit_price + si.tax + si.duty) / scr.from_gbp) AS gross_sales_value,
	0 AS shipping_value,
	0 AS gift_credit_redeemed,
	0 AS store_credit_redeemed,
	0 AS total,
	0 AS new_order_count,
	0 AS new_units,
	0 AS new_merchandise_sales_value,
	0 AS new_tax_value,
	0 AS new_duties_value,
	0 AS new_gross_sales_value,
	0 AS new_shipping_value,
	0 AS new_gift_credit_redeemed,
	0 AS new_store_credit_redeemed,
	0 AS new_total

	FROM
	orders o
	JOIN link_orders__shipment los ON o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id AND s.shipment_class_id = 1
	JOIN shipment_item si ON s.id = si.shipment_id
	JOIN nji_lookup_fx_rates scr ON o.currency_id = scr.currency_id AND o.date > scr.valid_from AND (scr.valid_to IS NULL OR o.date < valid_to)

	WHERE
	si.variant_id <> 49285 AND si.variant_id <> 67158 AND si.variant_id <> 73652
   	AND o.channel_id = 3

	GROUP BY
	date_trunc('day'::text, o.date)


UNION
	SELECT date_trunc('day'::text, o.date) AS date,
	0 AS order_count,
	0 AS units,
	0 AS merchandise_sales_value,
	0 AS tax_value,
	0 AS duties_value,
	0 AS gross_sales_value,
	sum(s.shipping_charge / scr.from_gbp) AS shipping_value,
	sum(s.gift_credit / scr.from_gbp) AS gift_credit_redeemed,
	sum(s.store_credit / scr.from_gbp) AS store_credit_redeemed,
	sum((s.shipping_charge + s.gift_credit + s.store_credit) / scr.from_gbp) AS total,
	0 AS new_order_count,
	0 AS new_units,
	0 AS new_merchandise_sales_value,
	0 AS new_tax_value,
	0 AS new_duties_value,
	0 AS new_gross_sales_value,
	0 AS new_shipping_value,
	0 AS new_gift_credit_redeemed,
	0 AS new_store_credit_redeemed,
	0 AS new_total

	FROM
	orders o
	JOIN link_orders__shipment los ON o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id AND s.shipment_class_id = 1
	JOIN nji_lookup_fx_rates scr ON o.currency_id = scr.currency_id AND o.date > scr.valid_from AND (scr.valid_to IS NULL OR o.date < valid_to)

        WHERE
	o.channel_id = 3

	GROUP BY date_trunc('day'::text, o.date)
	)


UNION

	SELECT
	date_trunc('day'::text, o.date) AS date,
	0 AS order_count,
	0 as units,
	0 AS merchandise_sales_value,
	0 AS tax_value,
	0 AS duties_value,
	0 AS gross_sales_value,
	0 AS shipping_value,
	0 AS gift_credit_redeemed,
	0 AS store_credit_redeemed,
	0 AS total,
	count(DISTINCT o.order_nr) AS new_order_count,
	count(si.id) AS new_units,
	sum(si.unit_price / scr.from_gbp) AS new_merchandise_sales_value,
	sum(si.tax / scr.from_gbp) AS new_tax_value,
	sum(si.duty / scr.from_gbp) AS new_duties_value,
	sum((si.unit_price + si.tax + si.duty) / scr.from_gbp) AS new_gross_sales_value,
	0 AS new_shipping_value,
	0 AS new_gift_credit_redeemed,
	0 AS new_store_credit_redeemed,
	0 AS new_total


	FROM
	orders o
	JOIN link_orders__shipment los ON o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id AND s.shipment_class_id = 1
	JOIN shipment_item si ON s.id = si.shipment_id
	JOIN order_flag of on o.id = of.orders_id AND of.flag_id = 3
	JOIN nji_lookup_fx_rates scr ON o.currency_id = scr.currency_id AND o.date > scr.valid_from AND (scr.valid_to IS NULL OR o.date < valid_to)


	WHERE
	si.variant_id <> 49285 AND si.variant_id <> 67158 AND si.variant_id <> 73652
	AND o.channel_id = 3

        GROUP BY
	date_trunc('day'::text, o.date)
	)


UNION
	SELECT
	date_trunc('day'::text, o.date) AS date,
	0 AS order_count,
	0 as units,
	0 AS merchandise_sales_value,
	0 AS tax_value,
	0 AS duties_value,
	0 AS gross_sales_value,
	0 AS shipping_value,
	0 AS gift_credit_redeemed,
	0 AS store_credit_redeemed,
	0 AS total,
	0 AS new_order_count,
	0 as new_units,
	0 AS new_merchandise_sales_value,
	0 AS new_tax_value,
	0 AS new_duties_value,
	0 AS new_gross_sales_value,
	sum(s.shipping_charge / scr.from_gbp) AS new_shipping_value,
	sum(s.gift_credit / scr.from_gbp) AS new_gift_credit_redeemed,
	sum(s.store_credit / scr.from_gbp) AS new_store_credit_redeemed,
	sum((s.shipping_charge + s.gift_credit + s.store_credit) / scr.from_gbp) AS new_total

	FROM
	orders o
	JOIN link_orders__shipment los ON o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id AND s.shipment_class_id = 1
	JOIN order_flag of on o.id = of.orders_id AND of.flag_id = 3
	JOIN nji_lookup_fx_rates scr ON o.currency_id = scr.currency_id AND o.date > scr.valid_from AND (scr.valid_to IS NULL OR o.date < valid_to)


	WHERE
	o.channel_id = 3

	GROUP BY
	date_trunc('day'::text, o.date)
	) tmp

  GROUP BY tmp.date;
ALTER TABLE njiv_daily_totals_2_outnet OWNER TO postgres;
---------------------------------------------------

CREATE OR REPLACE VIEW njiv_daily_totals_currency_2_outnet AS
SELECT
tmp.date,
tmp.currency,
sum(tmp.order_count) AS order_count,
sum(tmp.units) AS units,
sum(tmp.merchandise_sales_value) AS merchandise_sales_value,
sum(tmp.tax_value) AS tax_value,
sum(tmp.duties_value) AS duties_value,
sum(tmp.gross_sales_value) AS gross_sales_value,
sum(tmp.shipping_value) AS shipping_value,
sum(tmp.gift_credit_redeemed) AS gift_credit_redeemed,
sum(tmp.store_credit_redeemed) AS store_credit_redeemed,
sum(tmp.total) AS gross_shipping_total,
sum(tmp.new_order_count) AS new_order_count,
sum(tmp.new_units) AS new_units,
sum(tmp.new_merchandise_sales_value) AS new_merchandise_sales_value,
sum(tmp.new_tax_value) AS new_tax_value,
sum(tmp.new_duties_value) AS new_duties_value,
sum(tmp.new_gross_sales_value) AS new_gross_sales_value,
sum(tmp.new_shipping_value) AS new_shipping_value,
sum(tmp.new_gift_credit_redeemed) AS new_gift_credit_redeemed,
sum(tmp.new_store_credit_redeemed) AS new_store_credit_redeemed,
sum(tmp.new_total) AS new_gross_shipping_total

FROM
(((

	SELECT
	date_trunc('day'::text, o.date) AS date,
	c.currency,
	count(DISTINCT o.order_nr) AS order_count,
	count(si.id) AS units,
	sum(si.unit_price) AS merchandise_sales_value,
	sum(si.tax) AS tax_value,
	sum(si.duty) AS duties_value,
	sum(si.unit_price + si.tax + si.duty) AS gross_sales_value,
	0 AS shipping_value,
	0 AS gift_credit_redeemed,
	0 AS store_credit_redeemed,
	0 AS total,
	0 AS new_order_count,
	0 AS new_units,
	0 AS new_merchandise_sales_value,
	0 AS new_tax_value,
	0 AS new_duties_value,
	0 AS new_gross_sales_value,
	0 AS new_shipping_value,
	0 AS new_gift_credit_redeemed,
	0 AS new_store_credit_redeemed,
	0 AS new_total

	FROM
	orders o
	JOIN link_orders__shipment los ON o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id AND s.shipment_class_id = 1
	JOIN shipment_item si ON s.id = si.shipment_id
	JOIN currency c ON o.currency_id = c.id

	WHERE
	si.variant_id <> 49285 AND si.variant_id <> 67158 AND si.variant_id <> 73652
   	AND o.channel_id = 3

	GROUP BY
	date_trunc('day'::text, o.date), c.currency

UNION
	SELECT date_trunc('day'::text, o.date) AS date,
	c.currency,
	0 AS order_count,
	0 AS units,
	0 AS merchandise_sales_value,
	0 AS tax_value,
	0 AS duties_value,
	0 AS gross_sales_value,
	sum(s.shipping_charge) AS shipping_value,
	sum(s.gift_credit) AS gift_credit_redeemed,
	sum(s.store_credit) AS store_credit_redeemed,
	sum(s.shipping_charge + s.gift_credit + s.store_credit) AS total,
	0 AS new_order_count,
	0 AS new_units,
	0 AS new_merchandise_sales_value,
	0 AS new_tax_value,
	0 AS new_duties_value,
	0 AS new_gross_sales_value,
	0 AS new_shipping_value,
	0 AS new_gift_credit_redeemed,
	0 AS new_store_credit_redeemed,
	0 AS new_total

	FROM
	orders o
	JOIN link_orders__shipment los ON o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id AND s.shipment_class_id = 1
	JOIN currency c ON o.currency_id = c.id

        WHERE
	o.channel_id = 3

	GROUP BY date_trunc('day'::text, o.date),c.currency
	)

UNION
	SELECT
	date_trunc('day'::text, o.date) AS date,
	c.currency,
	0 AS order_count,
	0 as units,
	0 AS merchandise_sales_value,
	0 AS tax_value,
	0 AS duties_value,
	0 AS gross_sales_value,
	0 AS shipping_value,
	0 AS gift_credit_redeemed,
	0 AS store_credit_redeemed,
	0 AS total,
	count(DISTINCT o.order_nr) AS new_order_count,
	count(si.id) AS new_units,
	sum(si.unit_price) AS new_merchandise_sales_value,
	sum(si.tax) AS new_tax_value,
	sum(si.duty) AS new_duties_value,
	sum(si.unit_price + si.tax + si.duty) AS new_gross_sales_value,
	0 AS new_shipping_value,
	0 AS new_gift_credit_redeemed,
	0 AS new_store_credit_redeemed,
	0 AS new_total


	FROM
	orders o
	JOIN link_orders__shipment los ON o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id AND s.shipment_class_id = 1
	JOIN shipment_item si ON s.id = si.shipment_id
	JOIN order_flag of on o.id = of.orders_id AND of.flag_id = 3
	JOIN currency c ON o.currency_id = c.id


	WHERE
	si.variant_id <> 49285 AND si.variant_id <> 67158 AND si.variant_id <> 73652
	AND o.channel_id = 3

        GROUP BY
	date_trunc('day'::text, o.date), c.currency
	)

UNION
	SELECT
	date_trunc('day'::text, o.date) AS date,
	c.currency,
	0 AS order_count,
	0 as units,
	0 AS merchandise_sales_value,
	0 AS tax_value,
	0 AS duties_value,
	0 AS gross_sales_value,
	0 AS shipping_value,
	0 AS gift_credit_redeemed,
	0 AS store_credit_redeemed,
	0 AS total,
	0 AS new_order_count,
	0 as new_units,
	0 AS new_merchandise_sales_value,
	0 AS new_tax_value,
	0 AS new_duties_value,
	0 AS new_gross_sales_value,
	sum(s.shipping_charge) AS new_shipping_value,
	sum(s.gift_credit) AS new_gift_credit_redeemed,
	sum(s.store_credit) AS new_store_credit_redeemed,
	sum(s.shipping_charge + s.gift_credit + s.store_credit) AS new_total

	FROM
	orders o
	JOIN link_orders__shipment los ON o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id AND s.shipment_class_id = 1
	JOIN order_flag of on o.id = of.orders_id AND of.flag_id = 3
	JOIN currency c ON o.currency_id = c.id


	WHERE
	o.channel_id = 3

	GROUP BY
	date_trunc('day'::text, o.date), c.currency
	) tmp

  GROUP BY tmp.date, tmp.currency;
ALTER TABLE njiv_daily_totals_currency_2_outnet OWNER TO postgres;
-----------------------------------------------------------

CREATE OR REPLACE VIEW njiv_daily_ukl_outnet AS 
SELECT date_trunc('day'::text, o.date) AS date_trunc, count(DISTINCT o.order_nr) AS count, sum(pp.uk_landed_cost) AS total_ukl

FROM 
orders o 
JOIN link_orders__shipment los ON o.id = los.orders_id
JOIN shipment s on los.shipment_id = s.id AND s.shipment_class_id = 1
JOIN shipment_item si ON s.id = si.shipment_id
JOIN variant v ON si.variant_id = v.id
JOIN product p ON v.product_id = p.id
JOIN price_purchase pp ON p.id = pp.product_id

WHERE
si.variant_id <> 49285 AND si.variant_id <> 67158 AND si.variant_id <> 73652
AND o.channel_id = 3


GROUP BY date_trunc('day'::text, o.date);
ALTER TABLE njiv_daily_ukl_outnet OWNER TO postgres;


------------------------------------------------------------
CREATE OR REPLACE VIEW njiv_ftbc_gross_orders_outnet AS 
SELECT 
ftbc1.date, 
count(ftbc1.order_id) AS order_count, 
ftbc1.currency, 
sum(ftbc1.first_order) AS first_orders, 
sum(ftbc1.ftbc_unit_count) AS ftbc_units, 
sum(ftbc1.units) AS total_units


FROM ( 
	SELECT date_trunc('day'::text, o.date) AS date, o.id AS order_id, o.order_nr, c.currency, 
	sum(CASE WHEN p.season_id = 39 THEN 1 ELSE 0 END) AS ftbc_unit_count, 
        CASE WHEN (3 IN ( SELECT order_flag.flag_id FROM orders, order_flag WHERE o.id = orders.id AND orders.id = order_flag.orders_id)) 
		THEN 1
                ELSE 0
                END AS first_order, 
	count(si.id) AS units, 
	sum(si.unit_price) AS merchandise_sales_value, 
	sum(si.tax) AS tax_value, 
	sum(si.duty) AS duties_value, 
	sum(si.unit_price + si.tax + si.duty) AS gross_sales_value
        
	FROM orders o
      	JOIN link_orders__shipment los ON o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id AND s.shipment_class_id = 1
	JOIN shipment_item si ON s.id = si.shipment_id
	JOIN currency c ON o.currency_id = c.id
	JOIN variant v ON si.variant_id = v.id
	JOIN product p ON v.product_id = p.id

	WHERE 
	o.channel_id = 3
  
	GROUP BY 
	date_trunc('day'::text, o.date), 
	o.id, 
	o.order_nr, 
	c.currency, 
	CASE WHEN (3 IN ( SELECT order_flag.flag_id FROM orders, order_flag WHERE o.id = orders.id AND orders.id = order_flag.orders_id)) 
	     THEN 1
	     ELSE 0
	END) ftbc1
  
WHERE 
ftbc1.ftbc_unit_count = ftbc1.units

GROUP BY 
ftbc1.date, ftbc1.currency

ORDER BY 
ftbc1.date, ftbc1.currency;

ALTER TABLE njiv_ftbc_gross_orders_outnet OWNER TO postgres;
----------------------------------------------------

CREATE OR REPLACE VIEW njiv_ftbc_gross_sales_outnet AS
SELECT
date_trunc('day'::text, o.date) AS date,
c.currency,
count(DISTINCT o.order_nr) AS containsftbc_order_count,
count(si.id) AS ftbc_units,
sum(si.unit_price) AS ftbc_merchandise_sales_value,
sum(si.tax) AS ftbc_tax_value,
sum(si.duty) AS ftbc_duties_value,
sum(si.unit_price + si.tax + si.duty) AS ftbc_gross_sales_value,
sum(pp.uk_landed_cost) AS ftbc_ukl

FROM orders o
JOIN link_orders__shipment los ON o.id = los.orders_id
JOIN shipment s ON los.shipment_id = s.id AND s.shipment_class_id = 1
JOIN shipment_item si ON s.id = si.shipment_id
JOIN currency c ON o.currency_id = c.id
JOIN variant v ON si.variant_id = v.id
JOIN product p ON v.product_id = p.id AND p.season_id = 39
JOIN price_purchase pp ON p.id = pp.product_id

WHERE
o.channel_id = 3

GROUP BY date_trunc('day'::text, o.date), c.currency;
ALTER TABLE njiv_ftbc_gross_sales_outnet OWNER TO postgres;

----------------------------------------------------

CREATE OR REPLACE VIEW njiv_ftbc_merch_cancellations_outnet AS
SELECT 
o.date AS date_ts, 
date_trunc('day'::text, o.date) AS date, 
o.id AS order_id, 
o.order_nr, 
o.customer_id, 
cu.is_customer_number, 
c.currency, 
count(si.variant_id) AS unit_count, 
sum(si.unit_price) AS merchandise_sales_value, 
sum(si.tax) AS tax_value, 
sum(si.duty) AS duties_value, 
sum(si.unit_price + si.tax + si.duty) AS gross_sales_value

FROM orders o
LEFT JOIN customer cu ON o.customer_id = cu.id
JOIN link_orders__shipment los ON o.id = los.orders_id
JOIN shipment s ON los.shipment_id = s.id AND s.shipment_class_id = 1
JOIN shipment_item si ON s.id = si.shipment_id AND (si.shipment_item_status_id = ANY (ARRAY[9, 10]))
JOIN currency c ON o.currency_id = c.id
JOIN variant v ON si.variant_id = v.id
JOIN product p ON v.product_id = p.id AND p.season_id = 39

WHERE 
o.channel_id = 3

GROUP BY o.date, date_trunc('day'::text, o.date), o.id, o.order_nr, o.customer_id, cu.is_customer_number, c.currency;

ALTER TABLE njiv_ftbc_merch_cancellations_outnet OWNER TO postgres;

-----------------------------------------------------

CREATE OR REPLACE VIEW njiv_ftbc_merch_returns_outnet AS 
SELECT 
o.date AS date_ts, 
date_trunc('day'::text, o.date) AS date, 
o.id AS order_id, 
o.order_nr, 
o.customer_id, 
cu.is_customer_number, 
c.currency, 
count(si.variant_id) AS unit_count, 
sum(si.unit_price) AS merchandise_sales_value, 
sum(si.tax) AS tax_value, sum(si.duty) AS duties_value, 
sum(si.unit_price + si.tax + si.duty) AS gross_sales_value

FROM orders o
LEFT JOIN customer cu ON o.customer_id = cu.id
JOIN link_orders__shipment los ON o.id = los.orders_id
JOIN shipment s ON los.shipment_id = s.id
JOIN shipment_item si ON s.id = si.shipment_id
JOIN currency c ON o.currency_id = c.id
JOIN return_item ri ON si.id = ri.shipment_item_id AND ri.return_type_id = 1
JOIN variant v ON si.variant_id = v.id
JOIN product p ON v.product_id = p.id AND p.season_id = 39

WHERE 
(ri.return_item_status_id = ANY (ARRAY[5, 6, 7])) AND 
o.channel_id = 3 

GROUP BY o.date, date_trunc('day'::text, o.date), o.id, o.order_nr, o.customer_id, cu.is_customer_number, c.currency;

ALTER TABLE njiv_ftbc_merch_returns_outnet OWNER TO postgres;
-------------------------------------------------

CREATE OR REPLACE VIEW njiv_gross_order_totals_currency_outnet AS
SELECT 
tmp.date_ts, 
tmp.date, 
tmp.order_id, 
tmp.order_nr, 
tmp.currency, 
sum(tmp.unit_count) AS unit_count, 
sum(tmp.merchandise_sales_value) AS merchandise_sales_value, 
sum(tmp.tax_value) AS tax_value, 
sum(tmp.duties_value) AS duties_value, 
sum(tmp.shipping_value) AS shipping_value, 
sum(tmp.gift_credit_redeemed) AS gift_credit_redeemed, 
sum(tmp.store_credit_redeemed) AS store_credit_redeemed, 
sum(tmp.gross_sales_value) + sum(tmp.total) AS total_order_value, 
tmp.first_order

FROM ( 
	SELECT 
	o.date AS date_ts, 
	date_trunc('day'::text, o.date) AS date, 
	o.id AS order_id, 
	o.order_nr, 
	c.currency, 
	count(si.variant_id) AS unit_count, 
	sum(si.unit_price) AS merchandise_sales_value, 
	sum(si.tax) AS tax_value, 
	sum(si.duty) AS duties_value, 
	sum(si.unit_price + si.tax + si.duty) AS gross_sales_value, 
	0 AS shipping_value, 
	0 AS gift_credit_redeemed, 0 AS store_credit_redeemed, 0 AS total, 
        CASE WHEN (3 IN ( SELECT order_flag.flag_id FROM orders, order_flag WHERE o.id = orders.id AND orders.id = order_flag.orders_id)) 
	     THEN 'Y'::text
             ELSE 'N'::text
             END AS first_order
        
	FROM 
	orders o 
	JOIN link_orders__shipment los ON o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id AND s.shipment_class_id = 1
	JOIN shipment_item si ON s.id = si.shipment_id 
	JOIN currency c ON o.currency_id = c.id
        
	WHERE si.variant_id <> 49285 AND si.variant_id <> 67158 AND si.variant_id <> 73652 and 
	o.channel_id = 3
        
	GROUP BY 
	o.date, 
	date_trunc('day'::text, o.date), 
	o.id, 
	o.order_nr, 
	c.currency, 
        CASE WHEN (3 IN ( SELECT order_flag.flag_id FROM orders, order_flag WHERE o.id = orders.id AND orders.id = order_flag.orders_id)) 
	     THEN 'Y'::text
             ELSE 'N'::text
             END

UNION 
        SELECT 
	o.date AS date_ts, 
	date_trunc('day'::text, o.date) AS date, 
	o.id AS order_id, 
	o.order_nr, 
	c.currency, 
	0 AS unit_count, 
	0 AS merchandise_sales_value, 
	0 AS tax_value, 
	0 AS duties_value, 
	0 AS gross_sales_value, 
	sum(s.shipping_charge) AS shipping_value, 
	sum(s.gift_credit) AS gift_credit_redeemed, 
	sum(s.store_credit) AS store_credit_redeemed, 
	sum(s.shipping_charge + s.gift_credit + s.store_credit) AS total, 
        CASE WHEN (3 IN ( SELECT order_flag.flag_id FROM orders, order_flag WHERE o.id = orders.id AND orders.id = order_flag.orders_id)) 
	     THEN 'Y'::text
             ELSE 'N'::text
             END AS first_order
        

	FROM
	orders o 
	JOIN link_orders__shipment los ON o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id AND s.shipment_class_id = 1
	JOIN currency c ON o.currency_id = c.id

	WHERE 
	o.channel_id = 3
        
	GROUP BY 
	o.date, 
	date_trunc('day'::text, o.date), 
	o.id, 
	o.order_nr, 
	c.currency, 
        CASE WHEN (3 IN ( SELECT order_flag.flag_id FROM orders, order_flag WHERE o.id = orders.id AND orders.id = order_flag.orders_id)) 
	     THEN 'Y'::text
             ELSE 'N'::text
             END
	) tmp

GROUP BY tmp.date_ts, tmp.order_nr, tmp.date, tmp.order_id, tmp.currency, tmp.first_order
ORDER BY tmp.date_ts, tmp.order_nr;

ALTER TABLE njiv_gross_order_totals_currency_outnet OWNER TO postgres;

-------------------------------------------------

CREATE OR REPLACE VIEW njiv_master_free_stock_outnet AS
SELECT saleable.product_id, saleable.legacy_sku, sum(saleable.quantity) AS quantity
   FROM ((((


	SELECT
	p.id as product_id,
	p.legacy_sku,
	sum(q.quantity) AS quantity

	FROM
	quantity q
	JOIN variant v ON q.variant_id = v.id
	JOIN product p ON v.product_id = p.id

	WHERE
	NOT q.location_id IN (SELECT location.id FROM location location WHERE location.type_id <> 1)
	AND q.channel_id = 3

	GROUP BY
	p.id, p.legacy_sku

UNION ALL

        SELECT
	p.id as product_id,
	p.legacy_sku,
	- count(*) AS quantity

        FROM
	reservation r
	JOIN variant v ON r.variant_id = v.id and r.status_id = 2
	JOIN product p ON v.product_id = p.id

        WHERE r.channel_id = 3

	GROUP BY p.id, p.legacy_sku
	)

UNION ALL

        SELECT
	p.id as product_id,
	p.legacy_sku,
	- count(*) AS quantity

	FROM
	orders o
	JOIN link_orders__shipment los ON o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id
	JOIN shipment_item si ON s.id = si.shipment_id AND si.shipment_item_status_id < 3
        join variant v on si.variant_id = v.id
        join product p on v.product_id = p.id

	WHERE o.channel_id = 3
        GROUP BY p.id, p.legacy_sku
	)

UNION ALL

	SELECT
	p.id as product_id,
	p.legacy_sku,
	- count(*) AS quantity

	FROM
	orders o
	JOIN link_orders__shipment los ON o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id
	JOIN shipment_item si ON s.id = si.shipment_id AND si.shipment_item_status_id = 10
	JOIN cancelled_item ci on si.id = ci.shipment_item_id AND ci.adjusted = 0
	JOIN variant v on si.variant_id = v.id
	JOIN product p on v.product_id = p.id

	WHERE  o.channel_id = 3

	GROUP BY p.id, p.legacy_sku
	) 

UNION ALL
	SELECT
	p.id as product_id,
	p.legacy_sku,
	- count(*) AS quantity

	FROM
	stock_transfer o
	JOIN link_stock_transfer__shipment los ON o.id = los.stock_transfer_id
	JOIN shipment s ON los.shipment_id = s.id
	JOIN shipment_item si ON s.id = si.shipment_id AND si.shipment_item_status_id < 3
        join variant v on si.variant_id = v.id
        join product p on v.product_id = p.id

	WHERE o.channel_id = 3
        GROUP BY p.id, p.legacy_sku
        ) saleable

GROUP BY saleable.product_id, saleable.legacy_sku;

ALTER TABLE njiv_master_free_stock_outnet OWNER TO postgres;


-------------------------------------------------
CREATE OR REPLACE VIEW njiv_master_product_attributes_outnet AS
SELECT
p.id AS product_id,
s.season,
d.designer,
dep.department,
c.classification,
pt.product_type,
st.sub_type,
pa.name,
pdc.visible,
pdc.live,
p.style_number,
p.legacy_sku,
pa.description,
col.colour,
p.hs_code_id,
cf.colour_filter AS mastercolor,
pdc.upload_date,
sum(po.ordered) AS ordered_quantity,
pp.uk_landed_cost,
round(pd.price * scr.conversion_rate, 3) AS original_selling_price,
CASE WHEN md.id is not null
	THEN round(pd.price * scr.conversion_rate * ((100::numeric - md.percentage) / 100::numeric), 3)
	ELSE round(pd.price * scr.conversion_rate, 3)
    	END AS selling_price,
pac.category AS markdown_category,
md.percentage,
CASE WHEN nap.onnap = 'NAP' THEN 'N' ELSE 'Y' END as outnet_only

FROM product p
LEFT JOIN price_default pd ON pd.product_id = p.id
LEFT JOIN price_adjustment md ON (md.product_id = p.id AND md.date_start <= now()::date AND md.date_finish > now()::date )
LEFT JOIN price_adjustment_category pac ON md.category_id = pac.id
LEFT JOIN sub_type st ON p.sub_type_id = st.id
LEFT JOIN hs_code hs ON p.hs_code_id = hs.id
LEFT JOIN product_type pt ON p.product_type_id = pt.id
LEFT JOIN classification c ON p.classification_id = c.id
LEFT JOIN designer d ON p.designer_id = d.id
LEFT JOIN colour col ON p.colour_id = col.id
LEFT JOIN filter_colour_mapping fcm ON p.colour_id = fcm.colour_id
LEFT JOIN legacy_attributes la ON p.id = la.product_id
LEFT JOIN (select product_id, ordered from product.stock_summary where channel_id = 3) po on p.id = po.product_id
JOIN season s ON p.season_id = s.id
JOIN product_attribute pa ON p.id = pa.product_id
JOIN product_department dep ON pa.product_department_id = dep.id
JOIN price_purchase pp ON p.id = pp.product_id
JOIN sales_conversion_rate scr ON pd.currency_id = scr.source_currency
JOIN colour_filter cf ON fcm.filter_colour_id = cf.id
LEFT JOIN product_channel pdc on p.id = pdc.product_id
LEFT JOIN (select product_id,'NAP'::text as onNAP from product_channel where channel_id = 1) nap on p.id = nap.product_id


WHERE scr.destination_currency = 1
AND 'now'::text::date > scr.date_start
AND (scr.date_finish IS NULL OR 'now'::text::date < scr.date_finish)
AND pdc.channel_id = 3

GROUP BY p.id,
s.season,
d.designer,
dep.department, c.classification, pt.product_type, st.sub_type, pa.name, pdc.visible, pdc.live, p.style_number, p.legacy_sku, pa.description, col.colour, 

p.hs_code_id, cf.colour_filter, pdc.upload_date, pp.uk_landed_cost, round(pd.price * scr.conversion_rate, 3),

CASE WHEN md.id is not null THEN round(pd.price * scr.conversion_rate * ((100::numeric - md.percentage) / 100::numeric), 3)
ELSE round(pd.price * scr.conversion_rate, 3)
END,
pac.category,
md.percentage,
CASE WHEN nap.onnap = 'NAP' THEN 'N'::text ELSE 'Y'::text END;

ALTER TABLE njiv_master_product_attributes_outnet OWNER TO postgres;
-------------------------------------------------

CREATE OR REPLACE VIEW njiv_merch_sales_season_outnet AS
SELECT 
date_trunc('day'::text, o.date) AS date, 
c.currency, 
se.season, 
count(si.id) AS units, 
sum(si.unit_price) AS merchandise_sales_value, 
sum(si.tax) AS tax_value, 
sum(si.duty) AS duties_value, 
sum(si.unit_price + si.tax + si.duty) AS gross_sales_value

FROM 
orders o 
JOIN link_orders__shipment los ON o.id = los.orders_id
JOIN shipment s ON los.shipment_id = s.id AND s.shipment_class_id = 1
JOIN shipment_item si ON s.id = si.shipment_id 
JOIN variant v on si.variant_id = v.id
JOIN product p on v.product_id = p.id
JOIN season se on p.season_id = se.id
JOIN currency c ON o.currency_id = c.id


WHERE 
si.variant_id <> 49285 AND si.variant_id <> 67158 AND si.variant_id <> 73652 AND 
o.channel_id = 3

GROUP BY date_trunc('day'::text, o.date), c.currency, se.season;
ALTER TABLE njiv_merch_sales_season_outnet OWNER TO postgres;

-------------------------------------------------

CREATE OR REPLACE VIEW njiv_net_sales_outnet AS

(
SELECT 
date_trunc('day'::text, o.date) AS date, 
'Order' AS action, 
c.id AS customer_id,
c.is_customer_number, 
o.id AS orders_id, 
o.order_nr, 
o.currency_id, 
oa2.country AS shipping_country, 
oa.country AS billing_country, 
v.product_id, 
CASE WHEN md.id IS NOT NULL 
     THEN round(pd.price * scr.conversion_rate * ((100::numeric - md.percentage) / 100::numeric), 3)
     ELSE round(pd.price * scr.conversion_rate, 3)
     END AS selling_price, 
1 AS order_units, 
si.unit_price AS order_merch_value, 
pp.uk_landed_cost AS order_cost_value, 
0 AS cancel_units, 
0 AS cancel_merch_value, 
0 AS cancel_cost_value, 
0 AS return_units, 
0 AS return_merch_value, 
0 AS return_cost_value, 
1 AS net_units, 
si.unit_price AS net_merch_value, 
pp.uk_landed_cost AS net_cost_value


FROM orders o
   JOIN link_orders__shipment los ON o.id = los.orders_id
   JOIN shipment s ON los.shipment_id = s.id AND s.shipment_class_id = 1
   JOIN shipment_item si ON s.id = si.shipment_id
   JOIN variant v ON si.variant_id = v.id
   JOIN product p ON v.product_id = p.id
   JOIN customer c on c.id = o.customer_id
   JOIN order_address oa on o.invoice_address_id = oa.id
   JOIN order_address oa2 on s.shipment_address_id = oa2.id
   LEFT JOIN price_default pd ON pd.product_id = p.id
   LEFT JOIN price_adjustment md ON md.product_id = p.id AND md.date_start <= now()::date AND md.date_finish > now()::date
   JOIN sales_conversion_rate scr ON pd.currency_id = scr.source_currency
   JOIN price_purchase pp ON p.id = pp.product_id


WHERE 
scr.destination_currency = 1 AND 'now'::text::date > scr.date_start AND (scr.date_finish IS NULL OR 'now'::text::date < scr.date_finish)
AND o.channel_id = 3

UNION ALL

SELECT 
date_trunc('day'::text, sisl.date) AS date, 
'cancel' AS action, 
c.id AS customer_id, 
c.is_customer_number, 
o.id AS orders_id, 
o.order_nr, 
o.currency_id, 
oa2.country AS shipping_country, 
oa.country AS billing_country, 
v.product_id, 
CASE WHEN md.id IS NOT NULL 
     THEN round(pd.price * scr.conversion_rate * ((100::numeric - md.percentage) / 100::numeric), 3)
     ELSE round(pd.price * scr.conversion_rate, 3)
     END AS selling_price,
0 AS order_units, 
0 AS order_merch_value, 
0 AS order_cost_value, 
1 AS cancel_units, 
si.unit_price AS cancel_merch_value, 
pp.uk_landed_cost AS cancel_cost_value, 
0 AS return_units, 
0 AS return_merch_value, 
0 AS return_cost_value, 
(-1) AS net_units, 
- si.unit_price AS net_merch_value, 
- pp.uk_landed_cost AS net_cost_value


FROM 

orders o
   JOIN link_orders__shipment los ON o.id = los.orders_id
   JOIN shipment s ON los.shipment_id = s.id AND s.shipment_class_id = 1
   JOIN shipment_item si ON s.id = si.shipment_id
   JOIN variant v ON si.variant_id = v.id
   JOIN product p ON v.product_id = p.id
   JOIN customer c on c.id = o.customer_id
   JOIN order_address oa on o.invoice_address_id = oa.id
   JOIN order_address oa2 on s.shipment_address_id = oa2.id
   LEFT JOIN price_default pd ON pd.product_id = p.id
   LEFT JOIN price_adjustment md ON md.product_id = p.id AND md.date_start <= now()::date AND md.date_finish > now()::date
   JOIN sales_conversion_rate scr ON pd.currency_id = scr.source_currency
   JOIN price_purchase pp ON p.id = pp.product_id
   JOIN shipment_item_status_log sisl on si.id = sisl.shipment_item_id AND sisl.shipment_item_status_id = 10


WHERE 
scr.destination_currency = 1 AND 'now'::text::date > scr.date_start AND (scr.date_finish IS NULL OR 'now'::text::date < scr.date_finish)
AND o.channel_id = 3)
UNION ALL
SELECT 
date_trunc('day'::text, risl.date) AS date, 
'return' AS action, 
c.id AS customer_id,
c.is_customer_number, 
o.id AS orders_id, 
o.order_nr, 
o.currency_id, 
oa2.country AS shipping_country, 
oa.country AS billing_country, 
v.product_id, 
CASE WHEN md.id IS NOT NULL 
     THEN round(pd.price * scr.conversion_rate * ((100::numeric - md.percentage) / 100::numeric), 3)
     ELSE round(pd.price * scr.conversion_rate, 3)
     END AS selling_price,
0 AS order_units, 
0 AS order_merch_value, 
0 AS order_cost_value,
0 AS cancel_units, 
0 AS cancel_merch_value, 
0 AS cancel_cost_value, 
1 AS return_units, 
si.unit_price AS return_merch_value, 
pp.uk_landed_cost AS return_cost_value, 
(-1) AS net_units, 
- si.unit_price AS net_merch_value, 
- pp.uk_landed_cost AS net_cost_value


FROM 
orders o
   JOIN link_orders__shipment los ON o.id = los.orders_id
   JOIN shipment s ON los.shipment_id = s.id
   JOIN shipment_item si ON s.id = si.shipment_id
   JOIN variant v ON si.variant_id = v.id
   JOIN product p ON v.product_id = p.id
   JOIN customer c on c.id = o.customer_id
   JOIN order_address oa on o.invoice_address_id = oa.id
   JOIN order_address oa2 on s.shipment_address_id = oa2.id
   LEFT JOIN price_default pd ON pd.product_id = p.id
   LEFT JOIN price_adjustment md ON md.product_id = p.id AND md.date_start <= now()::date AND md.date_finish > now()::date
   JOIN sales_conversion_rate scr ON pd.currency_id = scr.source_currency
   JOIN price_purchase pp ON p.id = pp.product_id
   JOIN return_item ri on si.id = ri.shipment_item_id AND ri.return_type_id = 1
   JOIN return_item_status_log risl on ri.id = risl.return_item_id AND risl.return_item_status_id = 7


WHERE 
scr.destination_currency = 1 AND 'now'::text::date > scr.date_start AND (scr.date_finish IS NULL OR 'now'::text::date < scr.date_finish)
AND o.channel_id = 3;

ALTER TABLE njiv_net_sales_outnet OWNER TO postgres;


-------------------------------------------------
CREATE OR REPLACE VIEW njiv_orders_outnet AS 
SELECT 
tmp.date_ts, 
tmp.date, 
tmp.order_id, 
tmp.order_nr, 
tmp.customer_id, 
tmp.is_customer_number, 
tmp.currency_id, 
tmp.currency, 
tmp.country, 
sum(tmp.unit_count) AS unit_count, 
sum(tmp.merchandise_sales_value) AS merchandise_sales_value, 
sum(tmp.tax_value) AS tax_value, 
sum(tmp.duties_value) AS duties_value, 
sum(tmp.shipping_value) AS shipping_value, 
sum(tmp.gift_credit_redeemed) AS gift_credit_redeemed, 
sum(tmp.store_credit_redeemed) AS store_credit_redeemed, 
sum(tmp.gross_sales_value) + sum(tmp.total) AS total_order_value, tmp.first_order
FROM 
( 
	SELECT 
	o.date AS date_ts, 
	date_trunc('day'::text, o.date) AS date, 
	o.id AS order_id, 
	o.order_nr, 
	o.customer_id, 
	cu.is_customer_number, 
	o.currency_id, 
	c.currency, 
	oa.country, 
	count(si.variant_id) AS unit_count, 
	sum(si.unit_price) AS merchandise_sales_value, 
	sum(si.tax) AS tax_value, 
	sum(si.duty) AS duties_value, 
	sum(si.unit_price + si.tax + si.duty) AS gross_sales_value, 
	0 AS shipping_value, 
	0 AS gift_credit_redeemed, 
	0 AS store_credit_redeemed, 0 AS total, 
        CASE WHEN (3 IN ( SELECT order_flag.flag_id FROM orders, order_flag WHERE o.id = orders.id AND orders.id = order_flag.orders_id)) 
	     THEN 'Y'::text
             ELSE 'N'::text
             END AS first_order
        
	FROM 
	orders o 
	JOIN link_orders__shipment los on o.id = los.orders_id
	JOIN shipment s on los.shipment_id = s.id AND s.shipment_class_id = 1
	JOIN shipment_item si on s.id = si.shipment_id
	JOIN currency c on o.currency_id = c.id
	JOIN order_address oa on o.invoice_address_id = oa.id     	
	LEFT JOIN customer cu ON o.customer_id = cu.id
     
	WHERE 
	si.variant_id <> 49285 AND si.variant_id <> 67158 AND si.variant_id <> 73652
	AND o.channel_id = 3
     
	GROUP BY 
	o.date, 
	date_trunc('day'::text, o.date), 
	o.id, 
	o.order_nr, 
	o.customer_id, 
	cu.is_customer_number, 
	o.currency_id, 
	c.currency, 
	oa.country, 
        CASE WHEN (3 IN ( SELECT order_flag.flag_id FROM orders, order_flag WHERE o.id = orders.id AND orders.id = order_flag.orders_id)) 
             THEN 'Y'::text
             ELSE 'N'::text
             END
UNION 
	SELECT o.date AS date_ts, 
	date_trunc('day'::text, o.date) AS date, 
	o.id AS order_id, 
	o.order_nr, 
	o.customer_id, 
	cu.is_customer_number, 
	o.currency_id, 
	c.currency, 
	oa.country, 
	0 AS unit_count, 
	0 AS merchandise_sales_value, 
	0 AS tax_value, 
	0 AS duties_value, 
	0 AS gross_sales_value, 
	sum(s.shipping_charge) AS shipping_value, 
	sum(s.gift_credit) AS gift_credit_redeemed, 
	sum(s.store_credit) AS store_credit_redeemed, 
	sum(s.shipping_charge + s.gift_credit + s.store_credit) AS total, 
        CASE WHEN (3 IN ( SELECT order_flag.flag_id FROM orders, order_flag WHERE o.id = orders.id AND orders.id = order_flag.orders_id)) 
	     THEN 'Y'::text
             ELSE 'N'::text
             END AS first_order
        
	FROM 
	orders o 
	JOIN link_orders__shipment los on o.id = los.orders_id
	JOIN shipment s on los.shipment_id = s.id AND s.shipment_class_id = 1
	JOIN currency c on o.currency_id = c.id
	JOIN order_address oa on o.invoice_address_id = oa.id     	
	LEFT JOIN customer cu ON o.customer_id = cu.id


     	WHERE 
	o.channel_id = 3
  
	GROUP BY 
	o.date, 
	date_trunc('day'::text, o.date), 
	o.id, 
	o.order_nr, 
	o.customer_id, 
	cu.is_customer_number, 
	o.currency_id, 
	c.currency, 
	oa.country, 
        CASE WHEN (3 IN ( SELECT order_flag.flag_id FROM orders, order_flag WHERE o.id = orders.id AND orders.id = order_flag.orders_id)) 
	     THEN 'Y'::text
             ELSE 'N'::text
             END
) tmp
GROUP BY 
tmp.date_ts, tmp.order_nr, tmp.date, tmp.order_id, tmp.customer_id, tmp.is_customer_number, tmp.currency_id, tmp.currency, tmp.country, tmp.first_order

ORDER BY tmp.date_ts, tmp.order_nr;

ALTER TABLE njiv_orders_outnet OWNER TO postgres;


-------------------------------------------------
CREATE OR REPLACE VIEW njiv_preorder_returns_dispatchdate_outnet AS

SELECT 
sisl.date AS date_ts, 
date_trunc('day'::text, sisl.date) AS date, 
o.id AS order_id, 
o.order_nr, 
o.customer_id, 
cu.is_customer_number, 
c.currency, 
oa.country, 
count(si.variant_id) AS unit_count, 
sum(si.unit_price) AS merchandise_sales_value, 
sum(si.tax) AS tax_value, 
sum(si.duty) AS duties_value, 
sum(si.unit_price + si.tax + si.duty) AS gross_sales_value, 
0 AS shipping_value, 
0 AS gift_credit_redeemed, 
0 AS store_credit_redeemed, 
0 AS total, 
CASE WHEN (3 IN ( SELECT order_flag.flag_id FROM orders, order_flag WHERE o.id = orders.id AND orders.id = order_flag.orders_id)) 
     THEN 'Y'::text
     ELSE 'N'::text
     END AS first_order

FROM orders o
LEFT JOIN customer cu ON o.customer_id = cu.id
JOIN link_orders__shipment los ON o.id = los.orders_id
JOIN shipment s ON los.shipment_id = s.id
JOIN shipment_item si ON s.id = si.shipment_id
JOIN currency c ON o.currency_id = c.id
JOIN order_address oa ON o.invoice_address_id = oa.id
JOIN return_item ri ON si.id = ri.shipment_item_id
JOIN order_flag of ON o.id = of.orders_id
LEFT JOIN shipment_item_status_log sisl ON si.id = sisl.shipment_item_id

WHERE (ri.return_item_status_id = ANY (ARRAY[5, 6, 7])) AND ri.return_type_id = 1 AND of.flag_id = 45 AND sisl.shipment_item_status_id = 4
AND o.channel_id = 3

GROUP BY sisl.date, date_trunc('day'::text, sisl.date), o.id, o.order_nr, o.customer_id, cu.is_customer_number, c.currency, oa.country, 
CASE
    WHEN (3 IN ( SELECT order_flag.flag_id
       FROM orders, order_flag
      WHERE o.id = orders.id AND orders.id = order_flag.orders_id)) THEN 'Y'::text
    ELSE 'N'::text
END;
ALTER TABLE njiv_preorder_returns_dispatchdate_outnet OWNER TO postgres;
-------------------------------------------------

CREATE OR REPLACE VIEW njiv_prod_orders_outnet AS 
 
SELECT 
product_id, ordered as qty 

FROM 
product.stock_summary

WHERE
channel_id = 3;

ALTER TABLE njiv_prod_orders_outnet OWNER TO postgres;
-------------------------------------------------

CREATE OR REPLACE VIEW njiv_product_ordered_qty_outnet AS 

SELECT 
po.product_id, 
po.qty AS ordered_quantity, 
round(po.qty::numeric * pp.uk_landed_cost, 2) AS cost_ordered

FROM 
njiv_prod_orders_outnet po
JOIN price_purchase pp on po.product_id = pp.product_id;


ALTER TABLE njiv_product_ordered_qty_outnet OWNER TO postgres;

-------------------------------------------------
CREATE OR REPLACE VIEW njiv_pws_log_stock_reporting_outnet AS 
SELECT 
p.id AS product_id, 
v.id AS variant_id, 
pa."action", 
pw.pws_action_id, 
pw.quantity, 
date_trunc('day'::text, pw.date) AS date, 
date_trunc('day'::text, fso.date) AS first_sold_out_date, 
CASE WHEN pw.pws_action_id = 11 OR pw.pws_action_id = 10 OR pw.pws_action_id = 7 OR pw.pws_action_id = 8 OR pw.pws_action_id = 9 OR pw.pws_action_id = 12    

 

     THEN pw.quantity::bigint
     ELSE 0::bigint
     END AS uploadunits, 
CASE WHEN pw.pws_action_id = 2 OR pw.pws_action_id = 3 OR pw.pws_action_id = 4 OR pw.pws_action_id = 5 THEN (pw.quantity * -1)::bigint
     ELSE 0::bigint
     END AS salesunits, 
CASE WHEN pw.pws_action_id = 11 OR pw.pws_action_id = 10 OR pw.pws_action_id = 7 OR pw.pws_action_id = 1 OR pw.pws_action_id = 8 OR pw.pws_action_id = 9 OR 

pw.pws_action_id = 12 OR pw.pws_action_id = 13 
     THEN pw.quantity::bigint
     ELSE 0::bigint
     END AS uploadamendedunits, 
CASE WHEN pw.pws_action_id = 11 OR pw.pws_action_id = 10 OR pw.pws_action_id = 7 OR pw.pws_action_id = 8 OR pw.pws_action_id = 9 OR pw.pws_action_id = 12    

 

 THEN pw.quantity::bigint::numeric::double precision * mpa.uk_landed_cost::double precision
     ELSE 0::bigint::numeric::double precision
     END AS uploadcost, 
CASE WHEN pw.pws_action_id = 2 OR pw.pws_action_id = 3 OR pw.pws_action_id = 4 OR pw.pws_action_id = 5 
     THEN (pw.quantity * -1)::bigint::numeric::double precision * mpa.uk_landed_cost::double precision
     ELSE 0::bigint::numeric::double precision
     END AS salescost, 
CASE WHEN pw.pws_action_id = 11 OR pw.pws_action_id = 10 OR pw.pws_action_id = 7 OR pw.pws_action_id = 1 OR pw.pws_action_id = 8 OR pw.pws_action_id = 9 OR 

pw.pws_action_id = 12 OR pw.pws_action_id = 13 
     THEN pw.quantity::bigint::numeric::double precision * mpa.uk_landed_cost::double precision
     ELSE 0::bigint::numeric::double precision
     END AS uploadamendedcost,
mpa.season, 
mpa.designer, 
mpa.classification, 
mpa.product_type, 
mpa.sub_type, 
mpa.name, 
mpa.visible, 
mpa.live, 
mpa.style_number, 
mpa.legacy_sku, 
mpa.description, 
mpa.colour, 
mpa.mastercolor, 
mpa.original_selling_price, 
mpa.uk_landed_cost, 
mpa.selling_price, 
mpa.upload_date

FROM product p
LEFT JOIN njiv_1st_sold_out_outnet fso ON p.id = fso.product_id
JOIN njiv_master_product_attributes_outnet mpa ON p.id = mpa.product_id 
JOIN variant v ON p.id = v.product_id 
JOIN log_pws_stock pw ON v.id = pw.variant_id and pw.channel_id = 3
JOIN pws_action pa ON pw.pws_action_id = pa.id; 

ALTER TABLE njiv_pws_log_stock_reporting_outnet OWNER TO postgres;


-------------------------------------------------

CREATE OR REPLACE VIEW njiv_returns_outnet AS
SELECT o.date AS date_ts, 
date_trunc('day'::text, o.date) AS date, 
o.id AS order_id, 
o.order_nr, 
o.customer_id, 
cu.is_customer_number, 
c.currency, 
oa.country, 
count(si.variant_id) AS unit_count, 
sum(si.unit_price) AS merchandise_sales_value, 
sum(si.tax) AS tax_value, 
sum(si.duty) AS duties_value, 
sum(si.unit_price + si.tax + si.duty) AS gross_sales_value, 
0 AS shipping_value, 
0 AS gift_credit_redeemed, 
0 AS store_credit_redeemed, 
0 AS total, 
CASE WHEN (3 IN ( SELECT order_flag.flag_id FROM orders, order_flag WHERE o.id = orders.id AND orders.id = order_flag.orders_id)) 
     THEN 'Y'::text
     ELSE 'N'::text
     END AS first_order, 'N'::text AS whole_order

FROM orders o
JOIN link_orders__shipment los ON o.id = los.orders_id
JOIN shipment s ON los.shipment_id = s.id
JOIN shipment_item si ON s.id = si.shipment_id
JOIN currency c ON o.currency_id = c.id
JOIN order_address oa ON o.invoice_address_id = oa.id
JOIN return_item ri ON si.id = ri.shipment_item_id AND (ri.return_item_status_id = ANY (ARRAY[5, 6, 7])) AND ri.return_type_id = 1
LEFT JOIN customer cu ON o.customer_id = cu.id

WHERE si.variant_id <> 49285 AND si.variant_id <> 67158 AND si.variant_id <> 73652 
AND o.channel_id = 3

GROUP BY 
o.date, 
date_trunc('day'::text, o.date), 
o.id, o.order_nr, 
o.customer_id, 
cu.is_customer_number, 
c.currency, 
oa.country, 
   CASE
       WHEN (3 IN ( SELECT order_flag.flag_id
          FROM orders, order_flag
         WHERE o.id = orders.id AND orders.id = order_flag.orders_id)) THEN 'Y'::text
       ELSE 'N'::text
   END;
ALTER TABLE njiv_returns_outnet OWNER TO postgres;



-------------------------------------------------
CREATE OR REPLACE VIEW njiv_rm_cancellations_outnet AS 
 SELECT tmp.date_ts, tmp.date, tmp.order_id, tmp.order_nr, tmp.customer_id, tmp.is_customer_number, tmp.currency, tmp.country, sum(tmp.unit_count) AS 

unit_count, sum(tmp.merchandise_sales_value) AS merchandise_sales_value, sum(tmp.tax_value) AS tax_value, sum(tmp.duties_value) AS duties_value, 

sum(tmp.shipping_value) AS shipping_value, sum(tmp.gift_credit_redeemed) AS gift_credit_redeemed, sum(tmp.store_credit_redeemed) AS store_credit_redeemed, 

sum(tmp.gross_sales_value) + sum(tmp.total) AS total_order_value, tmp.first_order, max(tmp.whole_order) AS max
   FROM ( SELECT o.date AS date_ts, date_trunc('day'::text, o.date) AS date, o.id AS order_id, o.order_nr, o.customer_id, cu.is_customer_number, c.currency, 

oa.country, count(si.variant_id) AS unit_count, sum(si.unit_price) AS merchandise_sales_value, sum(si.tax) AS tax_value, sum(si.duty) AS duties_value, 

sum(si.unit_price + si.tax + si.duty) AS gross_sales_value, 0 AS shipping_value, 0 AS gift_credit_redeemed, 0 AS store_credit_redeemed, 0 AS total, 
                CASE
                    WHEN (3 IN ( SELECT order_flag.flag_id
                       FROM orders, order_flag
                      WHERE o.id = orders.id AND orders.id = order_flag.orders_id)) THEN 'Y'::text
                    ELSE 'N'::text
                END AS first_order, 'N'::text AS whole_order
           FROM orders o
      LEFT JOIN customer cu ON o.customer_id = cu.id
   JOIN link_orders__shipment los ON o.id = los.orders_id
   JOIN shipment s ON los.shipment_id = s.id
   JOIN shipment_item si ON s.id = si.shipment_id AND s.shipment_class_id = 1 AND (si.shipment_item_status_id = ANY (ARRAY[9, 10]))
   JOIN currency c ON o.currency_id = c.id
   JOIN order_address oa ON o.invoice_address_id = oa.id
   JOIN order_flag of on o.id = of.orders_id and of.flag_id = 45

WHERE si.variant_id <> 49285 AND si.variant_id <> 67158 AND si.variant_id <> 73652 AND o.channel_id = 3
  GROUP BY o.date, date_trunc('day'::text, o.date), o.id, o.order_nr, o.customer_id, cu.is_customer_number, c.currency, oa.country, 
CASE
    WHEN (3 IN ( SELECT order_flag.flag_id
       FROM orders, order_flag
      WHERE o.id = orders.id AND orders.id = order_flag.orders_id)) THEN 'Y'::text
    ELSE 'N'::text
END
UNION 
         SELECT o.date AS date_ts, date_trunc('day'::text, o.date) AS date, o.id AS order_id, o.order_nr, o.customer_id, cu.is_customer_number, c.currency, 

oa.country, 0 AS unit_count, 0 AS merchandise_sales_value, 0 AS tax_value, 0 AS duties_value, 0 AS gross_sales_value, sum(s.shipping_charge) AS 

shipping_value, sum(s.gift_credit) AS gift_credit_redeemed, sum(s.store_credit) AS store_credit_redeemed, sum(s.shipping_charge + s.gift_credit + 

s.store_credit) AS total, 
                CASE
                    WHEN (3 IN ( SELECT order_flag.flag_id
                       FROM orders, order_flag
                      WHERE o.id = orders.id AND orders.id = order_flag.orders_id)) THEN 'Y'::text
                    ELSE 'N'::text
                END AS first_order, 'Y'::text AS whole_order
           FROM orders o
      LEFT JOIN customer cu ON o.customer_id = cu.id
   JOIN link_orders__shipment los ON o.id = los.orders_id
   JOIN shipment s ON los.shipment_id = s.id AND s.shipment_class_id = 1 AND s.shipment_status_id = 5
   JOIN currency c ON o.currency_id = c.id
   JOIN order_address oa ON o.invoice_address_id = oa.id
   JOIN order_flag of on o.id = of.orders_id and of.flag_id = 45

  WHERE o.channel_id = 3
  GROUP BY o.date, date_trunc('day'::text, o.date), o.id, o.order_nr, o.customer_id, cu.is_customer_number, c.currency, oa.country, 
CASE
    WHEN (3 IN ( SELECT order_flag.flag_id
       FROM orders, order_flag
      WHERE o.id = orders.id AND orders.id = order_flag.orders_id)) THEN 'Y'::text
    ELSE 'N'::text
END) tmp
  GROUP BY tmp.date_ts, tmp.order_nr, tmp.date, tmp.order_id, tmp.customer_id, tmp.is_customer_number, tmp.currency, tmp.country, tmp.first_order
  ORDER BY tmp.date_ts, tmp.order_nr;

ALTER TABLE njiv_rm_cancellations_outnet OWNER TO postgres;
-------------------------------------------------
CREATE OR REPLACE VIEW njiv_rm_daily_totals_currency_outnet AS

SELECT
tmp.date,
tmp.currency,
sum(tmp.order_count) AS order_count,
sum(tmp.units) AS units,
sum(tmp.merchandise_sales_value) AS merchandise_sales_value,
sum(tmp.tax_value) AS tax_value,
sum(tmp.duties_value) AS duties_value,
sum(tmp.gross_sales_value) AS gross_sales_value,
sum(tmp.shipping_value) AS shipping_value,
sum(tmp.gift_credit_redeemed) AS gift_credit_redeemed,
sum(tmp.store_credit_redeemed) AS store_credit_redeemed,
sum(tmp.total) AS gross_shipping_total

FROM
(
	SELECT date_trunc('day'::text, o.date) AS date,
	c.currency,
	count(DISTINCT o.order_nr) AS order_count,
	count(si.id) AS units,
	sum(si.unit_price) AS merchandise_sales_value,
	sum(si.tax) AS tax_value,
	sum(si.duty) AS duties_value,
	sum(si.unit_price + si.tax + si.duty) AS gross_sales_value,
	0 AS shipping_value,
	0 AS gift_credit_redeemed,
	0 AS store_credit_redeemed,
	0 AS total,
	0 AS new_order_count,
	0 AS new_units,
	0 AS new_merchandise_sales_value,
	0 AS new_tax_value,
	0 AS new_duties_value,
	0 AS new_gross_sales_value,
	0 AS new_shipping_value,
	0 AS new_gift_credit_redeemed,
	0 AS new_store_credit_redeemed,
	0 AS new_total

	FROM
	orders o
	JOIN link_orders__shipment los ON o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id AND s.shipment_class_id = 1
	JOIN shipment_item si ON s.id = si.shipment_id
	JOIN currency c ON o.currency_id = c.id
	JOIN order_flag of ON o.id = of.orders_id AND of.flag_id = 45

	WHERE si.variant_id <> 49285 AND si.variant_id <> 67158 AND si.variant_id <> 73652
	AND o.channel_id = 3

        GROUP BY date_trunc('day'::text, o.date), c.currency

UNION
        SELECT date_trunc('day'::text, o.date) AS date,
	c.currency,
	0 AS order_count,
	0 AS units,
	0 AS merchandise_sales_value,
	0 AS tax_value,
	0 AS duties_value,
	0 AS gross_sales_value,
	sum(s.shipping_charge) AS shipping_value,
	sum(s.gift_credit) AS gift_credit_redeemed,
	sum(s.store_credit) AS store_credit_redeemed,
	sum(s.shipping_charge + s.gift_credit + s.store_credit) AS total,
	0 AS new_order_count,
	0 AS new_units,
	0 AS new_merchandise_sales_value,
	0 AS new_tax_value,
	0 AS new_duties_value,
	0 AS new_gross_sales_value,
	0 AS new_shipping_value,
	0 AS new_gift_credit_redeemed,
	0 AS new_store_credit_redeemed,
	0 AS new_total

	FROM orders o
	JOIN link_orders__shipment los ON o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id AND s.shipment_class_id = 1
	JOIN currency c ON o.currency_id = c.id
	JOIN order_flag of ON o.id = of.orders_id AND of.flag_id = 45

	WHERE o.channel_id = 3

	GROUP BY date_trunc('day'::text, o.date), c.currency
	) tmp
GROUP BY tmp.date, tmp.currency;

ALTER TABLE njiv_rm_daily_totals_currency_outnet OWNER TO postgres;

-------------------------------------------------

CREATE OR REPLACE VIEW njiv_rm_daily_totals_currency_dispatch_outnet AS 
 
SELECT 
tmp.date, 
tmp.currency, 
sum(tmp.units) AS units, 
sum(tmp.merchandise_sales_value) AS merchandise_sales_value, 
sum(tmp.tax_value) AS tax_value, 
sum(tmp.duties_value) AS duties_value, 
sum(tmp.gross_sales_value) AS gross_sales_value, 
sum(tmp.shipping_value) AS shipping_value, 
sum(tmp.gift_credit_redeemed) AS gift_credit_redeemed, 
sum(tmp.store_credit_redeemed) AS store_credit_redeemed, 
sum(tmp.total) AS gross_shipping_total

FROM 
	( 
	SELECT date_trunc('day'::text, ssl.date) AS date, 
	c.currency, 
	count(si.id) AS units, 
	sum(si.unit_price) AS merchandise_sales_value, 
	sum(si.tax) AS tax_value, 
	sum(si.duty) AS duties_value, 
	sum(si.unit_price + si.tax + si.duty) AS gross_sales_value, 
	0 AS shipping_value, 
	0 AS gift_credit_redeemed, 
	0 AS store_credit_redeemed, 0 AS total
        
	FROM orders o
      	JOIN link_orders__shipment los ON o.id = los.orders_id
   	JOIN shipment s ON los.shipment_id = s.id
   	JOIN shipment_item si ON s.id = si.shipment_id
   	JOIN currency c ON o.currency_id = c.id
   	JOIN order_flag of ON o.id = of.orders_id
   	JOIN shipment_status_log ssl ON s.id = ssl.shipment_id
  	
	WHERE s.shipment_class_id = 1 AND of.flag_id = 45 AND ssl.shipment_status_id = 4 AND o.channel_id = 3
	GROUP BY date_trunc('day'::text, ssl.date), c.currency
	
UNION 
       SELECT date_trunc('day'::text, ssl.date) AS date, 
	c.currency, 
	0 AS units, 
	0 AS merchandise_sales_value, 
	0 AS tax_value, 
	0 AS duties_value, 
	0 AS gross_sales_value, 
	sum(s.shipping_charge) AS shipping_value, 
	sum(s.gift_credit) AS gift_credit_redeemed, 
	sum(s.store_credit) AS store_credit_redeemed, 
	sum(s.shipping_charge + s.gift_credit + s.store_credit) AS total
        
	FROM orders o
      	JOIN link_orders__shipment los ON o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id
	JOIN currency c ON o.currency_id = c.id
	JOIN order_flag of ON o.id = of.orders_id
	JOIN shipment_status_log ssl ON s.id = ssl.shipment_id
 
	WHERE s.shipment_class_id = 1 AND of.flag_id = 45 AND ssl.shipment_status_id = 4 AND o.channel_id = 3

	GROUP BY date_trunc('day'::text, ssl.date), c.currency
	) tmp

GROUP BY tmp.date, tmp.currency;

ALTER TABLE njiv_rm_daily_totals_currency_dispatch_outnet OWNER TO postgres;


-------------------------------------------------
CREATE OR REPLACE VIEW njiv_rm_returns_outnet AS 
 
SELECT 
o.date AS date_ts, 
date_trunc('day'::text, o.date) AS date, 
o.id AS order_id, 
o.order_nr, 
o.customer_id, 
cu.is_customer_number, 
c.currency, 
oa.country, 
count(si.variant_id) AS unit_count, 
sum(si.unit_price) AS merchandise_sales_value, 
sum(si.tax) AS tax_value, 
sum(si.duty) AS duties_value, 
sum(si.unit_price + si.tax + si.duty) AS gross_sales_value, 
0 AS shipping_value, 
0 AS gift_credit_redeemed, 
0 AS store_credit_redeemed, 
0 AS total, 
CASE WHEN (3 IN ( SELECT order_flag.flag_id FROM orders, order_flag WHERE o.id = orders.id AND orders.id = order_flag.orders_id)) 
     THEN 'Y'::text
     ELSE 'N'::text
     END AS first_order

FROM 
orders o
LEFT JOIN customer cu ON o.customer_id = cu.id
JOIN link_orders__shipment los ON o.id = los.orders_id
JOIN shipment s ON los.shipment_id = s.id
JOIN shipment_item si ON s.id = si.shipment_id
JOIN currency c ON o.currency_id = c.id
JOIN order_address oa ON o.invoice_address_id = oa.id
JOIN return_item ri ON si.id = ri.shipment_item_id
JOIN order_flag of ON o.id = of.orders_id


WHERE (ri.return_item_status_id = ANY (ARRAY[5, 6, 7])) AND ri.return_type_id = 1 AND of.flag_id = 45 AND o.channel_id = 3

GROUP BY 
o.date, 
date_trunc('day'::text, o.date), 
o.id, 
o.order_nr, 
o.customer_id, 
cu.is_customer_number, 
c.currency, 
oa.country, 
CASE WHEN (3 IN ( SELECT order_flag.flag_id FROM orders, order_flag WHERE o.id = orders.id AND orders.id = order_flag.orders_id)) 
     THEN 'Y'::text
     ELSE 'N'::text
     END;

ALTER TABLE njiv_rm_returns_outnet OWNER TO postgres;



-------------------------------------------------
CREATE OR REPLACE VIEW njiv_stock_by_location_outnet AS
SELECT lt.type, p.id as product_id, sum(q.quantity) AS quantity

FROM quantity q
JOIN variant v ON q.variant_id = v.id
JOIN product p ON v.product_id = p.id
JOIN location loc ON q.location_id = loc.id
JOIN location_type lt ON loc.type_id = lt.id

WHERE q.channel_id = 3

GROUP BY lt.type, p.id

UNION

SELECT 'GoodsIn' AS type, v.product_id, sum(sp.quantity) AS quantity

FROM
stock_process sp
JOIN delivery_item di ON sp.delivery_item_id = di.id
JOIN link_delivery_item__stock_order_item ldi_soi ON di.id = ldi_soi.delivery_item_id
JOIN stock_order_item soi ON ldi_soi.stock_order_item_id = soi.id
JOIN stock_order so ON so.id = soi.stock_order_id
LEFT JOIN purchase_order po ON so.purchase_order_id = po.id AND po.channel_id = 3
JOIN variant v ON soi.variant_id = v.id

WHERE di.cancel = false AND di.status_id < 4

GROUP BY v.product_id;

ALTER TABLE njiv_stock_by_location_outnet OWNER TO postgres;

-------------------------------------------------
CREATE OR REPLACE VIEW njiv_variant_free_stock_outnet AS 
SELECT 
saleable.variant_id, 
saleable.legacy_sku, 
saleable.season,
sum(saleable.quantity) AS quantity
FROM 
((((
	SELECT 
	v.id AS variant_id, 
	v.legacy_sku, 
	se.season, 
	sum(q.quantity) AS quantity
        
	FROM 
	quantity q
	JOIN variant v ON q.variant_id = v.id
	JOIN product p on v.product_id = p.id
	JOIN season se on p.season_id = se.id
        
	WHERE 
	NOT (q.location_id IN ( SELECT location.id FROM location WHERE location.type_id <> 1))
	AND q.channel_id = 3 
	
        
	GROUP BY v.id, 
	v.legacy_sku, 
	se.season


UNION ALL 

        SELECT 
	v.id AS variant_id, 
	v.legacy_sku, 
	se.season, 
	- count(*) AS quantity
        
	FROM 
	reservation r
	JOIN variant v ON r.variant_id = v.id AND r.status_id = 2
	JOIN product p on v.product_id = p.id
	JOIN season se on p.season_id = se.id

        WHERE r.channel_id = 3
	
        
	GROUP BY 
	v.id, 
	v.legacy_sku, 
	se.season
	)

UNION ALL 
        
	SELECT 
	v.id AS variant_id, 
	v.legacy_sku, 
	se.season, 
	- count(*) AS quantity
        
	FROM 
	orders o
	JOIN link_orders__shipment los ON o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id
	JOIN shipment_item si ON s.id = si.shipment_id AND si.shipment_item_status_id < 3
	JOIN variant v ON si.variant_id = v.id
	JOIN product p on v.product_id = p.id
	JOIN season se on p.season_id = se.id
        
	WHERE 
	o.channel_id = 3
	
        GROUP BY v.id, v.legacy_sku, se.season
	)

UNION ALL 
         
	SELECT 
	v.id AS variant_id, 
	v.legacy_sku, 
	se.season, 
	- count(*) AS quantity
        
	FROM 

	orders o
	JOIN link_orders__shipment los ON o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id
	JOIN shipment_item si ON s.id = si.shipment_id AND si.shipment_item_status_id = 10
	JOIN cancelled_item ci on si.id = ci.shipment_item_id AND ci.adjusted = 0
	JOIN variant v on si.variant_id = v.id
	JOIN product p on v.product_id = p.id
	JOIN season se on p.season_id = se.id

        WHERE 
	o.channel_id = 3	
        
	GROUP BY v.id, v.legacy_sku, se.season
	) 

UNION ALL 
        
	SELECT 
	v.id AS variant_id, 
	v.legacy_sku, 
	se.season, 
	- count(*) AS quantity
        
	FROM 
	stock_transfer o
	JOIN link_stock_transfer__shipment los ON o.id = los.stock_transfer_id
	JOIN shipment s ON los.shipment_id = s.id
	JOIN shipment_item si ON s.id = si.shipment_id AND si.shipment_item_status_id < 3
	JOIN variant v ON si.variant_id = v.id
	JOIN product p on v.product_id = p.id
	JOIN season se on p.season_id = se.id
        
	WHERE o.channel_id = 3
	
        GROUP BY v.id, v.legacy_sku, se.season
	)
	saleable

GROUP BY saleable.variant_id, saleable.legacy_sku, saleable.season;

ALTER TABLE njiv_variant_free_stock_outnet OWNER TO postgres;
-------------------------------------------------

CREATE OR REPLACE VIEW vw_sale_orders_outnet AS 
SELECT 
sales.date, 
sales.order_nr, 
sum(sales.item) AS order_items, 
'sale_order'::text AS sale_order

FROM 
	(
	SELECT 
	o.order_nr, 
	o.date, 
	v.product_id, 
	max_date_start.date_start, 1 AS item, 
        CASE WHEN max_date_start.date_start IS NOT NULL
		THEN 1
                ELSE NULL::integer
                END AS sale

        FROM 
	orders o
	JOIN link_orders__shipment los ON o.id = los.orders_id
	JOIN shipment s ON los.shipment_id = s.id
	JOIN shipment_item si ON s.id = si.shipment_id
	JOIN variant v ON si.variant_id = v.id 
	LEFT JOIN 
		(
		SELECT 
		max(pa1.date_start) AS date_start, 
		pa1.product_id
                
		FROM
		price_adjustment pa1
                
		GROUP BY 
		pa1.product_id
		) max_date_start ON v.product_id = max_date_start.product_id

	WHERE
	o.channel_id = 3 AND
	(max_date_start.date_start < o.date::date OR max_date_start.date_start IS NULL)
	) sales

GROUP BY
sales.date,
sales.order_nr

HAVING 
sum(sales.sale) = sum(sales.item);

ALTER TABLE vw_sale_orders_outnet OWNER TO postgres;

-------------------------------------------------


COMMIT;