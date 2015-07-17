BEGIN;

CREATE OR REPLACE VIEW vw_product_variant AS
  SELECT
    pc.channel_id,
    v.product_id,
    p.world_id,
    w.world,
    p.classification_id,
    c.classification,
    p.product_type_id,
    pt.product_type,
    curr.currency AS wholesale_currency,
    pp.original_wholesale,
    p.designer_id,
    d.designer,
    p.colour_id,
    col.colour,
    pa.designer_colour_code,
    pa.designer_colour,
    p.style_number,
    p.season_id,
    s.season,
    pa.name,
    pa.description,
    pc.visible,
    pc.live,
    pc.staging,
    v.id AS variant_id,
    ((v.product_id)::text || '-'::text) || sku_padding(v.size_id) AS sku,
    v.legacy_sku,
    v.type_id AS variant_type_id,
    vt.type AS variant_type,
    v.size_id,
    sz.size,
    nsz.nap_size,
    v.designer_size_id,
    dsz.size AS designer_size
  FROM
    product p
    JOIN product_channel pc ON p.id = pc.product_id
    JOIN product_attribute pa ON p.id = pa.product_id
    JOIN price_purchase pp ON p.id = pp.product_id
    JOIN currency curr ON pp.wholesale_currency_id = curr.id
    JOIN designer d ON p.designer_id = d.id
    JOIN colour col ON p.colour_id = col.id
    JOIN world w ON p.world_id = w.id
    JOIN classification c ON p.classification_id = c.id
    JOIN product_type pt ON p.product_type_id = pt.id
    JOIN season s ON p.season_id = s.id
    JOIN variant v ON p.id = v.product_id
    JOIN variant_type vt ON v.type_id = vt.id
    LEFT JOIN size sz ON v.size_id = sz.id
    LEFT JOIN nap_size nsz ON v.nap_size_id = nsz.id
    LEFT JOIN size dsz ON v.designer_size_id = dsz.id
;
ALTER TABLE public.vw_product_variant OWNER TO postgres;
GRANT ALL ON TABLE vw_product_variant TO postgres;
GRANT ALL ON TABLE vw_product_variant TO www;
GRANT SELECT ON TABLE vw_product_variant TO perlydev;

CREATE OR REPLACE VIEW vw_sample_request_dets AS
  SELECT
    srd.sample_request_id,
    lpad((srd.sample_request_id)::text, 5, (0)::text) AS sample_request_ref,
    srd.id AS sample_request_det_id,
    srd.variant_id,
    srd.quantity,
    srd.sample_request_det_status_id,
    vsrdcs.status,
    vsrdcs.status_date,
    vsrdcs.status_operator,
    vsrdcs.loc_from,
    vsrdcs.loc_to,
    to_char(srd.date_return_due, 'DD-Mon-YYYY'::text) AS date_return_due,
    CASE WHEN (srd.date_return_due < ('now'::text)::timestamp without time zone) THEN true ELSE false END AS return_overdue,
    to_char(srd.date_returned, 'DD-Mon-YYYY HH24:MI'::text) AS date_returned,
    v.product_id,
    pa.name,
    pa.description,
    CAST(sku_padding(v.size_id) as text) AS size_id,
    sz.size,
    v.legacy_sku,
    d.designer
  FROM
    sample_request_det srd
    JOIN variant v ON srd.variant_id = v.id
    JOIN product_attribute pa ON v.product_id = pa.product_id
    JOIN product p ON p.id = pa.product_id
    JOIN size sz ON v.size_id = sz.id
    JOIN designer d ON p.designer_id = d.id
    LEFT JOIN vw_sample_request_det_current_status vsrdcs ON srd.id = vsrdcs.sample_request_det_id
;
ALTER TABLE public.vw_sample_request_dets OWNER TO postgres;
GRANT ALL ON TABLE vw_sample_request_dets TO postgres;
GRANT SELECT ON TABLE vw_sample_request_dets TO www;
GRANT SELECT ON TABLE vw_sample_request_dets TO perlydev;

COMMIT;
