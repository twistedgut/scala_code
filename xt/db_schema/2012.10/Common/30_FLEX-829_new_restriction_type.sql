
BEGIN;

--
-- FLEX-829 - Rename Fulfilment/Transit to Transit and introduce Dispatch
--

UPDATE shipping.delivery_date_restriction_type
    SET token = 'transit', name = 'Transit', description = 'The Carrier (e.g. DHL) will not Transit the Shipment on this date'
    WHERE token = 'fulfilment_or_transit'
;

INSERT INTO shipping.delivery_date_restriction_type
    (token, name, description)
    VALUES ('dispatch', 'Dispatch', 'The Warehouse can not Fulfil or Dispatch any more Shipments on this date')
;


COMMIT;
