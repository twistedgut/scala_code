BEGIN;

insert into sample_size_scheme_default_size (channel_id, size_scheme_id, size_id)
values (
    5,
    (select id from size_scheme ss where ss.name = 'M Shirts UK sleeves size'),
    (select ssvs.size_id from size_scheme_variant_size ssvs
        join size_scheme ss on ss.id = ssvs.size_scheme_id
        join size s on s.id = ssvs.size_id
    where
        ss.name = 'M Shirts UK sleeves size'
    and
        s.size = '15.5/34'
    )
);

update sample_size_scheme_default_size set size_id = (
    select ssvs.size_id from size_scheme_variant_size ssvs
        join size_scheme ss on ss.id = ssvs.size_scheme_id
        join size s on s.id = ssvs.size_id
    where
        ss.name = 'M Glasses'
    and
        s.size = '0'
    )
WHERE size_scheme_id = (
    select id from size_scheme where name='M Glasses'
);

COMMIT;
