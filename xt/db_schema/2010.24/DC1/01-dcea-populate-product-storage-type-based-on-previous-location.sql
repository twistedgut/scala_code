-- This script is based on db_schema/2010.23/DC1/02-dcea-populate-product-storage-type-id.sql

-- We're populating the product storage_type_id with values based on previous location of 
-- currently unavailable stock.

BEGIN;

UPDATE product p SET storage_type_id = CASE substr(old_location, 3, 1)
       WHEN '1' THEN
       	    CASE substr(old_location, 4, 1)
	    	 WHEN 'X' THEN 1              -- 'PRECIOUS THINGS'
                 WHEN 'W' THEN 4              -- 'AKWARD ITEMS'  on unit 5
                 WHEN 'Y' THEN 1              -- 'PRECIOUS THINGS'
                 WHEN 'Z' THEN 1              -- 'TOTES'
                 ELSE 2                       -- 'hanging stock'
            END
       WHEN '2' THEN
            CASE substr(old_location, 4, 1)
                 WHEN 'W' THEN 4              -- 'AKWARD ITEMS'
                 ELSE 1                       -- 'totes/boxes'
 	    END
       WHEN '3' THEN 1                        -- 'totes/boxes'
       ELSE 999                               -- 'unknown/evil'
       END 
       FROM (
       	    SELECT 
       DISTINCT ON (p.id) p.id as pid,
       v.id as vid,
       q.quantity,
       l.location,
       l2.location AS old_location,
       ll.date
       FROM product p
       LEFT JOIN variant v ON v.product_id = p.id
       LEFT JOIN quantity q ON v.id = q.variant_id
       LEFT JOIN location l ON l.id = q.location_id
       LEFT JOIN log_location ll ON ll.variant_id = v.id
       LEFT JOIN location l2 ON l2.id = ll.location_id
       WHERE q.quantity IS NULL                    -- Selecting on the currently non-existent ones
       AND p.storage_type_id IS NULL		   -- Don't select products already populated
       AND substr(l2.location, 1, 1) LIKE '0'
       ) AS loppl -- List Of Previous Product Location
       WHERE p.id = loppl.pid
;

COMMIT;









