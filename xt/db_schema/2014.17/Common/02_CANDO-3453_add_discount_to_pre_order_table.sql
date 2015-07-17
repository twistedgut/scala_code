-- CANDO-3453: Add Discount fields to 'pre_order' table

BEGIN WORK;

ALTER TABLE pre_order
    ADD COLUMN applied_discount_percent     DECIMAL(5,2) DEFAULT 0.00 NOT NULL,
    ADD COLUMN applied_discount_operator_id INTEGER REFERENCES operator(id)
;

--
-- add 'original' columns to the 'pre_order_item' table
--
ALTER TABLE pre_order_item
    ADD COLUMN original_unit_price DECIMAL (10,3),
    ADD COLUMN original_tax DECIMAL (10,3),
    ADD COLUMN original_duty DECIMAL (10,3)
;

COMMENT ON COLUMN pre_order_item.original_unit_price IS 'This stores the Original Unit Price before any Discount was applied, if there is NO Discount then this will hold the same as ''unit_price''.';
COMMENT ON COLUMN pre_order_item.original_tax IS 'This stores the Original Tax before any Discount was applied, if there is NO Discount then this will hold the same as ''tax''. As Tax & Duties can be based on thresholds or flatrates then finding out the original when a Discount has been applied could be difficult hence the need to store the original value here.';
COMMENT ON COLUMN pre_order_item.original_duty IS 'This stores the Original Duty before any Discount was applied, if there is NO Discount then this will hold the same as ''duty''. As Tax & Duties can be based on thresholds or flatrates then finding out the original when a Discount has been applied could be difficult hence the need to store the original value here.';

-- update the now empty 'original' columns to be the same as their non-original columns
UPDATE  pre_order_item
    SET original_unit_price = unit_price,
        original_tax        = tax,
        original_duty       = duty
;

-- now apply 'not null' constraints to the new columns
ALTER TABLE pre_order_item
    ALTER COLUMN original_unit_price SET NOT NULL,
    ALTER COLUMN original_tax SET NOT NULL,
    ALTER COLUMN original_duty SET NOT NULL
;

COMMIT WORK;
