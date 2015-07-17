BEGIN;

    select setval('size_scheme_id_seq', (SELECT max(id) FROM size_scheme));
    insert into size_scheme (name,short_name) values ('M Jeans 32length','');
    insert into size_scheme (name,short_name) values ('M Jeans 34length','');
    insert into size_scheme (name,short_name) values ('M Jeans 36length','');

    update size_scheme set id=47 where name='M Jeans 32length';
    update size_scheme set id=48 where name='M Jeans 34length';
    update size_scheme set id=49 where name='M Jeans 36length';

COMMIT;
