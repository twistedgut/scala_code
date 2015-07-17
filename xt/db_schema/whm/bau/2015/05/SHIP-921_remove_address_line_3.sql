--SHIP-921 Address has invalid characters in address_line_3 which can't be
--edited through the interface, so set it to ''

BEGIN;
    UPDATE order_address oa
        SET address_line_3 = ''
        FROM shipment s
        WHERE s.shipment_address_id = oa.id
        AND s.id = 7173283
    ;
COMMIT;
