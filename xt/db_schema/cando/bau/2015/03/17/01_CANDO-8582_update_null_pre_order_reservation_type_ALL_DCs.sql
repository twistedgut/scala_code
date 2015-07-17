-- All DCs

-- CANDO-8582: Update all Incomplete Pre-Order's 'reservation_type_id' field
--             to 'Pre-order Pending' so long as the field is NULL

BEGIN WORK;

UPDATE  pre_order
    SET reservation_type_id = (
        SELECT  id
        FROM    reservation_type
        WHERE   type = 'Pre-order Pending'
    )
WHERE   reservation_type_id IS NULL
AND     pre_order_status_id = (
    SELECT  id
    FROM    pre_order_status
    WHERE   status = 'Incomplete'
)
;

COMMIT WORK;
