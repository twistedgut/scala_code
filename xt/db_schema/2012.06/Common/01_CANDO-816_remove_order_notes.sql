-- CANDO-816: Removes all of the 'order_note' records which
--            have been generated for this Bug and are no
--            longer required.

BEGIN WORK;

DELETE FROM order_note
WHERE   operator_id = (
            SELECT  id
            FROM    operator
            WHERE   name = 'Application'
        )
AND     note_type_id = (
            SELECT  id
            FROM    note_type
            WHERE   description = 'Returns'
        )
AND     note LIKE 'Unexpected invoice type: 3 at /opt/xt%'
;

COMMIT WORK;
