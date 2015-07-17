-- Change the cart of the given sample request - it's currently on an Outnet
-- cart but due to a reversed channel transfer the PID should be on NAP - this
-- is causing problems when trying to return the item.

BEGIN;
    UPDATE sample_request_det
        SET sample_request_id = 9194
        WHERE sample_request_id = 5814
        AND   variant_id = (
            SELECT id FROM variant
            WHERE product_id = 424400
            AND size_id = 11
            AND type_id = ( SELECT id FROM variant_type WHERE type = 'Stock' )
        );

    -- We also need the original stock transfer's channel so the sample can be
    -- married up to its original shipment
    UPDATE stock_transfer
        SET channel_id = ( SELECT id FROM channel WHERE web_name = 'NAP-AM' )
        WHERE channel_id = ( SELECT id FROM channel WHERE web_name = 'OUTNET-AM' )
        AND   variant_id = (
            SELECT id FROM variant
            WHERE product_id = 424400
            AND size_id = 11
            AND type_id = ( SELECT id FROM variant_type WHERE type = 'Stock' )
        );
COMMIT;
