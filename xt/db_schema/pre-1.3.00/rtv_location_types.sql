/******************************************************
* Return to Vendor
* 
* Location types required by RTV
******************************************************/

BEGIN;

SELECT setval('location_type_id_seq', (SELECT max(id) FROM location_type));

INSERT INTO location_type (type) VALUES ('RTV Goods In');
INSERT INTO location_type (type) VALUES ('RTV Workstation');
INSERT INTO location_type (type) VALUES ('RTV Process');

COMMIT;
