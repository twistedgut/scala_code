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
        ('Domestic',184385371,1,5,10,NULL,NULL),
        ('International',184385397,1,5,12,NULL,NULL),
        ('Unknown','',0,5,7,NULL,NULL)
    ;

COMMIT;
