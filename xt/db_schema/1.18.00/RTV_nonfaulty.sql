/*******************************************************
* RTV Enhancements:-
*
* * Add 'RTV Non-Faulty' location (type 'RTV Process')
* * Add table rtv_nonfaulty_location
* * Add column: rtv_quantity.date_created
* * Recreate existing RTV views 
*
*******************************************************/

BEGIN;

/********************
* RTV Non Faulty
********************/
INSERT INTO location (location, type_id) VALUES ('RTV Non-Faulty', (SELECT id FROM location_type WHERE type = 'RTV Process'));


/*************************
* rtv_nonfaulty_location
*************************/
CREATE TABLE rtv_nonfaulty_location (
    rtv_quantity_id INTEGER NOT NULL PRIMARY KEY,
    original_location VARCHAR(255) NOT NULL
);
GRANT ALL ON rtv_nonfaulty_location TO www;


/********************
* RTV Quantity Date
********************/
ALTER TABLE ONLY rtv_quantity ADD COLUMN date_created timestamp without time zone NOT NULL DEFAULT LOCALTIMESTAMP;

COMMIT;



BEGIN;

/****************************************
* Drop and recreate existing views
****************************************/

DROP VIEW vw_list_rma;
DROP VIEW vw_rtv_quantity_check;
DROP VIEW vw_rtv_shipment_details_with_results;
DROP VIEW vw_rtv_shipment_detail_result_totals_row;
DROP VIEW vw_rtv_shipment_detail_result_totals;
DROP VIEW vw_rtv_inspection_validate_pick;
DROP VIEW vw_rtv_inspection_list;
DROP VIEW vw_rtv_inspection_pick_requested;
DROP VIEW vw_rtv_inspection_pick_request_details;
DROP VIEW vw_rtv_workstation_stock;
DROP VIEW vw_rtv_inspection_stock;
DROP VIEW vw_rtv_shipment_validate_pack;
DROP VIEW vw_rtv_shipment_validate_pick;
DROP VIEW vw_rtv_shipment_packlist;
DROP VIEW vw_rtv_shipment_picklist;
DROP VIEW vw_rtv_shipment_details;
DROP VIEW vw_rma_request_designers;
DROP VIEW vw_rma_request_notes;
DROP VIEW vw_rma_request_details;
DROP VIEW vw_designer_rtv_carrier;
DROP VIEW vw_designer_rtv_address;
DROP VIEW vw_rtv_address;
DROP VIEW vw_rtv_stock_designers;
DROP VIEW vw_rtv_stock_details;
DROP VIEW vw_rtv_quantity;
DROP VIEW vw_location_details;
DROP VIEW vw_return_details;
DROP VIEW vw_stock_order_details;
DROP VIEW vw_delivery_details;
DROP VIEW vw_stock_process;
DROP VIEW vw_product_variant;


SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

SET search_path = public, pg_catalog;



/**********************
* vw_product_variant
**********************/
--
-- Name: vw_product_variant; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_product_variant AS
    SELECT
        v.product_id
    ,   p.world_id
    ,   w.world
    ,   p.classification_id
    ,   c.classification
    ,   p.product_type_id
    ,   pt.product_type
    ,   curr.currency AS wholesale_currency
    ,   pp.original_wholesale
    ,   p.designer_id
    ,   d.designer
    ,   p.colour_id
    ,   col.colour
    ,   pa.designer_colour_code
    ,   pa.designer_colour
    ,   p.style_number
    ,   p.season_id
    ,   s.season
    ,   pa.name
    ,   pa.description
    ,   p.visible
    ,   p.live
    ,   p.staging
    ,   v.id AS variant_id
    ,   (((v.product_id)::text || '-'::text) || lpad((v.size_id)::text, 3, (0)::text)) AS sku
    ,   v.legacy_sku, v.type_id AS variant_type_id
    ,   vt.type AS variant_type
    ,   v.size_id
    ,   sz.size
    ,   nsz.nap_size
    ,   v.designer_size_id
    ,   dsz.size AS designer_size
    FROM ((((((((((((((product p JOIN product_attribute pa ON ((p.id = pa.product_id))) JOIN price_purchase pp ON ((p.id = pp.product_id))) JOIN currency curr ON ((pp.wholesale_currency_id = curr.id))) JOIN designer d ON ((p.designer_id = d.id))) JOIN colour col ON ((p.colour_id = col.id))) JOIN world w ON ((p.world_id = w.id))) JOIN classification c ON ((p.classification_id = c.id))) JOIN product_type pt ON ((p.product_type_id = pt.id))) JOIN season s ON ((p.season_id = s.id))) JOIN variant v ON ((p.id = v.product_id))) JOIN variant_type vt ON ((v.type_id = vt.id))) LEFT JOIN size sz ON ((v.size_id = sz.id))) LEFT JOIN nap_size nsz ON ((v.nap_size_id = nsz.id))) LEFT JOIN size dsz ON ((v.designer_size_id = dsz.id)))
;


ALTER TABLE public.vw_product_variant OWNER TO postgres;

--
-- Name: vw_product_variant; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE vw_product_variant FROM PUBLIC;
REVOKE ALL ON TABLE vw_product_variant FROM postgres;
GRANT ALL ON TABLE vw_product_variant TO postgres;
GRANT SELECT ON TABLE vw_product_variant TO www;



/********************
* vw_stock_process
********************/
--
-- Name: vw_stock_process; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_stock_process AS
    SELECT
        sp.id AS stock_process_id
    ,   sp.delivery_item_id
    ,   sp.quantity
    ,   sp.group_id
    ,   sp.type_id AS stock_process_type_id
    ,   spt."type" AS stock_process_type
    ,   sp.status_id AS stock_process_status_id
    ,   sps.status AS stock_process_status
    ,   sp.complete
    FROM ((stock_process sp JOIN stock_process_type spt ON ((sp.type_id = spt.id))) JOIN stock_process_status sps ON ((sp.status_id = sps.id)))
;


ALTER TABLE public.vw_stock_process OWNER TO postgres;

--
-- Name: vw_stock_process; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE vw_stock_process FROM PUBLIC;
REVOKE ALL ON TABLE vw_stock_process FROM postgres;
GRANT ALL ON TABLE vw_stock_process TO postgres;
GRANT SELECT ON TABLE vw_stock_process TO www;



/***********************
* vw_delivery_details
***********************/
--
-- Name: vw_delivery_details; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_delivery_details AS
    SELECT
        d.id AS delivery_id
    ,   d.date
    ,   d.invoice_nr
    ,   d.cancel AS delivery_cancel
    ,   d.type_id AS delivery_type_id
    ,   dt."type" AS delivery_type
    ,   d.status_id AS delivery_status_id
    ,   ds.status AS delivery_status
    ,   di.id AS delivery_item_id
    ,   di.packing_slip
    ,   di.quantity
    ,   di.cancel AS delivery_item_cancel
    ,   di.type_id AS delivery_item_type_id
    ,   dit."type" AS delivery_item_type
    ,   di.status_id AS delivery_item_status_id
    ,   dis.status AS delivery_item_status
    FROM (((((delivery d JOIN delivery_type dt ON ((d.type_id = dt.id))) JOIN delivery_status ds ON ((d.status_id = ds.id))) JOIN delivery_item di ON ((di.delivery_id = d.id))) JOIN delivery_item_type dit ON ((di.type_id = dit.id))) JOIN delivery_item_status dis ON ((di.status_id = dis.id)))
;


ALTER TABLE public.vw_delivery_details OWNER TO postgres;

--
-- Name: vw_delivery_details; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE vw_delivery_details FROM PUBLIC;
REVOKE ALL ON TABLE vw_delivery_details FROM postgres;
GRANT ALL ON TABLE vw_delivery_details TO postgres;
GRANT SELECT ON TABLE vw_delivery_details TO www;



/**************************
* vw_stock_order_details
**************************/
--
-- Name: vw_stock_order_details; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_stock_order_details AS
    SELECT
        so.id AS stock_order_id
    ,   so.product_id
    ,   so.purchase_order_id
    ,   so.start_ship_date
    ,   so.cancel_ship_date
    ,   so.status_id AS stock_order_status_id
    ,   sos.status AS stock_order_status
    ,   so."comment"
    ,   so.type_id AS stock_order_type_id
    ,   sot."type" AS stock_order_type
    ,   so.consignment
    ,   so.cancel AS stock_order_cancel
    ,   soi.id AS stock_order_item_id
    ,   soi.variant_id
    ,   soi.quantity
    ,   soi.status_id AS stock_order_item_status_id
    ,   sois.status AS stock_order_item_status
    ,   soi.status_id AS stock_order_item_type_id
    ,   soit."type" AS stock_order_item_type
    ,   soi.cancel AS stock_order_item_cancel
    ,   soi.original_quantity
    FROM (((((stock_order so JOIN stock_order_type sot ON ((so.type_id = sot.id))) JOIN stock_order_status sos ON ((so.status_id = sos.id))) JOIN stock_order_item soi ON ((soi.stock_order_id = so.id))) JOIN stock_order_item_type soit ON ((soi.type_id = soit.id))) JOIN stock_order_item_status sois ON ((soi.status_id = sois.id)))
