--
-- DC1 Only
--

-- CANDO-8690: Reset the DDU Flag for Outnet
--             Customer: 301700177

BEGIN WORK;

UPDATE  customer
    SET ddu_terms_accepted = FALSE
WHERE   is_customer_number = 301700177
AND     channel_id = (
    SELECT ch.id
    FROM   channel ch
           JOIN business b ON b.id = ch.business_id
                          AND b.config_section = 'OUTNET'
)
;

INSERT INTO customer_note ( customer_id, note_type_id, operator_id, date, note )
SELECT  c.id,
        nt.id,
        op.id,
        now(),
        'BAU (CANDO-8690): Have reset the Customer''s DDU Terms Acceptance flag'
FROM    customer c
        JOIN channel ch ON ch.id = c.channel_id
        JOIN business b ON b.id = ch.business_id
                       AND b.config_section = 'OUTNET',
        note_type nt,
        operator op
WHERE   c.is_customer_number = 301700177
AND     nt.code = 'CUS'
AND     op.name = 'Application'
;

COMMIT WORK;

