BEGIN;

    SET CONSTRAINTS ALL DEFERRED;

    ALTER TABLE packaging_type DROP COLUMN business_id;

    DELETE FROM packaging_type;

    SELECT SETVAL('packaging_type_id_seq', (SELECT max(id) FROM packaging_type));

    insert into packaging_type (sku,name,channel_id) values ('900006-001','SIGNATURE',NULL);
    insert into packaging_type (sku,name,channel_id) values ('900007-001','BASIC',NULL);
    insert into packaging_type (sku,name,channel_id) values ('900009-001','DISCREET',NULL);
    insert into packaging_type (sku,name,channel_id) values ('900110-001','WEDDING',NULL);
    insert into packaging_type (sku,name,channel_id) values ('903100-001','BASIC',3);
    insert into packaging_type (sku,name,channel_id) values ('904100-001','BASIC',NULL);

COMMIT;
