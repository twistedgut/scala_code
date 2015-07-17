BEGIN;

-- New column to store the date when the order was created in xt

alter table orders add column order_created_in_xt_date timestamp with time zone;

-- Set existing dates in this new column to the date when order was placed on live website

update orders set order_created_in_xt_date = date;

ALTER TABLE orders
    ALTER COLUMN order_created_in_xt_date SET NOT NULL,
    ALTER COLUMN order_created_in_xt_date SET DEFAULT now();

COMMIT;
