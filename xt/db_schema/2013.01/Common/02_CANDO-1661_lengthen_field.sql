-- CANDO-1661: Lengthen the 'order_nr' field
--             on the 'hotlist_value' table

BEGIN WORK;

ALTER TABLE hotlist_value
    ALTER COLUMN order_nr TYPE CHARACTER VARYING(255)
;

COMMIT WORK;
