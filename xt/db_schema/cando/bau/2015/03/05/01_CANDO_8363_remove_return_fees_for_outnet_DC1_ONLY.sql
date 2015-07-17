--  DC1-ONLY

-- CANDO-8363: Remove Returns Fee for OUTNET

BEGIN WORK;

-- Delete return charge for outnet
DELETE FROM returns_charge
WHERE  channel_id = (
    SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'OUTNET'
);


UPDATE shipping_charge
SET is_return_shipment_free=true
WHERE
    channel_id = (
        SELECT c.id FROM channel c JOIN business b ON b.id = c.business_id AND b.config_section = 'OUTNET'
    )
AND
    is_return_shipment_free=false
;

COMMIT WORK;
