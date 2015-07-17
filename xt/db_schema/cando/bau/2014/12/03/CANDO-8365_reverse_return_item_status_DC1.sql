--
-- DC1 Only
--
-- CANDO-8365: Set a Return Item Status back to 'Booked In'
--

BEGIN WORK;

UPDATE  return_item
    SET return_item_status_id = (
        SELECT  id
        FROM    return_item_status
        WHERE   status = 'Booked In'
    )
WHERE   return_id = (
    SELECT  id
    FROM    return
    WHERE   rma_number = 'R6285574-2340884'
)
;

INSERT INTO return_item_status_log (return_item_id,return_item_status_id,operator_id) VALUES (
    (
        SELECT  id
        FROM    return_item
        WHERE   return_id = (
            SELECT  id
            FROM    return
            WHERE   rma_number = 'R6285574-2340884'
        )
    ),
    (
        SELECT  id
        FROM    return_item_status
        WHERE   status = 'Booked In'
    ),
    (
        SELECT  id
        FROM    operator
        WHERE   name = 'Application'
    )
)
;

INSERT INTO return_note (return_id,note_type_id,operator_id,date,note) VALUES (
    (
        SELECT  id
        FROM    return
        WHERE   rma_number = 'R6285574-2340884'
    ),
    (
        SELECT  id
        FROM    note_type
        WHERE   description = 'Returns'
    ),
    (
        SELECT  id
        FROM    operator
        WHERE   name = 'Application'
    ),
    now(),
    'BAU (CANDO-8365): Set Return Item Status of SKU ''502155-014'' back to ''Booked In'' so that the Item can be Reversed & then Cancelled.'
)
;

COMMIT WORK;
