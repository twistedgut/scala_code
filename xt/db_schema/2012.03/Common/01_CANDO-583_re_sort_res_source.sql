-- CANDO-583: Re-Sort the 'Stock Discrepancy' Reservation
--            Source so that it appears underneath 'Unknown'

BEGIN WORK;

UPDATE reservation_source
    SET sort_order  = (
                SELECT  ( MAX(sort_order) + 1 )
                FROM    reservation_source
                WHERE   sort_order < 999        -- less than 'Unknown'
            )
WHERE   source = 'Stock Discrepancy'
;

COMMIT WORK;
