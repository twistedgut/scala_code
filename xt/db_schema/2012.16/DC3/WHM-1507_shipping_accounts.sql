-- Dummy shipping account data

BEGIN;
    DELETE FROM shipping_account__country;
    DELETE FROM shipping_account__postcode;
    DELETE FROM shipping_account;
    SELECT setval('shipping_account_id_seq', 1, false);
    INSERT INTO shipping_account (
        id, name, account_number, carrier_id, channel_id, return_cutoff_days
    ) VALUES
        ( 0, 'Unknown', '', ( SELECT id FROM carrier WHERE name = 'Unknown' ), ( SELECT id from channel WHERE web_name = 'NAP-APAC' ), 28 )
    ;
    INSERT INTO shipping_account (
        name, account_number, carrier_id, channel_id, return_cutoff_days, return_account_number
    ) VALUES
        ( 'Domestic', '631138086', ( SELECT id FROM carrier WHERE name = 'DHL Express' ), ( SELECT id from channel WHERE web_name = 'NAP-APAC' ), 28,  '954293042' ),
        ( 'International', '631138086', ( SELECT id FROM carrier WHERE name = 'DHL Express' ), ( SELECT id from channel WHERE web_name = 'NAP-APAC' ), 28, '954293042' )
    ;
COMMIT;
