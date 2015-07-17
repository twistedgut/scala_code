BEGIN;
   
    select setval('shipping_account_id_seq', (SELECT max(id) FROM shipping_account));

    insert into shipping_account (
        name,
        account_number,
        carrier_id,
        channel_id,
        return_cutoff_days,
        shipping_number,
        return_account_number)
    values 
        ('Domestic','X27W90',2,6,17,NULL,NULL),
        ('International','845888117',1,6,17,NULL,NULL),
        ('Unknown','',0,6,7,NULL,NULL)
    ;

COMMIT;
