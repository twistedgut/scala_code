-- CANDO-337: Add new Tax Rule 'Custom Modifier', apply Custom Modifier of 0.82 to Brazil and update Tax Rate for Brazil to 18%.

BEGIN WORK;

-- Apply Custom Modifier of 0.82 to Brazil
INSERT INTO tax_rule_value (
    tax_rule_id,
    country_id,
    value
) VALUES (
    ( SELECT id FROM tax_rule WHERE rule = 'Custom Modifier' ),
    ( SELECT id FROM country WHERE country = 'Brazil' ),
    82
);

-- Update Country Tax Rate for Brazil to 18%
UPDATE  country_tax_rate
SET     rate = 0.18
WHERE   country_id = ( SELECT id FROM country WHERE country = 'Brazil' );

COMMIT;