;


ALTER TABLE public.vw_stock_order_details OWNER TO postgres;

--
-- Name: vw_stock_order_details; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE vw_stock_order_details FROM PUBLIC;
REVOKE ALL ON TABLE vw_stock_order_details FROM postgres;
GRANT ALL ON TABLE vw_stock_order_details TO postgres;
GRANT SELECT ON TABLE vw_stock_order_details TO www;



/*********************
* vw_return_details
*********************/
--
-- Name: vw_return_details; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_return_details AS
    SELECT
        r.id AS return_id
    ,   r.shipment_id
    ,   r.rma_number
    ,   r.return_status_id
    ,   rs.status AS return_status
    ,   r."comment"
    ,   r.exchange_shipment_id
    ,   r.pickup
    ,   ri.id AS return_item_id
    ,   ri.shipment_item_id
    ,   ri.return_item_status_id
    ,   ris.status AS return_item_status
    ,   cit.description AS customer_issue_type_description
    ,   ri.return_type_id AS return_item_type_id
    ,   rt."type" AS return_item_type
    ,   ri.return_airway_bill
    ,   ri.variant_id
    FROM (((((return r JOIN return_status rs ON ((r.return_status_id = rs.id))) JOIN return_item ri ON ((ri.return_id = r.id))) JOIN return_type rt ON ((ri.return_type_id = rt.id))) JOIN return_item_status ris ON ((ri.return_item_status_id = ris.id))) JOIN customer_issue_type cit ON ((ri.customer_issue_type_id = cit.id)))
;


ALTER TABLE public.vw_return_details OWNER TO postgres;

--
-- Name: vw_return_details; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE vw_return_details FROM PUBLIC;
REVOKE ALL ON TABLE vw_return_details FROM postgres;
GRANT ALL ON TABLE vw_return_details TO postgres;
GRANT SELECT ON TABLE vw_return_details TO www;



/***********************
* vw_location_details
***********************/
--
-- Name: vw_location_details; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_location_details AS
    SELECT
        l.id AS location_id
    ,   l."location"
    ,   "substring"((l."location")::text, '\\A(\\d{2})\\d[a-zA-Z]-?\\d{3,4}[a-zA-Z]\\Z'::text) AS loc_dc
    ,   "substring"((l."location")::text, '\\A\\d{2}(\\d)[a-zA-Z]-?\\d{3,4}[a-zA-Z]\\Z'::text) AS loc_floor
    ,   "substring"((l."location")::text, '\\A\\d{2}\\d([a-zA-Z])-?\\d{3,4}[a-zA-Z]\\Z'::text) AS loc_zone
    ,   "substring"((l."location")::text, '\\A\\d{2}\\d[a-zA-Z]-?(\\d{3,4})[a-zA-Z]\\Z'::text) AS loc_section
    ,   "substring"((l."location")::text, '\\A\\d{2}\\d[a-zA-Z]-?\\d{3,4}([a-zA-Z])\\Z'::text) AS loc_shelf
    ,   lt.id AS location_type_id
    ,   lt."type" AS location_type
    FROM ("location" l JOIN location_type lt ON ((l.type_id = lt.id)))
;


ALTER TABLE public.vw_location_details OWNER TO postgres;

--
-- Name: vw_location_details; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE vw_location_details FROM PUBLIC;
REVOKE ALL ON TABLE vw_location_details FROM postgres;
GRANT ALL ON TABLE vw_location_details TO postgres;
GRANT SELECT ON TABLE vw_location_details TO www;



/*******************
* vw_rtv_quantity
*******************/
--
-- Name: vw_rtv_quantity; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_rtv_quantity AS
    SELECT
        rq.id
    ,   rq.variant_id
    ,   rq.location_id
    ,   rq.quantity
    ,   rq.delivery_item_id
    ,   rq.fault_type_id
    ,   rq.fault_description
    ,   rq.origin
    ,   rq.date_created
    ,   v.product_id
    ,   l."location"
    ,   lt."type" AS location_type
    ,   rrd.rma_request_id
    ,   rrd.id AS rma_request_detail_id
    ,   rrd.quantity AS rma_request_detail_quantity
    ,   rsd.rtv_shipment_id
    ,   rsd.id AS rtv_shipment_detail_id
    ,   rsd.quantity AS rtv_shipment_detail_quantity
    FROM (((((rtv_quantity rq JOIN "location" l ON ((rq.location_id = l.id))) JOIN location_type lt ON ((l.type_id = lt.id))) JOIN variant v ON ((rq.variant_id = v.id))) LEFT JOIN rma_request_detail rrd ON ((rrd.rtv_quantity_id = rq.id))) LEFT JOIN rtv_shipment_detail rsd ON ((rsd.rma_request_detail_id = rrd.id)))
;


ALTER TABLE public.vw_rtv_quantity OWNER TO postgres;

--
-- Name: vw_rtv_quantity; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE vw_rtv_quantity FROM PUBLIC;
REVOKE ALL ON TABLE vw_rtv_quantity FROM postgres;
GRANT ALL ON TABLE vw_rtv_quantity TO postgres;
GRANT SELECT ON TABLE vw_rtv_quantity TO www;



/************************
* vw_rtv_stock_details
************************/
--
-- Name: vw_rtv_stock_details; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_rtv_stock_details AS
    SELECT
        rq.id AS rtv_quantity_id
    ,   rq.variant_id
    ,   rq.location_id
    ,   rq.origin
    ,   rq.date_created AS rtv_quantity_date
    ,   to_char(rq.date_created, 'DD-Mon-YYYY HH24:MI'::text) AS txt_rtv_quantity_date
    ,   vw_ld."location"
    ,   vw_ld.loc_dc
    ,   vw_ld.loc_floor
    ,   vw_ld.loc_zone
    ,   vw_ld.loc_section
    ,   vw_ld.loc_shelf
    ,   vw_ld.location_type
    ,   rq.quantity
    ,   rq.fault_type_id
    ,   ft.fault_type
    ,   rq.fault_description
    ,   vw_dd.delivery_id
    ,   vw_dd.delivery_item_id
    ,   vw_dd.delivery_item_type
    ,   vw_dd.delivery_item_status
    ,   vw_dd.date AS delivery_date
    ,   to_char(vw_dd.date, 'DD-Mon-YYYY HH24:MI'::text) AS txt_delivery_date
    ,   vw_pv.product_id
    ,   vw_pv.size_id
    ,   vw_pv.size
    ,   vw_pv.designer_size_id
    ,   vw_pv.designer_size
    ,   vw_pv.sku
    ,   vw_pv.name
    ,   vw_pv.description
    ,   vw_pv.designer_id
    ,   vw_pv.designer
    ,   vw_pv.style_number
    ,   vw_pv.colour
    ,   vw_pv.designer_colour_code
    ,   vw_pv.designer_colour
    ,   vw_pv.product_type_id
    ,   vw_pv.product_type
    ,   vw_pv.classification_id
    ,   vw_pv.classification
    ,   vw_pv.season_id
    ,   vw_pv.season
    ,   rrd.rma_request_id
    FROM (((((rtv_quantity rq JOIN vw_location_details vw_ld ON ((rq.location_id = vw_ld.location_id))) JOIN vw_product_variant vw_pv ON ((rq.variant_id = vw_pv.variant_id))) LEFT JOIN item_fault_type ft ON ((rq.fault_type_id = ft.id))) LEFT JOIN rma_request_detail rrd ON ((rq.id = rrd.rtv_quantity_id))) LEFT JOIN vw_delivery_details vw_dd ON ((rq.delivery_item_id = vw_dd.delivery_item_id)))
;


ALTER TABLE public.vw_rtv_stock_details OWNER TO postgres;

--
-- Name: vw_rtv_stock_details; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE vw_rtv_stock_details FROM PUBLIC;
REVOKE ALL ON TABLE vw_rtv_stock_details FROM postgres;
GRANT ALL ON TABLE vw_rtv_stock_details TO postgres;
GRANT SELECT ON TABLE vw_rtv_stock_details TO www;



/**************************
* vw_rtv_stock_designers
**************************/
--
-- Name: vw_rtv_stock_designers; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_rtv_stock_designers AS
    SELECT
        DISTINCT p.designer_id
    ,   d.designer
    FROM (((rtv_quantity rq JOIN variant v ON ((rq.variant_id = v.id))) JOIN product p ON ((v.product_id = p.id))) JOIN designer d ON ((p.designer_id = d.id)))
    ORDER BY p.designer_id, d.designer
;


ALTER TABLE public.vw_rtv_stock_designers OWNER TO postgres;

--
-- Name: vw_rtv_stock_designers; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE vw_rtv_stock_designers FROM PUBLIC;
REVOKE ALL ON TABLE vw_rtv_stock_designers FROM postgres;
GRANT ALL ON TABLE vw_rtv_stock_designers TO postgres;
GRANT SELECT ON TABLE vw_rtv_stock_designers TO www;



