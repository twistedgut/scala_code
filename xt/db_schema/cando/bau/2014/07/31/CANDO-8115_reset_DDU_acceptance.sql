--
-- CANDO-8115: Reset DDU Acceptance on Customer 710264400
--
-- TO BE RUN ON XTDC3 ONLY
--

BEGIN WORK;

UPDATE customer SET ddu_terms_accepted = false WHERE is_customer_number = '710264400';

INSERT INTO customer_note ( customer_id, note, note_type_id, operator_id, date )
VALUES (
    ( SELECT id FROM customer WHERE is_customer_number = '710264400' ),
    'DDU Acceptance reset (CANDO-8115)',
    ( SELECT id FROM note_type WHERE description = 'Customer' ),
    ( SELECT id FROM operator WHERE name = 'Application'),
    now()
);

COMMIT WORK;
