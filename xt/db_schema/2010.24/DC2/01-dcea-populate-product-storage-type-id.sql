-- Based on Locations by Storage Type.xls
-- 
-- Zone	Storage Type	Locations			
-- A	Flat				
-- B	Flat				
-- C	Flat				
-- D	Flat				
-- E	Flat				
-- F	Flat				
-- G	Flat				
-- H	Flat				
-- I	Flat				
-- J	Flat				
-- K	Flat				
-- L	Flat	0021-0028 - All levels			
-- L	Hanging	0001-0017 - All levels			
-- M	Flat				
-- N	Hanging				
-- O	Hanging				
-- P	Hanging				
-- Q	Hanging				
-- R	Hanging				
-- S	Hanging				
-- T	Hanging				
-- U	Hanging				
-- V	Hanging				
-- W	Hanging				
-- X	Hanging	0001 - 0020 and 0100 - 0129 - All levels			
-- X	Flat	0021-0041 - All levels			
-- Y	Flat (High Value / Security Cage)				
-- Z 					

-- WARNING
-- From a perspective of easiness the comments containing evil where once considered edge cases where there was no rules defined 
-- they have since been flattened to 1 for simplicity and we'll deal with the weird cases later if we have too.

BEGIN;

CREATE OR REPLACE FUNCTION wharehouse_rules(location varchar) returns integer as $$
DECLARE 
	ret integer;
       BEGIN
	SELECT CASE SUBSTR(location, 4, 7) 
       	    WHEN SUBSTRING(SUBSTR(location, 4, 7),'[A-KM]-.*') THEN 1                 -- 'A to K or M' Flat
       	    WHEN SUBSTRING(SUBSTR(location, 4, 7),'[N-W]-.*') THEN 2                  -- 'N to W'      Hanging
       	    WHEN SUBSTRING(SUBSTR(location, 4, 7),'L-.*') THEN 
	    	 CASE WHEN SUBSTR(location, 6, 4)::integer BETWEEN 1 AND 17 THEN 2    -- 'L 0001-0017 Hanging'
		      WHEN SUBSTR(location, 6, 4)::integer BETWEEN 21 AND 28 THEN 1   -- 'L 0021-0028 Flat'
		      ELSE 1                                                       -- 'L is evil, as in not defined'
            	 END 
       	    WHEN SUBSTRING(SUBSTR(location, 4, 7),'X-.*') THEN 
	    	 CASE WHEN SUBSTR(location, 6, 4)::integer BETWEEN 1 AND 20 THEN 2    -- 'X 0001-0020' Hanging
		      WHEN SUBSTR(location, 6, 4)::integer BETWEEN 100 AND 129 THEN 2 -- 'X 0100-0129' Hanging
		      WHEN SUBSTR(location, 6, 4)::integer BETWEEN 21 AND 41 THEN 1   -- 'X 0021-0041 Flat'
		      ELSE 1                                                       -- 'X is evil, as in not defined'
              	 END 
       	    WHEN SUBSTRING(SUBSTR(location, 4, 7),'Y-.*') THEN 1                      -- 'Y Flat (High Value / Security Cage)'
       	    WHEN SUBSTRING(SUBSTR(location, 4, 7),'Z-.*') THEN 1                   -- 'Z is evil, as in not defined'
	    ELSE 1                                                                 -- 'just pure evil, we must have missed something'
	    INTO ret
       END;
       
       RETURN ret;
      END;
$$ LANGUAGE plpgsql;

-- Updating storage_location for known product quantity 
UPDATE product p SET storage_type_id = wharehouse_rules(l.location)
       FROM quantity q
       LEFT JOIN variant v ON v.id = q.variant_id
       LEFT JOIN location l ON l.id = q.location_id
       WHERE p.id = v.product_id
       AND substr(l.location, 1, 1) LIKE '0'
;


-- Now run the same query but populate products for which we don't have stock anymore.

UPDATE product p SET storage_type_id = wharehouse_rules(loppl.old_location)
       FROM (
       -- What we had at some point 
       SELECT 
       	      DISTINCT ON (p2.id) p2.id as pid,
              v.id as vid,
       	      l2.location as old_location
       	      FROM product p2
       	      LEFT JOIN variant v ON v.product_id = p2.id
       	      LEFT JOIN quantity q ON v.id = q.variant_id
       	      LEFT JOIN location l ON l.id = q.location_id
       	      LEFT JOIN log_location ll ON ll.variant_id = v.id
       	      LEFT JOIN location l2 ON l2.id = ll.location_id
       	      WHERE q.quantity IS NULL                    -- Selecting on the currently non-existent ones
       	      AND p2.storage_type_id IS NULL		  -- Don't select products already populated
       	      AND substr(l2.location, 1, 1) LIKE '0'
       ) as loppl                                         -- List Of Previous Product Location
       WHERE p.id = loppl.pid
;

COMMIT;
