
BEGIN;

ALTER TABLE purchase_order RENAME TO old_purchase_order;

--create new tables
CREATE TABLE super_purchase_order (
    id integer NOT NULL,
    purchase_order_number character varying(255) NOT NULL,
    date timestamp without time zone DEFAULT ('now'::text)::timestamp(6) with time zone NOT NULL,
    currency_id integer,
    status_id integer DEFAULT 0,
    exchange_rate double precision,
    cancel boolean DEFAULT false,
    supplier_id integer,
    channel_id integer NOT NULL,
    type_id integer DEFAULT 0
);
ALTER TABLE public.super_purchase_order OWNER TO www;

CREATE TABLE purchase_order (
    comment text,
    designer_id integer,
    description character varying(255),
    season_id integer,
    act_id integer DEFAULT 0 NOT NULL,
    confirmed boolean DEFAULT false NOT NULL,
    confirmed_operator_id integer DEFAULT 0 NOT NULL,
    placed_by character varying(255)
) INHERITS (super_purchase_order);
ALTER TABLE public.purchase_order OWNER TO www;

CREATE TABLE voucher.purchase_order (
    created_by integer REFERENCES public.operator(id) DEFERRABLE NOT NULL
) INHERITS (super_purchase_order);
ALTER TABLE voucher.purchase_order OWNER TO www;

