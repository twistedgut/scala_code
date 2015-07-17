--
-- DC3 Only
--

-- CANDO-8003: Resets the 'ddu_terms_accepted' flag
--             on two Customer records

BEGIN WORK;

UPDATE customer
    SET ddu_terms_accepted = FALSE
WHERE is_customer_number IN (
    710264400,
    710267809
)
;

INSERT INTO customer_note ( customer_id, note_type_id, operator_id, date, note )
SELECT  c.id,
        nt.id,
        op.id,
        now(),
        'BAU (CANDO-8003): Have reset the Customer''s DDU Terms Acceptance flag'
FROM    customer c,
        note_type nt,
        operator op
WHERE   c.is_customer_number IN (
    710264400,
    710267809
)
AND     nt.code = 'CUS'
AND     op.name = 'Application'
;

COMMIT WORK;