/******************
* vw_rtv_address
******************/
--
-- Name: vw_rtv_address; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_rtv_address AS
    SELECT
        rtv_address.id
    ,   rtv_address.address_line_1
    ,   rtv_address.address_line_2
    ,   rtv_address.address_line_3
    ,   rtv_address.town_city
    ,   rtv_address.region_county
    ,   rtv_address.postcode_zip
    ,   rtv_address.country
    ,   md5(((((((btrim(lower((rtv_address.address_line_1)::text)) || btrim(lower((rtv_address.address_line_2)::text))) || btrim(lower((rtv_address.address_line_3)::text))) || btrim(lower((rtv_address.country)::text))) || btrim(lower((rtv_address.postcode_zip)::text))) || btrim(lower((rtv_address.region_county)::text))) || btrim(lower((rtv_address.town_city)::text)))) AS address_hash
    FROM rtv_address
;


ALTER TABLE public.vw_rtv_address OWNER TO postgres;

--
-- Name: vw_rtv_address; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE vw_rtv_address FROM PUBLIC;
REVOKE ALL ON TABLE vw_rtv_address FROM postgres;
GRANT ALL ON TABLE vw_rtv_address TO postgres;
GRANT SELECT ON TABLE vw_rtv_address TO www;



/***************************
* vw_designer_rtv_address
***************************/
--
-- Name: vw_designer_rtv_address; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_designer_rtv_address AS
    SELECT
        d.id AS designer_id
    ,   d.designer
    ,   vw_ra.id AS rtv_address_id
    ,   vw_ra.address_line_1
    ,   vw_ra.address_line_2
    ,   vw_ra.address_line_3
    ,   vw_ra.town_city
    ,   vw_ra.region_county
    ,   vw_ra.postcode_zip
    ,   vw_ra.country
    ,   vw_ra.address_hash
    ,   d_ra.id AS designer_rtv_address_id
    ,   d_ra.contact_name
    ,   d_ra.do_not_use
    FROM ((designer d JOIN designer_rtv_address d_ra ON ((d.id = d_ra.designer_id))) JOIN vw_rtv_address vw_ra ON ((vw_ra.id = d_ra.rtv_address_id)))
;


ALTER TABLE public.vw_designer_rtv_address OWNER TO postgres;

--
-- Name: vw_designer_rtv_address; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE vw_designer_rtv_address FROM PUBLIC;
REVOKE ALL ON TABLE vw_designer_rtv_address FROM postgres;
GRANT ALL ON TABLE vw_designer_rtv_address TO postgres;
GRANT SELECT ON TABLE vw_designer_rtv_address TO www;



/***************************
* vw_designer_rtv_carrier
***************************/
--
-- Name: vw_designer_rtv_carrier; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_designer_rtv_carrier AS
    SELECT
        d.id AS designer_id
    ,   d.designer
    ,   rc.id AS rtv_carrier_id
    ,   rc.name AS rtv_carrier_name
    ,   d_rc.id AS designer_rtv_carrier_id
    ,   d_rc.account_ref
    ,   CASE COALESCE(d_rc.account_ref, ''::character varying)
            WHEN ''::text THEN (rc.name)::text
            ELSE (((rc.name)::text || ' : '::text) || (d_rc.account_ref)::text)
        END AS designer_carrier
    ,   d_rc.do_not_use
    FROM ((designer d JOIN designer_rtv_carrier d_rc ON ((d.id = d_rc.designer_id))) RIGHT JOIN rtv_carrier rc ON ((rc.id = d_rc.rtv_carrier_id)))
;


ALTER TABLE public.vw_designer_rtv_carrier OWNER TO postgres;

--
-- Name: vw_designer_rtv_carrier; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE vw_designer_rtv_carrier FROM PUBLIC;
REVOKE ALL ON TABLE vw_designer_rtv_carrier FROM postgres;
GRANT ALL ON TABLE vw_designer_rtv_carrier TO postgres;
GRANT SELECT ON TABLE vw_designer_rtv_carrier TO www;



/**************************
* vw_rma_request_details
**************************/
--
-- Name: vw_rma_request_details; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_rma_request_details AS
    SELECT
        rr.id AS rma_request_id
    ,   rr.operator_id
    ,   op.name AS operator_name
    ,   op.email_address
    ,   rr.status_id AS rma_request_status_id
    ,   rrs.status AS rma_request_status
    ,   rr.date_request
    ,   to_char(rr.date_request, 'DD-Mon-YYYY HH24:MI'::text) AS txt_date_request
    ,   rr.date_followup
    ,   to_char(rr.date_followup, 'DD-Mon-YYYY'::text) AS txt_date_followup
    ,   rr.rma_number
    ,   rr.comments AS rma_request_comments
    ,   rrd.id AS rma_request_detail_id
    ,   rrd.rtv_quantity_id
    ,   vw_pv.product_id
    ,   vw_pv.size_id
    ,   vw_pv.sku
    ,   vw_pv.wholesale_currency
    ,   vw_pv.original_wholesale
    ,   vw_pv.variant_id
    ,   vw_pv.designer_id
    ,   vw_pv.designer
    ,   vw_pv.season_id
    ,   vw_pv.season
    ,   vw_pv.style_number
    ,   vw_pv.colour
    ,   vw_pv.designer_colour_code
    ,   vw_pv.designer_colour
    ,   vw_pv.name
    ,   vw_pv.description
    ,   vw_pv.size
    ,   vw_pv.designer_size
    ,   vw_pv.nap_size
    ,   vw_pv.product_type
    ,   vw_dd.delivery_item_id
    ,   vw_dd.delivery_item_type
    ,   vw_dd.date AS delivery_date
    ,   to_char(vw_dd.date, 'DD-Mon-YYYY HH24:MI'::text) AS txt_delivery_date
    ,   rrd.quantity AS rma_request_detail_quantity
    ,   ift.fault_type
    ,   rrd.fault_description
    ,   rrdt.id AS rma_request_detail_type_id
    ,   rrdt."type" AS rma_request_detail_type
    ,   rrds.id AS rma_request_detail_status_id
    ,   rrds.status AS rma_request_detail_status
    ,   vw_rstkd.quantity AS rtv_stock_detail_quantity
    ,   vw_rstkd."location"
    ,   vw_rstkd.loc_dc
    ,   vw_rstkd.loc_floor
    ,   vw_rstkd.loc_zone
    ,   vw_rstkd.loc_section
    ,   vw_rstkd.loc_shelf
    ,   vw_rstkd.location_type
    FROM (((((((((rma_request rr JOIN rma_request_status rrs ON ((rr.status_id = rrs.id))) JOIN "operator" op ON ((rr.operator_id = op.id))) JOIN rma_request_detail rrd ON ((rrd.rma_request_id = rr.id))) JOIN rma_request_detail_type rrdt ON ((rrd.type_id = rrdt.id))) JOIN item_fault_type ift ON ((rrd.fault_type_id = ift.id))) JOIN rma_request_detail_status rrds ON ((rrd.status_id = rrds.id))) LEFT JOIN vw_rtv_stock_details vw_rstkd ON ((rrd.rtv_quantity_id = vw_rstkd.rtv_quantity_id))) JOIN vw_product_variant vw_pv ON ((rrd.variant_id = vw_pv.variant_id))) LEFT JOIN vw_delivery_details vw_dd ON ((rrd.delivery_item_id = vw_dd.delivery_item_id)))
;


ALTER TABLE public.vw_rma_request_details OWNER TO postgres;

--
-- Name: vw_rma_request_details; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE vw_rma_request_details FROM PUBLIC;
REVOKE ALL ON TABLE vw_rma_request_details FROM postgres;
GRANT ALL ON TABLE vw_rma_request_details TO postgres;
GRANT SELECT ON TABLE vw_rma_request_details TO www;



/************************
* vw_rma_request_notes
************************/
--
-- Name: vw_rma_request_notes; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_rma_request_notes AS
    SELECT
        rrn.id AS rma_request_note_id
    ,   rrn.rma_request_id
    ,   rrn.date_time
    ,   to_char(rrn.date_time, 'DD-Mon-YYYY HH24:MI'::text) AS txt_date_time
    ,   rrn.note
    ,   rrn.operator_id
    ,   o.name AS operator_name
    ,   o.department_id
    ,   o.email_address
    ,   d.department
    FROM ((rma_request_note rrn JOIN "operator" o ON ((rrn.operator_id = o.id))) LEFT JOIN department d ON ((o.department_id = d.id)))
;


ALTER TABLE public.vw_rma_request_notes OWNER TO postgres;

--
-- Name: vw_rma_request_notes; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE vw_rma_request_notes FROM PUBLIC;
REVOKE ALL ON TABLE vw_rma_request_notes FROM postgres;
GRANT ALL ON TABLE vw_rma_request_notes TO postgres;
GRANT SELECT ON TABLE vw_rma_request_notes TO www;



/****************************
* vw_rma_request_designers
****************************/
--
-- Name: vw_rma_request_designers; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_rma_request_designers AS
    SELECT
        DISTINCT p.designer_id
    ,   d.designer
    FROM (((rma_request_detail rrd JOIN variant v ON ((rrd.variant_id = v.id))) JOIN product p ON ((v.product_id = p.id))) JOIN designer d ON ((p.designer_id = d.id)))
    ORDER BY p.designer_id, d.designer
