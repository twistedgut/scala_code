BEGIN;

    -- packaging_types

    alter table packaging_type add column channel_id int;
    update packaging_type set channel_id=2 where dc='DC1';
    update packaging_type set channel_id=4 where dc='DC2';
    alter table packaging_type drop column dc;

    alter table packaging_type rename column packaging_type to name;
    
COMMIT;
