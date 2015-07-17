--
-- DCA-3291 - Add extra allocation statuses for GOH allocations
--
BEGIN;

INSERT INTO allocation_status (status, description) VALUES
    ( 'preparing', 'PRL has been asked to prepare the allocation' ),
    ( 'prepared', 'PRL has said allocation is prepared' ),
    ( 'delivering', 'PRL has been asked to deliver the allocation' ),
    ( 'delivered', 'PRL has said allocation is delivered' )
;

COMMIT;