;


ALTER TABLE public.vw_rma_request_designers OWNER TO postgres;

--
-- Name: vw_rma_request_designers; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE vw_rma_request_designers FROM PUBLIC;
REVOKE ALL ON TABLE vw_rma_request_designers FROM postgres;
GRANT ALL ON TABLE vw_rma_request_designers TO postgres;
GRANT SELECT ON TABLE vw_rma_request_designers TO www;



/***************************
* vw_rtv_shipment_details
***************************/
--
-- Name: vw_rtv_shipment_details; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_rtv_shipment_details AS
    SELECT
        rs.id AS rtv_shipment_id
    ,   rs.designer_rtv_carrier_id
    ,   vw_drc.rtv_carrier_name
    ,   vw_drc.account_ref AS carrier_account_ref
    ,   rs.designer_rtv_address_id
    ,   vw_dra.contact_name
    ,   vw_dra.address_line_1
    ,   vw_dra.address_line_2
    ,   vw_dra.address_line_3
    ,   vw_dra.town_city
    ,   vw_dra.region_county
    ,   vw_dra.postcode_zip
    ,   vw_dra.country
    ,   rs.date_time AS rtv_shipment_date
    ,   to_char(rs.date_time, 'DD-Mon-YYYY HH24:MI'::text) AS txt_rtv_shipment_date
    ,   rs.status_id AS rtv_shipment_status_id
    ,   rss.status AS rtv_shipment_status
    ,   rs.airway_bill
    ,   vw_rrd.rma_request_id
    ,   vw_rrd.operator_id
    ,   vw_rrd.operator_name
    ,   vw_rrd.email_address
    ,   vw_rrd.rma_request_status_id
    ,   vw_rrd.rma_request_status
    ,   vw_rrd.date_request
    ,   vw_rrd.txt_date_request
    ,   vw_rrd.date_followup
    ,   vw_rrd.txt_date_followup
    ,   vw_rrd.rma_number
    ,   vw_rrd.rma_request_comments
    ,   vw_rrd.rma_request_detail_id
    ,   vw_rrd.rtv_quantity_id
    ,   vw_rrd.product_id
    ,   vw_rrd.size_id
    ,   vw_rrd.sku
    ,   vw_rrd.wholesale_currency
    ,   vw_rrd.original_wholesale
    ,   vw_rrd.variant_id
    ,   vw_rrd.designer_id
    ,   vw_rrd.designer
    ,   vw_rrd.season_id
    ,   vw_rrd.season
    ,   vw_rrd.style_number
    ,   vw_rrd.colour
    ,   vw_rrd.designer_colour_code
    ,   vw_rrd.designer_colour
    ,   vw_rrd.name
    ,   vw_rrd.description
    ,   vw_rrd.size
    ,   vw_rrd.designer_size
    ,   vw_rrd.nap_size
    ,   vw_rrd.product_type
    ,   vw_rrd.delivery_item_id
    ,   vw_rrd.delivery_item_type
    ,   vw_rrd.delivery_date
    ,   vw_rrd.txt_delivery_date
    ,   vw_rrd.rma_request_detail_quantity
    ,   vw_rrd.fault_type
    ,   vw_rrd.fault_description
    ,   vw_rrd.rma_request_detail_type_id
    ,   vw_rrd.rma_request_detail_type
    ,   vw_rrd.rma_request_detail_status_id
    ,   vw_rrd.rma_request_detail_status
    ,   vw_rrd.rtv_stock_detail_quantity
    ,   vw_rrd."location"
    ,   vw_rrd.loc_dc
    ,   vw_rrd.loc_floor
    ,   vw_rrd.loc_zone
    ,   vw_rrd.loc_section
    ,   vw_rrd.loc_shelf
    ,   vw_rrd.location_type
    ,   rsd.id AS rtv_shipment_detail_id
    ,   rsd.quantity AS rtv_shipment_detail_quantity
    ,   rsd.status_id AS rtv_shipment_detail_status_id
    ,   rsds.status AS rtv_shipment_detail_status
    FROM ((((((rtv_shipment rs JOIN rtv_shipment_status rss ON ((rs.status_id = rss.id))) JOIN rtv_shipment_detail rsd ON ((rsd.rtv_shipment_id = rs.id))) JOIN rtv_shipment_detail_status rsds ON ((rsd.status_id = rsds.id))) JOIN vw_designer_rtv_carrier vw_drc ON ((rs.designer_rtv_carrier_id = vw_drc.designer_rtv_carrier_id))) JOIN vw_designer_rtv_address vw_dra ON ((rs.designer_rtv_address_id = vw_dra.designer_rtv_address_id))) JOIN vw_rma_request_details vw_rrd ON ((rsd.rma_request_detail_id = vw_rrd.rma_request_detail_id)))
;

ALTER TABLE public.vw_rtv_shipment_details OWNER TO postgres;

--
-- Name: vw_rtv_shipment_details; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE vw_rtv_shipment_details FROM PUBLIC;
REVOKE ALL ON TABLE vw_rtv_shipment_details FROM postgres;
GRANT ALL ON TABLE vw_rtv_shipment_details TO postgres;
GRANT SELECT ON TABLE vw_rtv_shipment_details TO www;



/****************************
* vw_rtv_shipment_picklist
****************************/
--
-- Name: vw_rtv_shipment_picklist; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_rtv_shipment_picklist AS
    SELECT
        rs.id AS rtv_shipment_id
    ,   rs.status_id AS rtv_shipment_status_id
    ,   rss.status AS rtv_shipment_status
    ,   rs.date_time AS rtv_shipment_date
    ,   to_char(rs.date_time,   'DD-Mon-YYYY HH24:MI'::text) AS txt_rtv_shipment_date
    ,   rsd.status_id AS rtv_shipment_detail_status_id
    ,   rsds.status AS rtv_shipment_detail_status
    ,   rsd.quantity AS rtv_shipment_detail_quantity
    ,   rr.id AS rma_request_id
    ,   rr.status_id AS rma_request_status_id
    ,   rr.date_request
    ,   to_char(rr.date_request, 'DD-Mon-YYYY HH24:MI'::text) AS txt_date_request
    ,   rrd.status_id AS rma_request_detail_status_id
    ,   rrd.fault_description
    ,   vw_pv.designer
    ,   vw_pv.sku
    ,   vw_pv.name
    ,   vw_pv.description
    ,   vw_pv.designer_size
    ,   vw_pv.colour
    ,   ift.fault_type
    ,   vw_ld.location
    ,   vw_ld.loc_dc
    ,   vw_ld.loc_floor
    ,   vw_ld.loc_zone
    ,   vw_ld.loc_section
    ,   vw_ld.loc_shelf
    ,   vw_ld.location_type
    ,   rnl.original_location
    FROM ((((((((((rtv_shipment rs JOIN rtv_shipment_status rss ON ((rs.status_id = rss.id))) JOIN rtv_shipment_detail rsd ON ((rsd.rtv_shipment_id = rs.id))) JOIN rtv_shipment_detail_status rsds ON ((rsd.status_id = rsds.id))) JOIN rma_request_detail rrd ON ((rrd.id = rsd.rma_request_detail_id))) JOIN vw_product_variant vw_pv ON ((rrd.variant_id = vw_pv.variant_id))) JOIN item_fault_type ift ON ((rrd.fault_type_id = ift.id))) JOIN rtv_quantity rq ON ((rrd.rtv_quantity_id = rq.id))) JOIN vw_location_details vw_ld ON ((rq.location_id = vw_ld.location_id))) JOIN rma_request rr ON ((rrd.rma_request_id = rr.id))) LEFT JOIN rtv_nonfaulty_location rnl ON ((rrd.rtv_quantity_id = rnl.rtv_quantity_id)))
;

ALTER TABLE public.vw_rtv_shipment_picklist OWNER TO postgres;

--
-- Name: vw_rtv_shipment_picklist; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE vw_rtv_shipment_picklist FROM PUBLIC;
REVOKE ALL ON TABLE vw_rtv_shipment_picklist FROM postgres;
GRANT ALL ON TABLE vw_rtv_shipment_picklist TO postgres;
GRANT SELECT ON TABLE vw_rtv_shipment_picklist TO www;