-- migrate data
    INSERT INTO purchase_order (id,
        purchase_order_number,
        date,                
        currency_id,        
        status_id,         
        exchange_rate,    
        cancel,          
        supplier_id,    
        channel_id,    
        type_id,      
        comment,     
        designer_id, 
        description,
        season_id, 
        act_id,   
        confirmed,
        confirmed_operator_id,
        placed_by           
    ) 
    SELECT 
    id,
    purchase_order_number,
    date,                
    currency_id,        
    status_id,         
    exchange_rate,    
    cancel,          
    supplier_id,    
    channel_id,    
    type_id,      
    comment,     
    designer_id, 
    description,
    season_id, 
    act_id,   
    confirmed,
    coalesce( confirmed_operator_id, 0 ),
    placed_by           
    FROM old_purchase_order;

    -- misc crap
    UPDATE purchase_order set cancel = 'f' where cancel is null;
    ALTER TABLE purchase_order alter COLUMN confirmed_operator_id drop not null;
    UPDATE purchase_order SET confirmed_operator_id = null where confirmed = false;
    ALTER TABLE purchase_order alter COLUMN confirmed_operator_id set default(null);
    ALTER TABLE  purchase_order ADD   FOREIGN KEY (confirmed_operator_id) REFERENCES operator(id) DEFERRABLE;
    ALTER TABLE  season_act ADD PRIMARY KEY (id);
    ALTER TABLE purchase_order ALTER COLUMN cancel SET NOT NULL;

    -- remove seq from old table
    ALTER TABLE old_purchase_order ALTER COLUMN id DROP DEFAULT;
    ALTER SEQUENCE purchase_order_id_seq OWNED BY NONE;

    -- add sequence, indexes and constraints to super_purchase_order
    ALTER TABLE super_purchase_order ALTER COLUMN id SET DEFAULT nextval('purchase_order_id_seq'::regclass);
    ALTER TABLE super_purchase_order ADD PRIMARY KEY (id);
    CREATE INDEX idx_super_purchase_order_currency_id ON super_purchase_order(currency_id);
    CREATE INDEX idx_super_purchase_order_status_id ON super_purchase_order(status_id);
    CREATE INDEX idx_super_purchase_order_type_id ON super_purchase_order(type_id);
    ALTER TABLE super_purchase_order
        ADD FOREIGN KEY (channel_id) REFERENCES channel(id) DEFERRABLE;
    ALTER TABLE super_purchase_order
        ADD FOREIGN KEY (status_id) REFERENCES purchase_order_status(id) DEFERRABLE;
    ALTER TABLE super_purchase_order
        ADD FOREIGN KEY (type_id) REFERENCES purchase_order_type(id) DEFERRABLE;

    -- add purchase_order PK, indexes and constraints
    ALTER TABLE public.purchase_order ADD PRIMARY KEY (id);
    CREATE INDEX idx_public_purchase_order_currency_id ON public.purchase_order(currency_id);
    CREATE INDEX idx_public_purchase_order_status_id ON public.purchase_order(status_id);
    CREATE INDEX idx_public_purchase_order_type_id ON public.purchase_order(type_id);
    ALTER TABLE purchase_order
        ADD FOREIGN KEY (designer_id) REFERENCES designer(id) DEFERRABLE;
    ALTER TABLE purchase_order
        ADD FOREIGN KEY (channel_id) REFERENCES channel(id) DEFERRABLE;
    ALTER TABLE purchase_order
        ADD FOREIGN KEY (status_id) REFERENCES purchase_order_status(id) DEFERRABLE;
    ALTER TABLE  purchase_order
        ADD FOREIGN KEY (type_id) REFERENCES purchase_order_type(id) DEFERRABLE;
    ALTER TABLE purchase_order
        ADD FOREIGN KEY (season_id) REFERENCES season(id) DEFERRABLE;
    ALTER TABLE purchase_order ADD FOREIGN KEY (act_id) REFERENCES season_act(id) DEFERRABLE;


    -- add voucher.purchase_order PK, indexes constraints
    ALTER TABLE voucher.purchase_order ADD PRIMARY KEY (id);
    CREATE INDEX idx_voucher_purchase_order_currency_id ON voucher.purchase_order(currency_id);
    CREATE INDEX idx_voucher_purchase_order_status_id ON voucher.purchase_order(status_id);
    CREATE INDEX idx_voucher_purchase_order_type_id ON voucher.purchase_order(type_id);
    ALTER TABLE voucher.purchase_order
        ADD FOREIGN KEY (channel_id) REFERENCES channel(id) DEFERRABLE;
    ALTER TABLE voucher.purchase_order
        ADD FOREIGN KEY (status_id) REFERENCES purchase_order_status(id) DEFERRABLE;
    ALTER TABLE voucher.purchase_order
        ADD FOREIGN KEY (type_id) REFERENCES purchase_order_type(id) DEFERRABLE;
    ALTER TABLE voucher.purchase_order
        ADD FOREIGN KEY (supplier_id) REFERENCES supplier(id) DEFERRABLE;


    -- constraint to be replaced by triggers
    ALTER TABLE  stock_order DROP CONSTRAINT stock_order_purchase_order_id_fkey;

    -- views need to be recreated.
    DROP VIEW njiv_stock_by_location_variant;
    DROP VIEW njiv_stock_by_location_outnet;
    DROP VIEW njiv_stock_by_location;
    DROP VIEW njiv_product_ordered_qty;
    DROP VIEW njiv_pws_log_stock_reporting;
    DROP VIEW njiv_master_product_attributes;
    DROP VIEW njiv_prod_orders ;

    -- add triggers as fk can't references super table
    CREATE OR REPLACE FUNCTION check_super_purchase_order_id()
    RETURNS TRIGGER AS $$
    BEGIN

    PERFORM id FROM super_purchase_order WHERE id = NEW.purchase_order_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION '% not found in super_purchase_order table', NEW.purchase_order_id;
    ELSE 
        RETURN NEW;
    END IF;
    END;
    $$
    LANGUAGE 'plpgsql';

    CREATE OR REPLACE FUNCTION check_delete_super_purchase_order()
    RETURNS TRIGGER AS $$
    BEGIN

    PERFORM purchase_order_id FROM stock_order WHERE purchase_order_id = OLD.id;

    IF FOUND THEN
        RAISE EXCEPTION 'update or delete on "%" violates foreign key constraint "%" references super_purchase_order (%)',
            TG_RELNAME, TG_NAME, OLD.id;
    END IF;
    END;
    $$
    LANGUAGE 'plpgsql';

    -- So ideally PO number should be unique, but for some POs in the past
    -- there are duplicates. So lets just have a contraint so we can't insert
    -- *new* duplicates
    CREATE OR REPLACE FUNCTION super_purchase_order_check_uniq_po_number()
    RETURNS TRIGGER AS $$
    BEGIN
    PERFORM id FROM super_purchase_order WHERE purchase_order_number = NEW.purchase_order_number;

    IF FOUND THEN
        RAISE EXCEPTION 'duplicate key value violates unique constraint "super_purchase_order_check_uniq_po_number"';
    ELSE 
        RETURN NEW;
    END IF;
    END;
    $$
    LANGUAGE 'plpgsql';

    CREATE TRIGGER check_spo_id BEFORE INSERT OR UPDATE ON stock_order FOR EACH ROW EXECUTE PROCEDURE check_super_purchase_order_id();
    CREATE TRIGGER check_spo_delete BEFORE DELETE ON super_purchase_order FOR EACH ROW EXECUTE PROCEDURE check_delete_super_purchase_order();
    CREATE TRIGGER check_spo_delete BEFORE DELETE ON purchase_order FOR EACH ROW EXECUTE PROCEDURE check_delete_super_purchase_order();

    -- Have to put the check trigger on both 'sub'tables here
    CREATE TRIGGER check_ppo_insert BEFORE INSERT ON public.purchase_order FOR EACH ROW EXECUTE PROCEDURE super_purchase_order_check_uniq_po_number();
    CREATE TRIGGER check_vpo_insert BEFORE INSERT ON voucher.purchase_order FOR EACH ROW EXECUTE PROCEDURE super_purchase_order_check_uniq_po_number();

    DROP TABLE old_purchase_order;

