-- Populate location_zone_to_zone_mapping table for DC1 zones

BEGIN WORK;

-- OUTNET
INSERT INTO location_zone_to_zone_mapping VALUES (
    '011G','011G',(SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'OUTNET')
)
;
INSERT INTO location_zone_to_zone_mapping VALUES (
    '011H','011G',(SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'OUTNET')
)
;
INSERT INTO location_zone_to_zone_mapping VALUES (
    '011J','011G',(SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'OUTNET')
)
;

INSERT INTO location_zone_to_zone_mapping
SELECT  DISTINCT(SUBSTR(location,1,4)),'013A',c.id
FROM    location l
        JOIN channel c ON c.id = l.channel_id
        JOIN business b ON b.id = c.business_id
                                AND b.config_section = 'OUTNET'
WHERE   location LIKE '013%'
AND     location NOT LIKE '013F%'
;


-- NAP

INSERT INTO location_zone_to_zone_mapping VALUES (
    '011A','011A',(SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'NAP')
)
;
INSERT INTO location_zone_to_zone_mapping VALUES (
    '011B','011A',(SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'NAP')
)
;
INSERT INTO location_zone_to_zone_mapping VALUES (
    '011C','011A',(SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'NAP')
)
;
INSERT INTO location_zone_to_zone_mapping VALUES (
    '011D','011A',(SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'NAP')
)
;
INSERT INTO location_zone_to_zone_mapping VALUES (
    '011E','011A',(SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'NAP')
)
;
INSERT INTO location_zone_to_zone_mapping VALUES (
    '011F','011A',(SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'NAP')
)
;

INSERT INTO location_zone_to_zone_mapping
SELECT  DISTINCT(SUBSTR(location,1,4)),'012A',c.id
FROM    location l
        JOIN channel c ON c.id = l.channel_id
        JOIN business b ON b.id = c.business_id
                                AND b.config_section = 'NAP'
WHERE   location LIKE '012%'
;


-- Jewellery

INSERT INTO location_zone_to_zone_mapping VALUES (
    '011X','011X',(SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'OUTNET')
)
;
INSERT INTO location_zone_to_zone_mapping VALUES (
    '011X','011X',(SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'NAP')
)
;

COMMIT WORK;