/****************************
* vw_rtv_shipment_packlist
****************************/
--
-- Name: vw_rtv_shipment_packlist; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_rtv_shipment_packlist AS
    SELECT
        rs.id AS rtv_shipment_id
    ,   rs.status_id AS rtv_shipment_status_id
    ,   rss.status AS rtv_shipment_status
    ,   rs.date_time AS rtv_shipment_date
    ,   to_char(rs.date_time, 'DD-Mon-YYYY HH24:MI'::text) AS txt_rtv_shipment_date
    ,   rsd.status_id AS rtv_shipment_detail_status_id
    ,   rsds.status AS rtv_shipment_detail_status
    ,   rsd.quantity AS rtv_shipment_detail_quantity
    ,   rr.id AS rma_request_id
    ,   rr.status_id AS rma_request_status_id
    ,   rr.date_request
    ,   to_char(rr.date_request, 'DD-Mon-YYYY HH24:MI'::text) AS txt_date_request
    ,   rrd.status_id AS rma_request_detail_status_id
    ,   rrd.fault_description
    ,   vw_pv.designer
    ,   vw_pv.sku
    ,   vw_pv.name
    ,   vw_pv.description
    ,   vw_pv.designer_size
    ,   vw_pv.colour
    ,   ift.fault_type
    FROM (((((((rtv_shipment rs JOIN rtv_shipment_status rss ON ((rs.status_id = rss.id))) JOIN rtv_shipment_detail rsd ON ((rsd.rtv_shipment_id = rs.id))) JOIN rtv_shipment_detail_status rsds ON ((rsd.status_id = rsds.id))) JOIN rma_request_detail rrd ON ((rrd.id = rsd.rma_request_detail_id))) JOIN vw_product_variant vw_pv ON ((rrd.variant_id = vw_pv.variant_id))) JOIN item_fault_type ift ON ((rrd.fault_type_id = ift.id))) JOIN rma_request rr ON ((rrd.rma_request_id = rr.id)))
;


ALTER TABLE public.vw_rtv_shipment_packlist OWNER TO postgres;

--
-- Name: vw_rtv_shipment_packlist; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE vw_rtv_shipment_packlist FROM PUBLIC;
REVOKE ALL ON TABLE vw_rtv_shipment_packlist FROM postgres;
GRANT ALL ON TABLE vw_rtv_shipment_packlist TO postgres;
GRANT SELECT ON TABLE vw_rtv_shipment_packlist TO www;



/*********************************
* vw_rtv_shipment_validate_pick
*********************************/
--
-- Name: vw_rtv_shipment_validate_pick; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_rtv_shipment_validate_pick AS
    SELECT
        a.rtv_shipment_id
    ,   a.rtv_shipment_status_id
    ,   a.rtv_shipment_status
    ,   a."location"
    ,   a.loc_dc
    ,   a.loc_floor
    ,   a.loc_zone
    ,   a.loc_section
    ,   a.loc_shelf
    ,   a.location_type
    ,   a.original_location
    ,   a.sku
    ,   a.sum_picklist_quantity
    ,   COALESCE(b.picked_quantity, (0)::bigint) AS picked_quantity
    ,   (a.sum_picklist_quantity - COALESCE(b.picked_quantity, (0)::bigint)) AS remaining_to_pick
    FROM (
        (SELECT
            vw_rtv_shipment_picklist.rtv_shipment_id
        ,   vw_rtv_shipment_picklist.rtv_shipment_status_id
        ,   vw_rtv_shipment_picklist.rtv_shipment_status
        ,   vw_rtv_shipment_picklist."location"
        ,   vw_rtv_shipment_picklist.loc_dc
        ,   vw_rtv_shipment_picklist.loc_floor
        ,   vw_rtv_shipment_picklist.loc_zone
        ,   vw_rtv_shipment_picklist.loc_section
        ,   vw_rtv_shipment_picklist.loc_shelf
        ,   vw_rtv_shipment_picklist.location_type
        ,   vw_rtv_shipment_picklist.sku
        ,   vw_rtv_shipment_picklist.original_location
        ,   sum(vw_rtv_shipment_picklist.rtv_shipment_detail_quantity) AS sum_picklist_quantity
         FROM vw_rtv_shipment_picklist
         WHERE ((vw_rtv_shipment_picklist.rtv_shipment_status)::text = ANY ((ARRAY['New'::character varying, 'Picking'::character varying])::text[]))
         GROUP BY vw_rtv_shipment_picklist.rtv_shipment_id, vw_rtv_shipment_picklist.rtv_shipment_status_id, vw_rtv_shipment_picklist.rtv_shipment_status, vw_rtv_shipment_picklist.sku, vw_rtv_shipment_picklist."location", vw_rtv_shipment_picklist.loc_dc, vw_rtv_shipment_picklist.loc_floor, vw_rtv_shipment_picklist.loc_zone, vw_rtv_shipment_picklist.loc_section, vw_rtv_shipment_picklist.loc_shelf, vw_rtv_shipment_picklist.location_type, vw_rtv_shipment_picklist.original_location) a
     LEFT JOIN
        (SELECT
            rtv_shipment_pick.rtv_shipment_id
        ,   rtv_shipment_pick."location"
        ,   rtv_shipment_pick.sku
        ,   count(*) AS picked_quantity
        FROM rtv_shipment_pick
        WHERE (rtv_shipment_pick.cancelled IS NULL)
        GROUP BY rtv_shipment_pick.rtv_shipment_id, rtv_shipment_pick.sku, rtv_shipment_pick."location") b
        ON ((((a.sku = (b.sku)::text) AND ((a."location")::text = (b."location")::text)) AND (a.rtv_shipment_id = b.rtv_shipment_id)))
     )
;


ALTER TABLE public.vw_rtv_shipment_validate_pick OWNER TO postgres;

--
-- Name: vw_rtv_shipment_validate_pick; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE vw_rtv_shipment_validate_pick FROM PUBLIC;
REVOKE ALL ON TABLE vw_rtv_shipment_validate_pick FROM postgres;
GRANT ALL ON TABLE vw_rtv_shipment_validate_pick TO postgres;
GRANT SELECT ON TABLE vw_rtv_shipment_validate_pick TO www;



/*********************************
* vw_rtv_shipment_validate_pack
*********************************/
--
-- Name: vw_rtv_shipment_validate_pack; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_rtv_shipment_validate_pack AS
    SELECT
        a.rtv_shipment_id
    ,   a.rtv_shipment_status_id
    ,   a.rtv_shipment_status
    ,   a.sku
    ,   a.sum_packlist_quantity
    ,   COALESCE(b.packed_quantity, (0)::bigint) AS packed_quantity
    ,   (a.sum_packlist_quantity - COALESCE(b.packed_quantity, (0)::bigint)) AS remaining_to_pack
    FROM (
        (SELECT
            vw_rtv_shipment_packlist.rtv_shipment_id
        ,   vw_rtv_shipment_packlist.rtv_shipment_status_id
        ,   vw_rtv_shipment_packlist.rtv_shipment_status
        ,   vw_rtv_shipment_packlist.sku
        ,   sum(vw_rtv_shipment_packlist.rtv_shipment_detail_quantity) AS sum_packlist_quantity
        FROM vw_rtv_shipment_packlist
        WHERE ((vw_rtv_shipment_packlist.rtv_shipment_status)::text = ANY ((ARRAY['Picked'::character varying, 'Packing'::character varying])::text[]))
        GROUP BY vw_rtv_shipment_packlist.rtv_shipment_id, vw_rtv_shipment_packlist.rtv_shipment_status_id, vw_rtv_shipment_packlist.rtv_shipment_status, vw_rtv_shipment_packlist.sku) a
    LEFT JOIN
        (SELECT
            rtv_shipment_pack.rtv_shipment_id
        ,   rtv_shipment_pack.sku
        ,   count(*) AS packed_quantity
        FROM rtv_shipment_pack
        WHERE (rtv_shipment_pack.cancelled IS NULL)
        GROUP BY rtv_shipment_pack.rtv_shipment_id, rtv_shipment_pack.sku) b
        ON (((a.sku = (b.sku)::text) AND (a.rtv_shipment_id = b.rtv_shipment_id)))
    )
;


ALTER TABLE public.vw_rtv_shipment_validate_pack OWNER TO postgres;

--
-- Name: vw_rtv_shipment_validate_pack; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE vw_rtv_shipment_validate_pack FROM PUBLIC;
REVOKE ALL ON TABLE vw_rtv_shipment_validate_pack FROM postgres;
GRANT ALL ON TABLE vw_rtv_shipment_validate_pack TO postgres;
GRANT SELECT ON TABLE vw_rtv_shipment_validate_pack TO www;



/***************************
* vw_rtv_inspection_stock
***************************/
--
-- Name: vw_rtv_inspection_stock; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_rtv_inspection_stock AS
    SELECT
        vw_rtv_stock_details.product_id
    ,   vw_rtv_stock_details.origin
    ,   max(vw_rtv_stock_details.rtv_quantity_date) AS rtv_quantity_date
    ,   to_char(max(vw_rtv_stock_details.rtv_quantity_date), 'DD-Mon-YYYY HH24:MI'::text) AS txt_rtv_quantity_date
    ,   vw_rtv_stock_details.designer_id
    ,   vw_rtv_stock_details.designer
    ,   vw_rtv_stock_details.colour
    ,   vw_rtv_stock_details.product_type
    ,   vw_rtv_stock_details.delivery_id
    ,   vw_rtv_stock_details.delivery_date
    ,   vw_rtv_stock_details.txt_delivery_date
    ,   sum(vw_rtv_stock_details.quantity) AS sum_quantity
    FROM vw_rtv_stock_details
    WHERE ((vw_rtv_stock_details.location_type)::text = 'RTV Goods In'::text)
    GROUP BY vw_rtv_stock_details.product_id, vw_rtv_stock_details.origin, vw_rtv_stock_details.designer_id, vw_rtv_stock_details.designer, vw_rtv_stock_details.colour, vw_rtv_stock_details.product_type, vw_rtv_stock_details.delivery_id, vw_rtv_stock_details.delivery_date, vw_rtv_stock_details.txt_delivery_date
