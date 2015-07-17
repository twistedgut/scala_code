--
-- CANDO-7942: Alter shipment_item table - add on_sale_flag column
--

BEGIN WORK;

ALTER TABLE shipment_item
    ADD COLUMN sale_flag_id INTEGER
    REFERENCES shipment_item_on_sale_flag(id);

COMMIT WORK;
