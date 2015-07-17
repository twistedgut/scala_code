begin;
    create table packaging_type ( 
        id serial, 
        sku varchar(255), 
        packaging_type varchar(255), 
        business_id int references business(id),
        dc varchar(6)
    );
    
    insert into packaging_type (sku,packaging_type,business_id,dc) values ('900006-001','SIGNATURE',NULL,NULL);
    insert into packaging_type (sku,packaging_type,business_id,dc) values ('900007-001','BASIC',NULL,NULL);
    insert into packaging_type (sku,packaging_type,business_id,dc) values ('900009-001','DISCREET',NULL,NULL);
    insert into packaging_type (sku,packaging_type,business_id,dc) values ('900110-001','WEDDING',1,NULL);
    insert into packaging_type (sku,packaging_type,business_id,dc) values ('903100-001','BASIC',2,'DC1');
    insert into packaging_type (sku,packaging_type,business_id,dc) values ('904100-001','BASIC',2,'DC2');
    
    grant all on packaging_type to www;

commit;