;


ALTER TABLE public.vw_rtv_inspection_stock OWNER TO postgres;

--
-- Name: vw_rtv_inspection_stock; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE vw_rtv_inspection_stock FROM PUBLIC;
REVOKE ALL ON TABLE vw_rtv_inspection_stock FROM postgres;
GRANT ALL ON TABLE vw_rtv_inspection_stock TO postgres;
GRANT SELECT ON TABLE vw_rtv_inspection_stock TO www;



/****************************
* vw_rtv_workstation_stock
****************************/
--
-- Name: vw_rtv_workstation_stock; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_rtv_workstation_stock AS
    SELECT
        vw_rtv_stock_details.location_id
    ,   vw_rtv_stock_details."location"
    ,   vw_rtv_stock_details.product_id
    ,   vw_rtv_stock_details.origin
    ,   max(vw_rtv_stock_details.rtv_quantity_date) AS rtv_quantity_date
    ,   to_char(max(vw_rtv_stock_details.rtv_quantity_date), 'DD-Mon-YYYY HH24:MI'::text) AS txt_rtv_quantity_date
    ,   vw_rtv_stock_details.designer_id
    ,   vw_rtv_stock_details.designer
    ,   vw_rtv_stock_details.colour
    ,   vw_rtv_stock_details.product_type
    ,   vw_rtv_stock_details.delivery_id
    ,   vw_rtv_stock_details.delivery_date
    ,   vw_rtv_stock_details.txt_delivery_date
    ,   sum(vw_rtv_stock_details.quantity) AS sum_quantity
    FROM vw_rtv_stock_details WHERE ((vw_rtv_stock_details.location_type)::text = 'RTV Workstation'::text)
    GROUP BY vw_rtv_stock_details.location_id, vw_rtv_stock_details."location", vw_rtv_stock_details.product_id, vw_rtv_stock_details.origin, vw_rtv_stock_details.designer_id, vw_rtv_stock_details.designer, vw_rtv_stock_details.colour, vw_rtv_stock_details.product_type, vw_rtv_stock_details.delivery_id, vw_rtv_stock_details.delivery_date, vw_rtv_stock_details.txt_delivery_date
;


ALTER TABLE public.vw_rtv_workstation_stock OWNER TO postgres;

--
-- Name: vw_rtv_workstation_stock; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE vw_rtv_workstation_stock FROM PUBLIC;
REVOKE ALL ON TABLE vw_rtv_workstation_stock FROM postgres;
GRANT ALL ON TABLE vw_rtv_workstation_stock TO postgres;
GRANT SELECT ON TABLE vw_rtv_workstation_stock TO www;



/******************************************
* vw_rtv_inspection_pick_request_details
******************************************/
--
-- Name: vw_rtv_inspection_pick_request_details; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_rtv_inspection_pick_request_details AS
    SELECT
        ripr.id AS rtv_inspection_pick_request_id
    ,   ripr.date_time
    ,   to_char(ripr.date_time, 'DD-Mon-YYYY HH24:MI'::text) AS txt_date_time
    ,   riprd.id AS rtv_inspection_pick_request_item_id
    ,   riprd.rtv_quantity_id
    ,   ripr.status_id
    ,   riprs.status
    ,   vw_rstkd.product_id
    ,   vw_rstkd.origin
    ,   vw_rstkd.sku
    ,   vw_rstkd.designer
    ,   vw_rstkd.name
    ,   vw_rstkd.colour
    ,   vw_rstkd.designer_size
    ,   vw_rstkd.variant_id
    ,   vw_rstkd.delivery_id
    ,   vw_rstkd.delivery_item_id
    ,   vw_rstkd.quantity
    ,   vw_rstkd.fault_type
    ,   vw_rstkd.fault_description
    ,   vw_rstkd."location"
    ,   vw_rstkd.loc_dc
    ,   vw_rstkd.loc_floor
    ,   vw_rstkd.loc_zone
    ,   vw_rstkd.loc_section
    ,   vw_rstkd.loc_shelf
    ,   vw_rstkd.location_type
    FROM (((rtv_inspection_pick_request ripr JOIN rtv_inspection_pick_request_status riprs ON ((ripr.status_id = riprs.id))) JOIN rtv_inspection_pick_request_detail riprd ON ((riprd.rtv_inspection_pick_request_id = ripr.id))) JOIN vw_rtv_stock_details vw_rstkd ON ((riprd.rtv_quantity_id = vw_rstkd.rtv_quantity_id)))
;


ALTER TABLE public.vw_rtv_inspection_pick_request_details OWNER TO postgres;

--
-- Name: vw_rtv_inspection_pick_request_details; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE vw_rtv_inspection_pick_request_details FROM PUBLIC;
REVOKE ALL ON TABLE vw_rtv_inspection_pick_request_details FROM postgres;
GRANT ALL ON TABLE vw_rtv_inspection_pick_request_details TO postgres;
GRANT SELECT ON TABLE vw_rtv_inspection_pick_request_details TO www;



/************************************
* vw_rtv_inspection_pick_requested
************************************/
--
-- Name: vw_rtv_inspection_pick_requested; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_rtv_inspection_pick_requested AS
    SELECT
        vw_rtv_inspection_pick_request_details.product_id
    ,   vw_rtv_inspection_pick_request_details.origin
    ,   vw_rtv_inspection_pick_request_details.delivery_id
    ,   sum(vw_rtv_inspection_pick_request_details.quantity) AS quantity_requested
    FROM vw_rtv_inspection_pick_request_details WHERE ((vw_rtv_inspection_pick_request_details.status)::text = ANY ((ARRAY['New'::character varying, 'Picking'::character varying])::text[]))
    GROUP BY vw_rtv_inspection_pick_request_details.product_id, vw_rtv_inspection_pick_request_details.origin, vw_rtv_inspection_pick_request_details.delivery_id
;


ALTER TABLE public.vw_rtv_inspection_pick_requested OWNER TO postgres;

--
-- Name: vw_rtv_inspection_pick_requested; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE vw_rtv_inspection_pick_requested FROM PUBLIC;
REVOKE ALL ON TABLE vw_rtv_inspection_pick_requested FROM postgres;
GRANT ALL ON TABLE vw_rtv_inspection_pick_requested TO postgres;
GRANT ALL ON TABLE vw_rtv_inspection_pick_requested TO www;



/**************************
* vw_rtv_inspection_list
**************************/
--
-- Name: vw_rtv_inspection_list; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_rtv_inspection_list AS
    SELECT
        vw_ris.product_id
    ,   vw_ris.origin
    ,   vw_ris.rtv_quantity_date
    ,   vw_ris.txt_rtv_quantity_date
    ,   vw_ris.designer_id
    ,   vw_ris.designer
    ,   vw_ris.colour
    ,   vw_ris.product_type
    ,   vw_ris.delivery_id
    ,   vw_ris.delivery_date
    ,   vw_ris.txt_delivery_date
    ,   vw_ris.sum_quantity
    ,   COALESCE(vw_ripr.quantity_requested, (0)::bigint) AS quantity_requested
    ,   (vw_ris.sum_quantity - COALESCE(vw_ripr.quantity_requested, (0)::bigint)) AS quantity_remaining
    FROM (vw_rtv_inspection_stock vw_ris LEFT JOIN vw_rtv_inspection_pick_requested vw_ripr ON ((((vw_ris.product_id = vw_ripr.product_id) AND ((vw_ris.origin)::text = (vw_ripr.origin)::text)) AND (vw_ris.delivery_id = vw_ripr.delivery_id))))
;


ALTER TABLE public.vw_rtv_inspection_list OWNER TO postgres;

--
-- Name: vw_rtv_inspection_list; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE vw_rtv_inspection_list FROM PUBLIC;
REVOKE ALL ON TABLE vw_rtv_inspection_list FROM postgres;
GRANT ALL ON TABLE vw_rtv_inspection_list TO postgres;
GRANT SELECT ON TABLE vw_rtv_inspection_list TO www;



