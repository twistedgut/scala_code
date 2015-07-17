CANDO-8183: Reset DDU Acceptance on Customer 710105927
--
-- TO BE RUN ON XTDC3 ONLY
--

BEGIN WORK;

UPDATE customer SET ddu_terms_accepted = false WHERE is_customer_number = '710105927';

INSERT INTO customer_note ( customer_id, note, note_type_id, operator_id, date )
VALUES (
    ( SELECT id FROM customer WHERE is_customer_number = '710105927' ),
    'DDU Acceptance reset (CANDO-8183)',
    ( SELECT id FROM note_type WHERE description = 'Customer' ),
    ( SELECT id FROM operator WHERE name = 'Application'),
    now()
);

COMMIT WORK;
