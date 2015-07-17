-- Populate location_zone_to_zone_mapping table for DC2 zones

BEGIN WORK;

-- OUTNET

INSERT INTO location_zone_to_zone_mapping VALUES ( '021Q','021Q',(SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'OUTNET'));
INSERT INTO location_zone_to_zone_mapping VALUES ( '021P','021Q',(SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'OUTNET'));
INSERT INTO location_zone_to_zone_mapping VALUES ( '021O','021Q',(SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'OUTNET'));
INSERT INTO location_zone_to_zone_mapping VALUES ( '021N','021Q',(SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'OUTNET'));

INSERT INTO location_zone_to_zone_mapping VALUES ( '021C','021D',(SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'OUTNET'));
INSERT INTO location_zone_to_zone_mapping VALUES ( '021D','021D',(SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'OUTNET'));

INSERT INTO location_zone_to_zone_mapping VALUES ( '021A','021A',(SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'OUTNET'));
INSERT INTO location_zone_to_zone_mapping VALUES ( '021B','021A',(SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'OUTNET'));

-- NAP

INSERT INTO location_zone_to_zone_mapping VALUES ( '021X','021W',(SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'NAP'));
INSERT INTO location_zone_to_zone_mapping VALUES ( '021W','021W',(SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'NAP'));
INSERT INTO location_zone_to_zone_mapping VALUES ( '021V','021W',(SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'NAP'));
INSERT INTO location_zone_to_zone_mapping VALUES ( '021U','021W',(SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'NAP'));
INSERT INTO location_zone_to_zone_mapping VALUES ( '021T','021W',(SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'NAP'));
INSERT INTO location_zone_to_zone_mapping VALUES ( '021S','021W',(SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'NAP'));
INSERT INTO location_zone_to_zone_mapping VALUES ( '021R','021W',(SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'NAP'));

INSERT INTO location_zone_to_zone_mapping VALUES ( '021L','021M',(SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'NAP'));
INSERT INTO location_zone_to_zone_mapping VALUES ( '021M','021M',(SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'NAP'));
INSERT INTO location_zone_to_zone_mapping VALUES ( '021K','021M',(SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'NAP'));
INSERT INTO location_zone_to_zone_mapping VALUES ( '021J','021M',(SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'NAP'));

INSERT INTO location_zone_to_zone_mapping VALUES ( '021E','021H',(SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'NAP'));
INSERT INTO location_zone_to_zone_mapping VALUES ( '021F','021H',(SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'NAP'));
INSERT INTO location_zone_to_zone_mapping VALUES ( '021G','021H',(SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'NAP'));
INSERT INTO location_zone_to_zone_mapping VALUES ( '021H','021H',(SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'NAP'));
INSERT INTO location_zone_to_zone_mapping VALUES ( '021I','021H',(SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'NAP'));

COMMIT WORK;
