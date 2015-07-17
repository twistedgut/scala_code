-- #######################
-- ### The basic rules ###
-- #######################

-- All rules are based on the public.location.location field.

-- At dc1 a location ref is composed of the following parts:
-- 011A012B	-->  	011 A 012 B

-- 011	The floor on which stock is held
-- A	The block in which stock is held
-- 012	The coordinate within the block
-- B	The shelf of that coordinate

-- The floor and the block determine the storage type largely. 

-- So 
-- 011A002B

-- 011::  The 01 at the beginning is just padding . 1 (last digit) is
-- floor. There are 3. 

-- All stock on floors 012 and 013 are in totes (boxes) and therefore
-- contain either flat packed clothes, shoes , acces, bags, etc. 
-- Floor 011 is mostly hanging stock. 

-- ### The exceptions ###

-- select *,
--  CASE substr(location, 3, 1)      
--                 WHEN '1' THEN
--                                 case substr(location, 4, 1)
--                                                 WHEN 'X' THEN 'PRECIOUS THINGS'
--                                                 WHEN 'W' THEN 'AKWARD ITEMS'            --unit 5
--                                                 WHEN 'Y' THEN 'PRECIOUS THINGS'
--                                                 WHEN 'Z' THEN 'TOTES'
--                                                 ELSE 'hanging stock'
--                                 END
--                 WHEN '2' THEN
--                                 case substr(location, 4, 1)
--                                 when 'W' then 'AKWARD ITEMS'
--                                 else 'totes/boxes'
--                                 end
--                 WHEN '3' THEN 'totes/boxes'
--                 ELSE 'unknown/evil'
--                 END as x
-- from location


BEGIN;

UPDATE product p SET storage_type_id = CASE substr(l.location, 3, 1)
       WHEN '1' THEN
       	    CASE substr(location, 4, 1)
	    	 WHEN 'X' THEN 1              -- 'PRECIOUS THINGS'
                 WHEN 'W' THEN 4              -- 'AKWARD ITEMS'  on unit 5
                 WHEN 'Y' THEN 1              -- 'PRECIOUS THINGS'
                 WHEN 'Z' THEN 1              -- 'TOTES'
                 ELSE 2                       -- 'hanging stock'
            END
       WHEN '2' THEN
            CASE substr(location, 4, 1)
                 WHEN 'W' THEN 4              -- 'AKWARD ITEMS'
                 ELSE 1                       -- 'totes/boxes'
 	    END
       WHEN '3' THEN 1                        -- 'totes/boxes'
       ELSE 999                               -- 'unknown/evil'
       END 

       FROM quantity q
       LEFT JOIN variant v ON v.id = q.variant_id
       LEFT JOIN location l ON l.id = q.location_id
       LEFT JOIN channel c ON c.id = q.channel_id
       WHERE p.id = v.product_id
       AND substr(location, 1, 1) LIKE '0'
;

COMMIT;

-- xtracker=# select id,location,substr(location, 1, 1) from location WHERE substr(location, 1, 1) NOT LIKE '0';
--   id   |       location       | substr 
-- -------+----------------------+--------
--      1 | Transfer Pending     | T
--      2 | Quarantine           | Q
--      3 | Sample Room          | S
--      4 | Upload 1             | U
--      5 | Upload 2             | U
--      6 | Styling              | S
--      7 | Editorial            | E
--      8 | Gift                 | G
--      9 | Press                | P
--     10 | Faulty               | F
--     11 | Removed Quarantine   | R
--  30488 | GI                   | G
--  31025 | PRE-ORDER            | P
--  33885 | Nuno                 | N
--  31023 | RTV Workstation      | R
--  31024 | Pre-Shoot            | P
--  33860 | RTV Non-Faulty       | R
--  31034 | RTV Transfer Pending | R
--  31035 | Press Samples        | P
--  38225 | OGI                  | O
--  38226 | Nuno-OUT             | N
-- (21 rows)
