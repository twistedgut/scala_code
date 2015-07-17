BEGIN;

-- add channel_id and populate it
ALTER TABLE product.pws_sort_order ADD COLUMN channel_id integer REFERENCES public.channel(id);
UPDATE product.pws_sort_order SET channel_id = (SELECT id FROM channel WHERE name = 'NET-A-PORTER');
ALTER TABLE product.pws_sort_order ALTER COLUMN channel_id SET NOT NULL;


ALTER TABLE product.pws_sort_variable_weighting ADD COLUMN channel_id integer REFERENCES public.channel(id);
UPDATE product.pws_sort_variable_weighting SET channel_id = (SELECT id FROM channel WHERE name = 'NET-A-PORTER');
ALTER TABLE product.pws_sort_variable_weighting ALTER COLUMN channel_id SET NOT NULL;


ALTER TABLE product.pws_product_sort_variable_value ADD COLUMN channel_id integer REFERENCES public.channel(id);
UPDATE product.pws_product_sort_variable_value SET channel_id = (SELECT id FROM channel WHERE name = 'NET-A-PORTER');
ALTER TABLE product.pws_product_sort_variable_value ALTER COLUMN channel_id SET NOT NULL;

-- extend unique constraint to include channel id
alter table product.pws_product_sort_variable_value drop constraint pws_product_sort_variable_value_pkey;
alter table product.pws_product_sort_variable_value add constraint pws_product_sort_variable_value_pkey UNIQUE (product_id, pws_sort_variable_id, pws_sort_destination_id, channel_id);



ALTER TABLE product_channel ADD column pws_sort_adjust_id integer references product.pws_sort_adjust(id);
UPDATE product_channel SET pws_sort_adjust_id = (SELECT pws_sort_adjust_id FROM product_attribute WHERE product_id = product_channel.product_id);
ALTER TABLE product_attribute DROP COLUMN pws_sort_adjust_id;


-- fix dodgy values in stock summary table
update product.stock_summary set cancel_pending = 0 where cancel_pending is null;
alter table product.stock_summary alter column cancel_pending SET not null;

COMMIT;