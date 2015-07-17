--
-- CANDO-2192: Make the order importer put orders with non ASCII or non Latin-1
--             characters in the shipping address on shipping hold.
--

BEGIN WORK;

INSERT INTO shipment_hold_reason (reason) VALUES
    ('Invalid Characters')
;

COMMIT WORK;