/***********************************
* vw_rtv_inspection_validate_pick
***********************************/
--
-- Name: vw_rtv_inspection_validate_pick; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_rtv_inspection_validate_pick AS
    SELECT
        a.rtv_inspection_pick_request_id
    ,   a.status_id
    ,   a.status
    ,   a."location"
    ,   a.loc_dc
    ,   a.loc_floor
    ,   a.loc_zone
    ,   a.loc_section
    ,   a.loc_shelf
    ,   a.location_type
    ,   a.sku
    ,   a.sum_picklist_quantity
    ,   COALESCE(b.picked_quantity, (0)::bigint) AS picked_quantity
    ,   (a.sum_picklist_quantity - COALESCE(b.picked_quantity, (0)::bigint)) AS remaining_to_pick
    FROM (
        (SELECT
            vw_rtv_inspection_pick_request_details.rtv_inspection_pick_request_id
        ,   vw_rtv_inspection_pick_request_details.status_id
        ,   vw_rtv_inspection_pick_request_details.status
        ,   vw_rtv_inspection_pick_request_details."location"
        ,   vw_rtv_inspection_pick_request_details.loc_dc
        ,   vw_rtv_inspection_pick_request_details.loc_floor
        ,   vw_rtv_inspection_pick_request_details.loc_zone
        ,   vw_rtv_inspection_pick_request_details.loc_section
        ,   vw_rtv_inspection_pick_request_details.loc_shelf
        ,   vw_rtv_inspection_pick_request_details.location_type
        ,   vw_rtv_inspection_pick_request_details.sku
        ,   sum(vw_rtv_inspection_pick_request_details.quantity) AS sum_picklist_quantity
        FROM vw_rtv_inspection_pick_request_details
        WHERE ((vw_rtv_inspection_pick_request_details.status)::text = ANY ((ARRAY['New'::character varying, 'Picking'::character varying])::text[]))
        GROUP BY vw_rtv_inspection_pick_request_details.rtv_inspection_pick_request_id, vw_rtv_inspection_pick_request_details.status_id, vw_rtv_inspection_pick_request_details.status, vw_rtv_inspection_pick_request_details.sku, vw_rtv_inspection_pick_request_details."location", vw_rtv_inspection_pick_request_details.loc_dc, vw_rtv_inspection_pick_request_details.loc_floor, vw_rtv_inspection_pick_request_details.loc_zone, vw_rtv_inspection_pick_request_details.loc_section, vw_rtv_inspection_pick_request_details.loc_shelf, vw_rtv_inspection_pick_request_details.location_type) a
    LEFT JOIN
        (SELECT
            rtv_inspection_pick.rtv_inspection_pick_request_id
        ,   rtv_inspection_pick."location"
        ,   rtv_inspection_pick.sku
        ,   count(*) AS picked_quantity
        FROM rtv_inspection_pick
        WHERE (rtv_inspection_pick.cancelled IS NULL)
        GROUP BY rtv_inspection_pick.rtv_inspection_pick_request_id, rtv_inspection_pick.sku, rtv_inspection_pick."location") b
        ON ((((a.sku = (b.sku)::text) AND ((a."location")::text = (b."location")::text)) AND (a.rtv_inspection_pick_request_id = b.rtv_inspection_pick_request_id)))
    )
;


ALTER TABLE public.vw_rtv_inspection_validate_pick OWNER TO postgres;

--
-- Name: vw_rtv_inspection_validate_pick; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE vw_rtv_inspection_validate_pick FROM PUBLIC;
REVOKE ALL ON TABLE vw_rtv_inspection_validate_pick FROM postgres;
GRANT ALL ON TABLE vw_rtv_inspection_validate_pick TO postgres;
GRANT SELECT ON TABLE vw_rtv_inspection_validate_pick TO www;



/****************************************
* vw_rtv_shipment_detail_result_totals
****************************************/
--
-- Name: vw_rtv_shipment_detail_result_totals; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_rtv_shipment_detail_result_totals AS
    SELECT
        c.rtv_shipment_detail_id
    ,   c.type_id
    ,   c."type"
    ,   COALESCE(d.sum_quantity, (0)::bigint) AS total_quantity
    FROM (
        (SELECT
            a.rtv_shipment_detail_id
        ,   b.type_id
        ,   b."type"
        FROM (
            (SELECT DISTINCT
                rtv_shipment_detail_result.rtv_shipment_detail_id
            FROM rtv_shipment_detail_result
            ORDER BY rtv_shipment_detail_result.rtv_shipment_detail_id) a
            CROSS JOIN
            (SELECT
                rtv_shipment_detail_result_type.id AS type_id
            ,   rtv_shipment_detail_result_type."type"
            FROM rtv_shipment_detail_result_type) b
        )) c
    LEFT JOIN
        (SELECT
            rsdr.rtv_shipment_detail_id
        ,   rsdr.type_id
        ,   rsdrt."type"
        ,   sum(rsdr.quantity) AS sum_quantity
        FROM (rtv_shipment_detail_result rsdr
        JOIN rtv_shipment_detail_result_type rsdrt
            ON ((rsdr.type_id = rsdrt.id)))
        GROUP BY rsdr.rtv_shipment_detail_id, rsdr.type_id, rsdrt."type") d
        ON (((c.rtv_shipment_detail_id = d.rtv_shipment_detail_id) AND (c.type_id = d.type_id)))
    )
;


ALTER TABLE public.vw_rtv_shipment_detail_result_totals OWNER TO postgres;

--
-- Name: vw_rtv_shipment_detail_result_totals; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE vw_rtv_shipment_detail_result_totals FROM PUBLIC;
REVOKE ALL ON TABLE vw_rtv_shipment_detail_result_totals FROM postgres;
GRANT ALL ON TABLE vw_rtv_shipment_detail_result_totals TO postgres;
GRANT SELECT ON TABLE vw_rtv_shipment_detail_result_totals TO www;



/********************************************
* vw_rtv_shipment_detail_result_totals_row
********************************************/
--
-- Name: vw_rtv_shipment_detail_result_totals_row; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_rtv_shipment_detail_result_totals_row AS
    SELECT
        vw_rtv_shipment_detail_result_totals.rtv_shipment_detail_id
    ,   sum(
            CASE vw_rtv_shipment_detail_result_totals."type"
                WHEN 'Unknown'::text THEN vw_rtv_shipment_detail_result_totals.total_quantity
                ELSE (0)::bigint
            END
        ) AS "unknown"
    ,   sum(
            CASE vw_rtv_shipment_detail_result_totals."type"
                WHEN 'Credited'::text THEN vw_rtv_shipment_detail_result_totals.total_quantity
                ELSE (0)::bigint
            END
        ) AS credited
    ,   sum(
            CASE vw_rtv_shipment_detail_result_totals."type"
                WHEN 'Repaired'::text THEN vw_rtv_shipment_detail_result_totals.total_quantity
                ELSE (0)::bigint
            END
        ) AS repaired
    ,   sum(
            CASE vw_rtv_shipment_detail_result_totals."type"
                WHEN 'Replaced'::text THEN vw_rtv_shipment_detail_result_totals.total_quantity
                ELSE (0)::bigint
            END
        ) AS replaced
    ,   sum(
            CASE vw_rtv_shipment_detail_result_totals."type"
                WHEN 'Dead'::text THEN vw_rtv_shipment_detail_result_totals.total_quantity
                ELSE (0)::bigint
            END
        ) AS dead
    ,   sum(
            CASE vw_rtv_shipment_detail_result_totals."type"
                WHEN 'Stock Swapped'::text
                THEN vw_rtv_shipment_detail_result_totals.total_quantity
                ELSE (0)::bigint
            END
        ) AS stock_swapped
    FROM vw_rtv_shipment_detail_result_totals
    GROUP BY vw_rtv_shipment_detail_result_totals.rtv_shipment_detail_id
;


ALTER TABLE public.vw_rtv_shipment_detail_result_totals_row OWNER TO postgres;

--
-- Name: vw_rtv_shipment_detail_result_totals_row; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE vw_rtv_shipment_detail_result_totals_row FROM PUBLIC;
REVOKE ALL ON TABLE vw_rtv_shipment_detail_result_totals_row FROM postgres;
GRANT ALL ON TABLE vw_rtv_shipment_detail_result_totals_row TO postgres;
GRANT SELECT ON TABLE vw_rtv_shipment_detail_result_totals_row TO www;



