BEGIN;
    
    SELECT setval('size_id_seq', (SELECT max(id) FROM size));
    insert into size (size,sequence) values ('28R',null);
    insert into size (size,sequence) values ('28L',null);
    update size_scheme_variant_size set position=position+2 where position > 2 and size_scheme_id = 50;
    insert into size_scheme_variant_size (size_scheme_id,size_id,designer_size_id,position) values (50,(select id from size where size='28R'),(select id from size where size='28R'),3);
    insert into size_scheme_variant_size (size_scheme_id,size_id,designer_size_id,position) values (50,(select id from size where size='28L'),(select id from size where size='28L'),4);

COMMIT;
