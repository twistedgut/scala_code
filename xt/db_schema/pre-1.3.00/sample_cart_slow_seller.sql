
/*****************************************************
* Sample Cart - Slow-Seller
*
* Add 'Slow-Seller' sample request type and location 
******************************************************/


BEGIN;

INSERT INTO location (location, type_id) VALUES ('Slow-Seller', (SELECT id FROM location_type WHERE type = 'Sample'));
INSERT INTO sample_request_type (code, type, bookout_location_id) VALUES ('slw', 'Slow-Seller', (SELECT id FROM location WHERE location = 'Slow-Seller'));

COMMIT;
