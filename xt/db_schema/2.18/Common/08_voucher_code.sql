BEGIN;

CREATE TABLE voucher.code (
    id serial PRIMARY KEY,
	voucher_product_id integer REFERENCES voucher.product(id) DEFERRABLE NOT NULL,
	code text NOT NULL,
	assigned timestamp with time zone,
	created timestamp with time zone default now() NOT NULL,
	delivery_item_id integer REFERENCES public.delivery_item(id) DEFERRABLE 
);
CREATE UNIQUE INDEX voucher_code_unique ON voucher.code (code);
ALTER TABLE voucher.code OWNER TO www;

ALTER TABLE shipment_item ADD COLUMN voucher_code_id integer REFERENCES voucher.code(id) DEFERRABLE;
ALTER TABLE shipment_item ALTER COLUMN variant_id DROP NOT NULL;
ALTER TABLE shipment_item ADD CONSTRAINT linked_to_variant_or_voucher_code CHECK(variant_id ::int::boolean != voucher_code_id ::int::boolean);

-- update triggers

CREATE OR REPLACE FUNCTION canc_pending_quantity_trigger()
RETURNS TRIGGER AS $$
DECLARE
	 v_shipment_item_id       INTEGER := NULL;
	 v_old_status_id  INTEGER := NULL;
	 v_new_status_id  INTEGER := NULL;
	 v_quantity               INTEGER := NULL;
	 v_product_id     INTEGER := NULL;
	 v_channel_id    INTEGER := NULL;
BEGIN
	-- stock_summary not updated for vouchers
	IF (new.voucher_code_id is NULL) THEN  
		 IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
			 v_shipment_item_id        := NEW.id;
		 ELSE
			 v_shipment_item_id        := OLD.id;
		 END IF;

		 IF (TG_OP = 'INSERT') THEN
			 v_old_status_id               := NEW.shipment_item_status_id;
			 v_new_status_id               := NEW.shipment_item_status_id;
		 ELSIF (TG_OP = 'UPDATE') THEN
			 v_old_status_id               := OLD.shipment_item_status_id;
			 v_new_status_id               := NEW.shipment_item_status_id;
		 ELSE
			 v_old_status_id               := OLD.shipment_item_status_id;
			 v_new_status_id               := OLD.shipment_item_status_id;
		 END IF;

		 IF (v_old_status_id = 10 OR v_new_status_id = 10) THEN

			 SELECT INTO v_product_id, v_quantity, v_channel_id v.product_id, count( si.* ), o.channel_id
				FROM variant v, cancelled_item ci, shipment_item si, link_orders__shipment los, orders o
				WHERE v.product_id = (SELECT product_id FROM variant WHERE id = 
					(SELECT variant_id FROM shipment_item WHERE id = v_shipment_item_id))
				AND v.id = si.variant_id
				AND si.shipment_item_status_id = 10
				AND si.id = ci.shipment_item_id
				AND ci.adjusted = 0
				AND si.shipment_id = los.shipment_id
				AND los.orders_id = o.id
				GROUP by v.product_id, o.channel_id;

			UPDATE product.stock_summary SET cancel_pending = v_quantity, 
				last_updated = current_timestamp WHERE product_id = v_product_id AND channel_id = v_channel_id;
		 END IF;
	END IF;
	 RETURN NEW;
END;	
$$
LANGUAGE 'plpgsql';

CREATE OR REPLACE FUNCTION prepick_quantity_trigger()
RETURNS TRIGGER AS $$
DECLARE
	v_variant_id     INTEGER := NULL;
	v_quantity               INTEGER := NULL;
	v_product_id     INTEGER := NULL;
	v_channel_id    INTEGER := NULL;
BEGIN

	-- stock_summary not updated for vouchers
	IF (new.voucher_code_id is NULL) THEN  
		IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
			v_variant_id        := NEW.variant_id;
		ELSE
			v_variant_id        := OLD.variant_id;
		END IF;

		SELECT INTO v_product_id, v_quantity, v_channel_id product_id, sum(total), channel_id FROM
			   (
			   SELECT v.product_id, count( si.* ) as total, o.channel_id
				   FROM variant v
						LEFT JOIN shipment_item si ON v.id = si.variant_id AND si.shipment_item_status_id < 3
						LEFT JOIN link_orders__shipment los ON si.shipment_id = los.shipment_id
						LEFT JOIN orders o ON los.orders_id = o.id
			   WHERE v.product_id = (SELECT product_id FROM variant WHERE id = v_variant_id)
				   GROUP BY v.product_id, o.channel_id
			   UNION ALL
			   SELECT v.product_id, count( si.* ) as total, st.channel_id
				   FROM variant v
						LEFT JOIN shipment_item si ON v.id = si.variant_id AND si.shipment_item_status_id < 3
						LEFT JOIN link_stock_transfer__shipment los ON si.shipment_id = los.shipment_id
						LEFT JOIN stock_transfer st ON los.stock_transfer_id = st.id
			   WHERE v.product_id = (SELECT product_id FROM variant WHERE id = v_variant_id)
				   GROUP BY v.product_id, st.channel_id
			   ) AS bob
				GROUP BY product_id, channel_id
		;

		IF v_quantity IS NULL THEN
			v_quantity := 0;
		END IF;

		IF v_channel_id IS NULL THEN
			UPDATE product.stock_summary SET pre_pick = v_quantity, last_updated = current_timestamp WHERE product_id = v_product_id;
		ELSE 
			UPDATE product.stock_summary SET pre_pick = v_quantity, last_updated = current_timestamp WHERE product_id = v_product_id AND channel_id = v_channel_id;
		END IF; 
	END IF; 

	RETURN NEW;
END;
$$
LANGUAGE 'plpgsql';

COMMIT;
