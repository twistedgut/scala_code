--
-- DC3 Only
--

-- CANDO-8367: Reset an APAC Customer's DDU Acceptance Flag

BEGIN WORK;

UPDATE  customer
    SET ddu_terms_accepted = FALSE
WHERE   is_customer_number = 710229283
;

INSERT INTO customer_note ( customer_id, note_type_id, operator_id, date, note )
SELECT  c.id,
        nt.id,
        op.id,
        now(),
        'BAU (CANDO-8367): Have reset the Customer''s DDU Terms Acceptance flag'
FROM    customer c,
        note_type nt,
        operator op
WHERE   c.is_customer_number = 710229283
AND     nt.code = 'CUS'
AND     op.name = 'Application'
;

COMMIT WORK;
