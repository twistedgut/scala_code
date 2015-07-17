-- CANDO-2676: Add some new Renumeration Reasons
--             and Update one of the existing ones

BEGIN WORK;

-- Insert some new Reasons
INSERT INTO renumeration_reason ( renumeration_reason_type_id, reason ) VALUES
( ( SELECT id FROM renumeration_reason_type WHERE type = 'Compensation' ), 'Size & fit complaint' ),
( ( SELECT id FROM renumeration_reason_type WHERE type = 'Compensation' ), 'Item packaged poorly' ),
( ( SELECT id FROM renumeration_reason_type WHERE type = 'Compensation' ), 'Price adjustment' ),
( ( SELECT id FROM renumeration_reason_type WHERE type = 'Compensation' ), 'Wrong order received' ),
( ( SELECT id FROM renumeration_reason_type WHERE type = 'Compensation' ), 'Style a Friend' ),
( ( SELECT id FROM renumeration_reason_type WHERE type = 'Compensation' ), 'Transfer of credit to/from account' )
;

-- Update an Existing Reason
UPDATE renumeration_reason
    SET reason  = 'Missing item/order'
WHERE   reason  = 'Missing item from order'
;

COMMIT WORK;
