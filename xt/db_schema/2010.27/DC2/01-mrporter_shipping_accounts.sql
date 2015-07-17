begin;

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
        ('International','X27W90',2 ,6,17,'X27W90','X27W90'),
        ('Unknown','',0 ,6,14,'','')
    ;

     update shipping_account set shipping_number='X27W90',return_account_number='X27W90' where channel_id=6 and carrier_id<>0;
     
    insert into shipping_account__country (
        shipping_account_id,
        country,
        channel_id
    ) values
        (9,'United States',6)
    ;

commit;
