-- DC2 ONLY Patch, to add an International shipping account for DHL Express for The Outnet

BEGIN WORK;

SELECT setval(
    'shipping_account_id_seq',
    ( SELECT MAX(id) FROM shipping_account )
)
;

INSERT INTO shipping_account (name,account_number,carrier_id,channel_id,return_cutoff_days) VALUES (
    'International',
    '',
    (SELECT id FROM carrier WHERE name = 'DHL Express'),
    (
        SELECT  c.id
        FROM    channel c
                JOIN business b ON b.id = c.business_id
                                AND b.config_section = 'OUTNET'
                    
    ),
    17
)
;

COMMIT WORK;
