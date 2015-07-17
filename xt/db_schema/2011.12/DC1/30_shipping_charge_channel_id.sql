

BEGIN;

-- Fill in missing information from the web site for shipping_charge.shannel_id



ALTER TABLE shipping_charge
    ADD COLUMN channel_id INTEGER NULL,
    ADD CONSTRAINT shipping_charge_channel_id_fkey FOREIGN KEY (channel_id)
            REFERENCES channel(id)
;



update shipping_charge
    set channel_id = (select id from channel where name = 'NET-A-PORTER.COM')
    where sku in (
        '',           -- Bogus Unknown shipping charge, assign to NAP as the least worst option
        '900010-001', -- France  (might be obsolete, not present in the web site)
        '900011-001', -- Germany (might be obsolete, not present in the web site)
        '900012-001', -- Greece  (might be obsolete, not present in the web site)
        '900000-001',
        '900001-001',
        '900002-001',
        '900003-001',
        '900004-001',
        '900005-001',
        '900008-001',
        '9000119-001',
        '9000120-001',
        '9000121-001',
        '9000122-001',
        '9000123-001',
        '9000200-001',
        '9000201-001',
        '9000202-001',
        '9000203-001',
        '9000204-001'
         )
;



update shipping_charge
    set channel_id = (select id from channel where name = 'MRPORTER.COM')
    where sku in (
        '910000-001',
        '910001-001',
        '910002-001',
        '910003-001',
        '910004-001',
        '910005-001',
        '910008-001',
        '9010203-001',
        '9010204-001'
        )
;



update shipping_charge
    set channel_id = (select id from channel where name = 'theOutnet.com')
    where sku in (
        '903000-001',
        '903001-001',
        '903002-001',
        '903003-001',
        '903004-001',
        '903005-001',
        '903006-001',
        '903007-001',
        '903008-001',
        '903009-001'
        )
;



update shipping_charge
    set channel_id = (select id from channel where name = 'JIMMYCHOO.COM')
    where sku in (
        'europe',
        'londonpremierzonea',
        'londonpremierzoneb',
        'londonpremierzonec',
        'londonpremierzoned',
        'londonpremierzonee',
        'londonpremierzonef',
        'northamerica',
        'restoftheworld',
        'southamerica',
        'uklondonstandard'
        )
;



ALTER TABLE shipping_charge
    ALTER COLUMN channel_id SET NOT NULL;



COMMIT;
