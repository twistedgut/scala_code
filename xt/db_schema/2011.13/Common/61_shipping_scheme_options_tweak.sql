BEGIN;


ALTER TABLE shipping.nap RENAME TO option_nap;
ALTER TABLE shipping.dhl RENAME TO option_dhl;
ALTER TABLE shipping.ups RENAME TO option_ups;



ALTER TABLE shipping.option ADD COLUMN note VARCHAR(255);
ALTER TABLE shipping.option ADD COLUMN product_name VARCHAR(255);


ALTER TABLE shipping.option_dhl ADD COLUMN voucher_fallback_code VARCHAR(10);
ALTER TABLE shipping.option_dhl ADD COLUMN routing_number INTEGER;
ALTER TABLE shipping.option_dhl ADD COLUMN service_type VARCHAR(10);
ALTER TABLE shipping.option_dhl ADD COLUMN description_of_goods VARCHAR(150);



COMMIT;
