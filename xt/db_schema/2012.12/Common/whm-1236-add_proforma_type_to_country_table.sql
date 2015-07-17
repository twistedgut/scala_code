-- Add flag to detect if Commercial Invoce is needed for specific countries

BEGIN WORK;
    ALTER TABLE country ADD is_commercial_proforma BOOLEAN NOT NULL DEFAULT FALSE;
    Update country SET is_commercial_proforma='true' WHERE country in ('Finland', 'Iceland', 'Kuwait', 'Turkey','Israel', 'Chile','Lebanon', 'Mauritius', 'Saint Lucia', 'Japan', 'India', 'Norway','South Africa', 'Gibraltar' );
COMMIT;