/****************************************
* vw_rtv_shipment_details_with_results
****************************************/
--
-- Name: vw_rtv_shipment_details_with_results; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_rtv_shipment_details_with_results AS
    SELECT
        vw_rsd.rtv_shipment_id
    ,   vw_rsd.designer_rtv_carrier_id
    ,   vw_rsd.rtv_carrier_name
    ,   vw_rsd.carrier_account_ref
    ,   vw_rsd.designer_rtv_address_id
    ,   vw_rsd.contact_name
    ,   vw_rsd.address_line_1
    ,   vw_rsd.address_line_2
    ,   vw_rsd.address_line_3
    ,   vw_rsd.town_city
    ,   vw_rsd.region_county
    ,   vw_rsd.postcode_zip
    ,   vw_rsd.country
    ,   vw_rsd.rtv_shipment_date
    ,   vw_rsd.txt_rtv_shipment_date
    ,   vw_rsd.rtv_shipment_status_id
    ,   vw_rsd.rtv_shipment_status
    ,   vw_rsd.airway_bill
    ,   vw_rsd.rma_request_id
    ,   vw_rsd.operator_id
    ,   vw_rsd.operator_name
    ,   vw_rsd.email_address
    ,   vw_rsd.rma_request_status_id
    ,   vw_rsd.rma_request_status
    ,   vw_rsd.date_request
    ,   vw_rsd.txt_date_request
    ,   vw_rsd.date_followup
    ,   vw_rsd.txt_date_followup
    ,   vw_rsd.rma_number
    ,   vw_rsd.rma_request_comments
    ,   vw_rsd.rma_request_detail_id
    ,   vw_rsd.rtv_quantity_id
    ,   vw_rsd.product_id
    ,   vw_rsd.size_id
    ,   vw_rsd.sku
    ,   vw_rsd.variant_id
    ,   vw_rsd.designer_id
    ,   vw_rsd.designer
    ,   vw_rsd.season_id
    ,   vw_rsd.season
    ,   vw_rsd.style_number
    ,   vw_rsd.colour
    ,   vw_rsd.designer_colour_code
    ,   vw_rsd.designer_colour
    ,   vw_rsd.name
    ,   vw_rsd.description
    ,   vw_rsd.size
    ,   vw_rsd.designer_size
    ,   vw_rsd.nap_size
    ,   vw_rsd.product_type
    ,   vw_rsd.delivery_item_id
    ,   vw_rsd.delivery_item_type
    ,   vw_rsd.delivery_date
    ,   vw_rsd.txt_delivery_date
    ,   vw_rsd.rma_request_detail_quantity
    ,   vw_rsd.fault_type
    ,   vw_rsd.fault_description
    ,   vw_rsd.rma_request_detail_type_id
    ,   vw_rsd.rma_request_detail_type
    ,   vw_rsd.rma_request_detail_status_id
    ,   vw_rsd.rma_request_detail_status
    ,   vw_rsd.rtv_stock_detail_quantity
    ,   vw_rsd."location"
    ,   vw_rsd.loc_dc
    ,   vw_rsd.loc_floor
    ,   vw_rsd.loc_zone
    ,   vw_rsd.loc_section
    ,   vw_rsd.loc_shelf
    ,   vw_rsd.location_type
    ,   vw_rsd.rtv_shipment_detail_id
    ,   vw_rsd.rtv_shipment_detail_quantity
    ,   vw_rsd.rtv_shipment_detail_status_id
    ,   vw_rsd.rtv_shipment_detail_status
    ,   COALESCE(vw_rsdrtr."unknown", (0)::numeric) AS result_total_unknown
    ,   COALESCE(vw_rsdrtr.credited, (0)::numeric) AS result_total_credited
    ,   COALESCE(vw_rsdrtr.repaired, (0)::numeric) AS result_total_repaired
    ,   COALESCE(vw_rsdrtr.replaced, (0)::numeric) AS result_total_replaced
    ,   COALESCE(vw_rsdrtr.dead, (0)::numeric) AS result_total_dead
    ,   COALESCE(vw_rsdrtr.stock_swapped, (0)::numeric) AS result_total_stock_swapped
    FROM (vw_rtv_shipment_details vw_rsd LEFT JOIN vw_rtv_shipment_detail_result_totals_row vw_rsdrtr ON ((vw_rsdrtr.rtv_shipment_detail_id = vw_rsd.rtv_shipment_detail_id)))
;


ALTER TABLE public.vw_rtv_shipment_details_with_results OWNER TO postgres;

--
-- Name: vw_rtv_shipment_details_with_results; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE vw_rtv_shipment_details_with_results FROM PUBLIC;
REVOKE ALL ON TABLE vw_rtv_shipment_details_with_results FROM postgres;
GRANT ALL ON TABLE vw_rtv_shipment_details_with_results TO postgres;
GRANT SELECT ON TABLE vw_rtv_shipment_details_with_results TO www;



/*************************
* vw_rtv_quantity_check
*************************/
--
-- Name: vw_rtv_quantity_check; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_rtv_quantity_check AS
    SELECT
        q.q_variant_id
    ,   q.q_location_id
    ,   q.q_location_type
    ,   q.q_sum_quantity
    ,   rq.rq_variant_id
    ,   rq.rq_location_id
    ,   rq.rq_location_type
    ,   rq.rq_sum_quantity
    FROM (
        (SELECT
            q.variant_id AS q_variant_id
        ,   q.location_id AS q_location_id
        ,   lt."type" AS q_location_type
        ,   sum(COALESCE(q.quantity, 0)) AS q_sum_quantity
        FROM ((quantity q JOIN "location" l ON ((q.location_id = l.id))) JOIN location_type lt ON ((l.type_id = lt.id)))
        WHERE ((lt."type")::text = ANY ((ARRAY['RTV Goods In'::character varying, 'RTV Workstation'::character varying, 'RTV Process'::character varying])::text[]))
        GROUP BY q.variant_id, q.location_id, lt."type") q
    FULL JOIN
        (SELECT
            rq.variant_id AS rq_variant_id
        ,   rq.location_id AS rq_location_id
        ,   lt."type" AS rq_location_type
        ,   sum(COALESCE(rq.quantity, 0)) AS rq_sum_quantity
        FROM ((rtv_quantity rq JOIN "location" l ON ((rq.location_id = l.id))) JOIN location_type lt ON ((l.type_id = lt.id)))
        GROUP BY rq.variant_id, rq.location_id, lt."type") rq
        ON (((q.q_variant_id = rq.rq_variant_id) AND (q.q_location_id = rq.rq_location_id)))
    )
    WHERE (((((q.q_variant_id IS NULL) OR (q.q_location_id IS NULL)) OR (rq.rq_variant_id IS NULL)) OR (rq.rq_location_id IS NULL)) OR (q.q_sum_quantity <> rq.rq_sum_quantity))
    ORDER BY q.q_variant_id, q.q_location_id
;


ALTER TABLE public.vw_rtv_quantity_check OWNER TO postgres;

--
-- Name: vw_rtv_quantity_check; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE vw_rtv_quantity_check FROM PUBLIC;
REVOKE ALL ON TABLE vw_rtv_quantity_check FROM postgres;
GRANT ALL ON TABLE vw_rtv_quantity_check TO postgres;
GRANT SELECT ON TABLE vw_rtv_quantity_check TO www;



/***************
* vw_list_rma
***************/
--
-- Name: vw_list_rma; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_list_rma AS
    SELECT
        vw_sp.stock_process_id
    ,   vw_sp.stock_process_type
    ,   vw_sp.stock_process_status_id
    ,   vw_sp.stock_process_status
    ,   vw_dd.delivery_item_id
    ,   vw_dd.delivery_item_type
    ,   vw_dd.delivery_item_status
    ,   vw_pv.variant_id
    ,   vw_pv.sku
    ,   vw_pv.designer_id
    ,   vw_pv.designer
    ,   vw_pv.style_number
    ,   vw_pv.colour
    ,   vw_pv.designer_colour_code
    ,   vw_pv.designer_colour
    ,   vw_pv.product_type
    ,   vw_dd.date AS delivery_date
    ,   to_char(vw_dd.date, 'DD-Mon-YYYY HH24:MI'::text) AS txt_delivery_date
    ,   vw_sp.quantity
    FROM ((((vw_stock_process vw_sp JOIN vw_delivery_details vw_dd ON ((vw_sp.delivery_item_id = vw_dd.delivery_item_id))) LEFT JOIN link_delivery_item__stock_order_item lnk_di_soi ON ((vw_dd.delivery_item_id = lnk_di_soi.delivery_item_id))) JOIN vw_stock_order_details vw_so ON ((lnk_di_soi.stock_order_item_id = vw_so.stock_order_item_id))) JOIN vw_product_variant vw_pv ON ((vw_so.variant_id = vw_pv.variant_id)))
    WHERE ((vw_sp.complete <> 1) AND (vw_sp.stock_process_type_id = 4))
    UNION
    SELECT
        vw_sp.stock_process_id
    ,   vw_sp.stock_process_type
    ,   vw_sp.stock_process_status_id
    ,   vw_sp.stock_process_status
    ,   vw_dd.delivery_item_id
    ,   vw_dd.delivery_item_type
    ,   vw_dd.delivery_item_status
    ,   vw_pv.variant_id
    ,   vw_pv.sku
    ,   vw_pv.designer_id
    ,   vw_pv.designer
    ,   vw_pv.style_number
    ,   vw_pv.colour
    ,   vw_pv.designer_colour_code
    ,   vw_pv.designer_colour
    ,   vw_pv.product_type
    ,   vw_dd.date AS delivery_date
    ,   to_char(vw_dd.date, 'DD-Mon-YYYY HH24:MI'::text) AS txt_delivery_date
    ,   vw_sp.quantity
    FROM ((((vw_stock_process vw_sp JOIN vw_delivery_details vw_dd ON ((vw_sp.delivery_item_id = vw_dd.delivery_item_id))) LEFT JOIN link_delivery_item__return_item lnk_di_ri ON ((vw_dd.delivery_item_id = lnk_di_ri.delivery_item_id))) JOIN vw_return_details vw_r ON ((lnk_di_ri.return_item_id = vw_r.return_item_id))) JOIN vw_product_variant vw_pv ON ((vw_r.variant_id = vw_pv.variant_id)))
    WHERE ((vw_sp.complete <> 1) AND (vw_sp.stock_process_type_id = 4))
;


ALTER TABLE public.vw_list_rma OWNER TO postgres;

--
-- Name: vw_list_rma; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE vw_list_rma FROM PUBLIC;
REVOKE ALL ON TABLE vw_list_rma FROM postgres;
GRANT ALL ON TABLE vw_list_rma TO postgres;
GRANT SELECT ON TABLE vw_list_rma TO www;


COMMIT;

/*** END ***/

