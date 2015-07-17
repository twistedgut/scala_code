-- CANDO-337: Re-Setting the Sequence Id on the 'tax_rule' table so that future
--            Inserts will work and won't try and add '1' as the sequence id

BEGIN WORK;

-- Reset sequence.
SELECT setval(
    pg_get_serial_sequence('tax_rule', 'id'),
    ( SELECT MAX(id) FROM tax_rule )
);

-- Add new Tax Rule 'Custom Modifier'
INSERT INTO tax_rule (
    rule
) VALUES (
    'Custom Modifier'
);

COMMIT WORK;