-- re-install MIS crack that I will probably never understand
    CREATE VIEW njiv_prod_orders AS
    SELECT so.product_id, sum(soi.quantity) AS qty FROM ((purchase_order po JOIN stock_order so ON ((so.purchase_order_id = po.id))) JOIN stock_order_item soi ON ((so.id = soi.stock_order_id))) WHERE ((so.type_id = 1) AND (po.channel_id = 1)) GROUP BY so.product_id;
    CREATE VIEW njiv_master_product_attributes AS
    SELECT p.id AS product_id, s.season, d.designer, dep.department, c.classification, pt.product_type, st.sub_type, pa.name, pdc.visible, pdc.live, p.style_number, p.legacy_sku, pa.description, col.colour, p.hs_code_id, cf.colour_filter AS mastercolor, (date_trunc('day'::text, pdc.upload_date))::date AS upload_date, sum(soi.quantity) AS ordered_quantity, pp.uk_landed_cost, round((pd.price * scr.conversion_rate), 3) AS original_selling_price, CASE WHEN (md.id IS NOT NULL) THEN round(((pd.price * scr.conversion_rate) * (((100)::numeric - md.percentage) / (100)::numeric)), 3) ELSE round((pd.price * scr.conversion_rate), 3) END AS selling_price, pac.category AS markdown_category, md.percentage FROM (((((((((((((((((((((product p LEFT JOIN price_default pd ON ((pd.product_id = p.id))) LEFT JOIN price_adjustment md ON ((((md.product_id = p.id) AND (md.date_start <= (now())::date)) AND (md.date_finish > (now())::date)))) LEFT JOIN price_adjustment_category pac ON ((md.category_id = pac.id))) LEFT JOIN sub_type st ON ((p.sub_type_id = st.id))) LEFT JOIN hs_code hs ON ((p.hs_code_id = hs.id))) LEFT JOIN product_type pt ON ((p.product_type_id = pt.id))) LEFT JOIN classification c ON ((p.classification_id = c.id))) LEFT JOIN designer d ON ((p.designer_id = d.id))) LEFT JOIN colour col ON ((p.colour_id = col.id))) LEFT JOIN filter_colour_mapping fcm ON ((p.colour_id = fcm.colour_id))) LEFT JOIN legacy_attributes la ON ((p.id = la.product_id))) JOIN season s ON ((p.season_id = s.id))) JOIN product_attribute pa ON ((p.id = pa.product_id))) JOIN product_department dep ON ((pa.product_department_id = dep.id))) JOIN price_purchase pp ON ((p.id = pp.product_id))) JOIN sales_conversion_rate scr ON ((pd.currency_id = scr.source_currency))) JOIN colour_filter cf ON ((fcm.filter_colour_id = cf.id))) LEFT JOIN product_channel pdc ON ((p.id = pdc.product_id))) LEFT JOIN stock_order so ON ((so.product_id = p.id))) LEFT JOIN stock_order_item soi ON ((soi.stock_order_id = so.id))) LEFT JOIN purchase_order po ON (((so.purchase_order_id = po.id) AND (po.channel_id = 1)))) WHERE ((((scr.destination_currency = 1) AND (('now'::text)::date > scr.date_start)) AND ((scr.date_finish IS NULL) OR (('now'::text)::date < scr.date_finish))) AND (pdc.channel_id = 1)) GROUP BY p.id, s.season, d.designer, dep.department, c.classification, pt.product_type, st.sub_type, pa.name, pdc.visible, pdc.live, p.style_number, p.legacy_sku, pa.description, col.colour, p.hs_code_id, cf.colour_filter, pdc.upload_date, pp.uk_landed_cost, round((pd.price * scr.conversion_rate), 3), CASE WHEN (md.id IS NOT NULL) THEN round(((pd.price * scr.conversion_rate) * (((100)::numeric - md.percentage) / (100)::numeric)), 3) ELSE round((pd.price * scr.conversion_rate), 3) END, pac.category, md.percentage;
    CREATE VIEW njiv_pws_log_stock_reporting AS
    SELECT p.id AS product_id, v.id AS variant_id, pa.action, pw.pws_action_id, pw.quantity, date_trunc('day'::text, pw.date) AS date, date_trunc('day'::text, fso.date) AS first_sold_out_date, CASE WHEN ((((((pw.pws_action_id = 11) OR (pw.pws_action_id = 10)) OR (pw.pws_action_id = 7)) OR (pw.pws_action_id = 8)) OR (pw.pws_action_id = 9)) OR (pw.pws_action_id = 12)) THEN (pw.quantity)::bigint ELSE (0)::bigint END AS uploadunits, CASE WHEN ((((pw.pws_action_id = 2) OR (pw.pws_action_id = 3)) OR (pw.pws_action_id = 4)) OR (pw.pws_action_id = 5)) THEN ((pw.quantity * (-1)))::bigint ELSE (0)::bigint END AS salesunits, CASE WHEN ((((((((pw.pws_action_id = 11) OR (pw.pws_action_id = 10)) OR (pw.pws_action_id = 7)) OR (pw.pws_action_id = 1)) OR (pw.pws_action_id = 8)) OR (pw.pws_action_id = 9)) OR (pw.pws_action_id = 12)) OR (pw.pws_action_id = 13)) THEN (pw.quantity)::bigint ELSE (0)::bigint END AS uploadamendedunits, CASE WHEN ((((((pw.pws_action_id = 11) OR (pw.pws_action_id = 10)) OR (pw.pws_action_id = 7)) OR (pw.pws_action_id = 8)) OR (pw.pws_action_id = 9)) OR (pw.pws_action_id = 12)) THEN ((((pw.quantity)::bigint)::numeric)::double precision * (mpa.uk_landed_cost)::double precision) ELSE (((0)::bigint)::numeric)::double precision END AS uploadcost, CASE WHEN ((((pw.pws_action_id = 2) OR (pw.pws_action_id = 3)) OR (pw.pws_action_id = 4)) OR (pw.pws_action_id = 5)) THEN (((((pw.quantity * (-1)))::bigint)::numeric)::double precision * (mpa.uk_landed_cost)::double precision) ELSE (((0)::bigint)::numeric)::double precision END AS salescost, CASE WHEN ((((((((pw.pws_action_id = 11) OR (pw.pws_action_id = 10)) OR (pw.pws_action_id = 7)) OR (pw.pws_action_id = 1)) OR (pw.pws_action_id = 8)) OR (pw.pws_action_id = 9)) OR (pw.pws_action_id = 12)) OR (pw.pws_action_id = 13)) THEN ((((pw.quantity)::bigint)::numeric)::double precision * (mpa.uk_landed_cost)::double precision) ELSE (((0)::bigint)::numeric)::double precision END AS uploadamendedcost, mpa.season, mpa.designer, mpa.classification, mpa.product_type, mpa.sub_type, mpa.name, mpa.visible, mpa.live, mpa.style_number, mpa.legacy_sku, mpa.description, mpa.colour, mpa.mastercolor, mpa.original_selling_price, mpa.uk_landed_cost, mpa.selling_price, mpa.upload_date FROM (((((product p LEFT JOIN njiv_1st_sold_out fso ON ((p.id = fso.product_id))) JOIN njiv_master_product_attributes mpa ON ((p.id = mpa.product_id))) JOIN variant v ON ((p.id = v.product_id))) JOIN log_pws_stock pw ON (((v.id = pw.variant_id) AND (pw.channel_id = 1)))) JOIN pws_action pa ON ((pw.pws_action_id = pa.id)));

    CREATE VIEW njiv_product_ordered_qty AS
    SELECT po.product_id, po.qty AS ordered_quantity, round(((po.qty)::numeric * pp.uk_landed_cost), 2) AS cost_ordered FROM (njiv_prod_orders po JOIN price_purchase pp ON ((po.product_id = pp.product_id)));

    CREATE VIEW njiv_stock_by_location AS
    SELECT lt.type, p.id AS product_id, sum(q.quantity) AS quantity FROM ((((quantity q JOIN variant v ON ((q.variant_id = v.id))) JOIN product p ON ((v.product_id = p.id))) JOIN location loc ON ((q.location_id = loc.id))) JOIN location_type lt ON ((loc.type_id = lt.id))) WHERE (q.channel_id = 1) GROUP BY lt.type, p.id UNION SELECT 'GoodsIn' AS type, v.product_id, sum(sp.quantity) AS quantity FROM ((((((stock_process sp JOIN delivery_item di ON ((sp.delivery_item_id = di.id))) JOIN link_delivery_item__stock_order_item ldi_soi ON ((di.id = ldi_soi.delivery_item_id))) JOIN stock_order_item soi ON ((ldi_soi.stock_order_item_id = soi.id))) JOIN stock_order so ON ((so.id = soi.stock_order_id))) JOIN purchase_order po ON (((so.purchase_order_id = po.id) AND (po.channel_id = 1)))) JOIN variant v ON ((soi.variant_id = v.id))) WHERE ((di.cancel = false) AND (di.status_id < 4)) GROUP BY v.product_id;
    CREATE VIEW njiv_stock_by_location_outnet AS
    SELECT lt.type, p.id AS product_id, sum(q.quantity) AS quantity FROM ((((quantity q JOIN variant v ON ((q.variant_id = v.id))) JOIN product p ON ((v.product_id = p.id))) JOIN location loc ON ((q.location_id = loc.id))) JOIN location_type lt ON ((loc.type_id = lt.id))) WHERE (q.channel_id = 3) GROUP BY lt.type, p.id UNION SELECT 'GoodsIn' AS type, v.product_id, sum(sp.quantity) AS quantity FROM ((((((stock_process sp JOIN delivery_item di ON ((sp.delivery_item_id = di.id))) JOIN link_delivery_item__stock_order_item ldi_soi ON ((di.id = ldi_soi.delivery_item_id))) JOIN stock_order_item soi ON ((ldi_soi.stock_order_item_id = soi.id))) JOIN stock_order so ON ((so.id = soi.stock_order_id))) JOIN purchase_order po ON (((so.purchase_order_id = po.id) AND (po.channel_id = 3)))) JOIN variant v ON ((soi.variant_id = v.id))) WHERE ((di.cancel = false) AND (di.status_id < 4)) GROUP BY v.product_id;
    CREATE VIEW njiv_stock_by_location_variant AS
    SELECT lt.type, p.id AS product_id, v.id AS variant_id, sum(q.quantity) AS quantity FROM ((((quantity q JOIN variant v ON ((q.variant_id = v.id))) JOIN product p ON ((v.product_id = p.id))) JOIN location loc ON ((q.location_id = loc.id))) JOIN location_type lt ON ((loc.type_id = lt.id))) WHERE (q.channel_id = 1) GROUP BY lt.type, p.id, v.id UNION SELECT 'GoodsIn' AS type, v.product_id, v.id AS variant_id, sum(sp.quantity) AS quantity FROM ((((((stock_process sp JOIN delivery_item di ON ((sp.delivery_item_id = di.id))) JOIN link_delivery_item__stock_order_item ldi_soi ON ((di.id = ldi_soi.delivery_item_id))) JOIN stock_order_item soi ON ((ldi_soi.stock_order_item_id = soi.id))) JOIN stock_order so ON ((so.id = soi.stock_order_id))) JOIN purchase_order po ON (((so.purchase_order_id = po.id) AND (po.channel_id = 1)))) JOIN variant v ON ((soi.variant_id = v.id))) WHERE ((di.cancel = false) AND (di.status_id < 4)) GROUP BY v.product_id, v.id;
COMMIT;
