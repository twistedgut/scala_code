BEGIN;

CREATE TABLE public.sample_size_scheme_default_size (
    id              serial primary key,
    size_scheme_id  integer not null references public.size_scheme(id) DEFERRABLE,
    size_id         integer not null references public.size(id) DEFERRABLE,
    channel_id      integer not null references public.channel(id) DEFERRABLE
);

ALTER TABLE public.sample_size_scheme_default_size OWNER TO www;

insert into sample_size_scheme_default_size (channel_id, size_scheme_id, size_id)
values (
    5,
    (select id from size_scheme ss where ss.name = 'M Accessories XXS - XXXL'),
    (select ssvs.size_id from size_scheme_variant_size ssvs
        join size_scheme ss on ss.id = ssvs.size_scheme_id
        join size s on s.id = ssvs.size_id
    where
        ss.name = 'M Accessories XXS - XXXL'
    and
        s.size = 'M'
    )
);

insert into sample_size_scheme_default_size (channel_id, size_scheme_id, size_id)
values (
    5,
    (select id from size_scheme ss where ss.name = 'M Acc Order S/M/L'),
    (select ssvs.size_id from size_scheme_variant_size ssvs
        join size_scheme ss on ss.id = ssvs.size_scheme_id
        join size s on s.id = ssvs.size_id
    where
        ss.name = 'M Acc Order S/M/L'
    and
        s.size = 'S/M'
    )
);

insert into sample_size_scheme_default_size (channel_id, size_scheme_id, size_id)
values (
    5,
    (select id from size_scheme ss where ss.name = 'M Belts'),
    (select ssvs.size_id from size_scheme_variant_size ssvs
        join size_scheme ss on ss.id = ssvs.size_scheme_id
        join size s on s.id = ssvs.size_id
    where
        ss.name = 'M Belts'
    and
        s.size = '90'
    )
);

insert into sample_size_scheme_default_size (channel_id, size_scheme_id, size_id)
values (
    5,
    (select id from size_scheme ss where ss.name = 'M Glasses'),
    (select ssvs.size_id from size_scheme_variant_size ssvs
        join size_scheme ss on ss.id = ssvs.size_scheme_id
        join size s on s.id = ssvs.size_id
    where
        ss.name = 'M Glasses'
    and
        s.size = '0.75'
    )
);

insert into sample_size_scheme_default_size (channel_id, size_scheme_id, size_id)
values (
    5,
    (select id from size_scheme ss where ss.name = 'M Gloves'),
    (select ssvs.size_id from size_scheme_variant_size ssvs
        join size_scheme ss on ss.id = ssvs.size_scheme_id
        join size s on s.id = ssvs.size_id
    where
        ss.name = 'M Gloves'
    and
        s.size = '9.5'
    )
);

insert into sample_size_scheme_default_size (channel_id, size_scheme_id, size_id)
values (
    5,
    (select id from size_scheme ss where ss.name = 'M Hats'),
    (select ssvs.size_id from size_scheme_variant_size ssvs
        join size_scheme ss on ss.id = ssvs.size_scheme_id
        join size s on s.id = ssvs.size_id
    where
        ss.name = 'M Hats'
    and
        s.size = 'L'
    )
);

insert into sample_size_scheme_default_size (channel_id, size_scheme_id, size_id)
values (
    5,
    (select id from size_scheme ss where ss.name = 'M Hats (cm)'),
    (select ssvs.size_id from size_scheme_variant_size ssvs
        join size_scheme ss on ss.id = ssvs.size_scheme_id
        join size s on s.id = ssvs.size_id
    where
        ss.name = 'M Hats (cm)'
    and
        s.size = '63'
    )
);

insert into sample_size_scheme_default_size (channel_id, size_scheme_id, size_id)
values (
    5,
    (select id from size_scheme ss where ss.name = 'M Jeans RL (inches)'),
    (select ssvs.size_id from size_scheme_variant_size ssvs
        join size_scheme ss on ss.id = ssvs.size_scheme_id
        join size s on s.id = ssvs.size_id
    where
        ss.name = 'M Jeans RL (inches)'
    and
        s.size = '32L'
    )
);

insert into sample_size_scheme_default_size (channel_id, size_scheme_id, size_id)
values (
    5,
    (select id from size_scheme ss where ss.name = 'M Jeans w/length'),
    (select ssvs.size_id from size_scheme_variant_size ssvs
        join size_scheme ss on ss.id = ssvs.size_scheme_id
        join size s on s.id = ssvs.size_id
    where
        ss.name = 'M Jeans w/length'
    and
        s.size = '32W 34L'
    )
);


insert into sample_size_scheme_default_size (channel_id, size_scheme_id, size_id)
values (
    5,
    (select id from size_scheme ss where ss.name = 'One Size'),
    (select ssvs.size_id from size_scheme_variant_size ssvs
        join size_scheme ss on ss.id = ssvs.size_scheme_id
        join size s on s.id = ssvs.size_id
    where
        ss.name = 'One Size'
    and
        s.size = 'One size'
    )
);


insert into sample_size_scheme_default_size (channel_id, size_scheme_id, size_id)
values (
    5,
    (select id from size_scheme ss where ss.name = 'M Pants'),
    (select ssvs.size_id from size_scheme_variant_size ssvs
        join size_scheme ss on ss.id = ssvs.size_scheme_id
        join size s on s.id = ssvs.size_id
    where
        ss.name = 'M Pants'
    and
        s.size = '32'
    )
);

insert into sample_size_scheme_default_size (channel_id, size_scheme_id, size_id)
values (
    5,
    (select id from size_scheme ss where ss.name = 'M Pants w/length'),
    (select ssvs.size_id from size_scheme_variant_size ssvs
        join size_scheme ss on ss.id = ssvs.size_scheme_id
        join size s on s.id = ssvs.size_id
    where
        ss.name = 'M Pants w/length'
    and
        s.size = '32W 34L'
    )
);

insert into sample_size_scheme_default_size (channel_id, size_scheme_id, size_id)
values (
    5,
    (select id from size_scheme ss where ss.name = 'M RTW - FRANCE'),
    (select ssvs.size_id from size_scheme_variant_size ssvs
        join size_scheme ss on ss.id = ssvs.size_scheme_id
        join size s on s.id = ssvs.size_id
    where
        ss.name = 'M RTW - FRANCE'
    and
        s.size = '50'
    )
);

insert into sample_size_scheme_default_size (channel_id, size_scheme_id, size_id)
values (
    5,
    (select id from size_scheme ss where ss.name = 'M RTW - ITALY'),
    (select ssvs.size_id from size_scheme_variant_size ssvs
        join size_scheme ss on ss.id = ssvs.size_scheme_id
        join size s on s.id = ssvs.size_id
    where
        ss.name = 'M RTW - ITALY'
    and
        s.size = '50'
    )
);

insert into sample_size_scheme_default_size (channel_id, size_scheme_id, size_id)
values (
    5,
    (select id from size_scheme ss where ss.name = 'M RTW - UK'),
    (select ssvs.size_id from size_scheme_variant_size ssvs
        join size_scheme ss on ss.id = ssvs.size_scheme_id
        join size s on s.id = ssvs.size_id
    where
        ss.name = 'M RTW - UK'
    and
        s.size = '40'
    )
);

insert into sample_size_scheme_default_size (channel_id, size_scheme_id, size_id)
values (
    5,
    (select id from size_scheme ss where ss.name = 'M RTW US SRL'),
    (select ssvs.size_id from size_scheme_variant_size ssvs
        join size_scheme ss on ss.id = ssvs.size_scheme_id
        join size s on s.id = ssvs.size_id
    where
        ss.name = 'M RTW US SRL'
    and
        s.size = '40R'
    )
);

insert into sample_size_scheme_default_size (channel_id, size_scheme_id, size_id)
values (
    5,
    (select id from size_scheme ss where ss.name = 'M RTW US'),
    (select ssvs.size_id from size_scheme_variant_size ssvs
        join size_scheme ss on ss.id = ssvs.size_scheme_id
        join size s on s.id = ssvs.size_id
    where
        ss.name = 'M RTW US'
    and
        s.size = '40'
    )
);

insert into sample_size_scheme_default_size (channel_id, size_scheme_id, size_id)
values (
    5,
    (select id from size_scheme ss where ss.name = 'M RTW XS - XL'),
    (select ssvs.size_id from size_scheme_variant_size ssvs
        join size_scheme ss on ss.id = ssvs.size_scheme_id
        join size s on s.id = ssvs.size_id
    where
        ss.name = 'M RTW XS - XL'
    and
        s.size = 'L'
    )
);

insert into sample_size_scheme_default_size (channel_id, size_scheme_id, size_id)
values (
    5,
    (select id from size_scheme ss where ss.name = 'M RTW XXS - XXXL'),
    (select ssvs.size_id from size_scheme_variant_size ssvs
        join size_scheme ss on ss.id = ssvs.size_scheme_id
        join size s on s.id = ssvs.size_id
    where
        ss.name = 'M RTW XXS - XXXL'
    and
        s.size = 'M'
    )
);

insert into sample_size_scheme_default_size (channel_id, size_scheme_id, size_id)
values (
    5,
    (select id from size_scheme ss where ss.name = 'M Shirts EU'),
    (select ssvs.size_id from size_scheme_variant_size ssvs
        join size_scheme ss on ss.id = ssvs.size_scheme_id
        join size s on s.id = ssvs.size_id
    where
        ss.name = 'M Shirts EU'
    and
        s.size = '40'
    )
);

insert into sample_size_scheme_default_size (channel_id, size_scheme_id, size_id)
values (
    5,
    (select id from size_scheme ss where ss.name = 'M Shirts UK'),
    (select ssvs.size_id from size_scheme_variant_size ssvs
        join size_scheme ss on ss.id = ssvs.size_scheme_id
        join size s on s.id = ssvs.size_id
    where
        ss.name = 'M Shirts UK'
    and
        s.size = '15.5'
    )
);

insert into sample_size_scheme_default_size (channel_id, size_scheme_id, size_id)
values (
    5,
    (select id from size_scheme ss where ss.name = 'M Shirts 38R-44L'),
    (select ssvs.size_id from size_scheme_variant_size ssvs
        join size_scheme ss on ss.id = ssvs.size_scheme_id
        join size s on s.id = ssvs.size_id
    where
        ss.name = 'M Shirts 38R-44L'
    and
        s.size = '40R'
    )
);

insert into sample_size_scheme_default_size (channel_id, size_scheme_id, size_id)
values (
    5,
    (select id from size_scheme ss where ss.name = 'M Shoes - FR full size'),
    (select ssvs.size_id from size_scheme_variant_size ssvs
        join size_scheme ss on ss.id = ssvs.size_scheme_id
        join size s on s.id = ssvs.size_id
    where
        ss.name = 'M Shoes - FR full size'
    and
        s.size = '44'
    )
);

insert into sample_size_scheme_default_size (channel_id, size_scheme_id, size_id)
values (
    5,
    (select id from size_scheme ss where ss.name = 'M Shoes - EU full size'),
    (select ssvs.size_id from size_scheme_variant_size ssvs
        join size_scheme ss on ss.id = ssvs.size_scheme_id
        join size s on s.id = ssvs.size_id
    where
        ss.name = 'M Shoes - EU full size'
    and
        s.size = '44'
    )
);

insert into sample_size_scheme_default_size (channel_id, size_scheme_id, size_id)
values (
    5,
    (select id from size_scheme ss where ss.name = 'M Shoes - EU half size'),
    (select ssvs.size_id from size_scheme_variant_size ssvs
        join size_scheme ss on ss.id = ssvs.size_scheme_id
        join size s on s.id = ssvs.size_id
    where
        ss.name = 'M Shoes - EU half size'
    and
        s.size = '44'
    )
);

insert into sample_size_scheme_default_size (channel_id, size_scheme_id, size_id)
values (
    5,
    (select id from size_scheme ss where ss.name = 'M Shoes - US full size'),
    (select ssvs.size_id from size_scheme_variant_size ssvs
        join size_scheme ss on ss.id = ssvs.size_scheme_id
        join size s on s.id = ssvs.size_id
    where
        ss.name = 'M Shoes - US full size'
    and
        s.size = '11'
    )
);


insert into sample_size_scheme_default_size (channel_id, size_scheme_id, size_id)
values (
    5,
    (select id from size_scheme ss where ss.name = 'M Shoes - US half size'),
    (select ssvs.size_id from size_scheme_variant_size ssvs
        join size_scheme ss on ss.id = ssvs.size_scheme_id
        join size s on s.id = ssvs.size_id
    where
        ss.name = 'M Shoes - US half size'
    and
        s.size = '11'
    )
);

insert into sample_size_scheme_default_size (channel_id, size_scheme_id, size_id)
values (
    5,
    (select id from size_scheme ss where ss.name = 'M Shoes - UK full size'),
    (select ssvs.size_id from size_scheme_variant_size ssvs
        join size_scheme ss on ss.id = ssvs.size_scheme_id
        join size s on s.id = ssvs.size_id
    where
        ss.name = 'M Shoes - UK full size'
    and
        s.size = '10'
    )
);

insert into sample_size_scheme_default_size (channel_id, size_scheme_id, size_id)
values (
    5,
    (select id from size_scheme ss where ss.name = 'M Shoes - UK half size'),
    (select ssvs.size_id from size_scheme_variant_size ssvs
        join size_scheme ss on ss.id = ssvs.size_scheme_id
        join size s on s.id = ssvs.size_id
    where
        ss.name = 'M Shoes - UK half size'
    and
        s.size = '10'
    )
);

insert into sample_size_scheme_default_size (channel_id, size_scheme_id, size_id)
values (
    5,
    (select id from size_scheme ss where ss.name = 'M Shorts'),
    (select ssvs.size_id from size_scheme_variant_size ssvs
        join size_scheme ss on ss.id = ssvs.size_scheme_id
        join size s on s.id = ssvs.size_id
    where
        ss.name = 'M Shorts'
    and
        s.size = '32'
    )
);

insert into sample_size_scheme_default_size (channel_id, size_scheme_id, size_id)
values (
    5,
    (select id from size_scheme ss where ss.name = 'M Socks'),
    (select ssvs.size_id from size_scheme_variant_size ssvs
        join size_scheme ss on ss.id = ssvs.size_scheme_id
        join size s on s.id = ssvs.size_id
    where
        ss.name = 'M Socks'
    and
        s.size = 'L'
    )
);

insert into sample_size_scheme_default_size (channel_id, size_scheme_id, size_id)
values (
    5,
    (select id from size_scheme ss where ss.name = 'M Swimwear'),
    (select ssvs.size_id from size_scheme_variant_size ssvs
        join size_scheme ss on ss.id = ssvs.size_scheme_id
        join size s on s.id = ssvs.size_id
    where
        ss.name = 'M Swimwear'
    and
        s.size = '32'
    )
);

insert into sample_size_scheme_default_size (channel_id, size_scheme_id, size_id)
values (
    5,
    (select id from size_scheme ss where ss.name = 'M Underwear'),
    (select ssvs.size_id from size_scheme_variant_size ssvs
        join size_scheme ss on ss.id = ssvs.size_scheme_id
        join size s on s.id = ssvs.size_id
    where
        ss.name = 'M Underwear'
    and
        s.size = '32'
    )
);

insert into sample_size_scheme_default_size (channel_id, size_scheme_id, size_id)
values (
    5,
    (select id from size_scheme ss where ss.name = 'M Underwear XS - XL'),
    (select ssvs.size_id from size_scheme_variant_size ssvs
        join size_scheme ss on ss.id = ssvs.size_scheme_id
        join size s on s.id = ssvs.size_id
    where
        ss.name = 'M Underwear XS - XL'
    and
        s.size = 'S/M'
    )
);

--- there is 'M Underwear XS-XXL' but not 'M Underwear XS-XXXL'
insert into sample_size_scheme_default_size (channel_id, size_scheme_id, size_id)
values (
    5,
    (select id from size_scheme ss where ss.name = 'M Underwear XS-XXL'),
    (select ssvs.size_id from size_scheme_variant_size ssvs
        join size_scheme ss on ss.id = ssvs.size_scheme_id
        join size s on s.id = ssvs.size_id
    where
        ss.name = 'M Underwear XS-XXL'
    and
        s.size = 'M'
    )
);

--- insert into sample_size_scheme_default_size (channel_id, size_scheme_id, size_id)
--- values (
---     5,
---     (select id from size_scheme ss where ss.name = 'Unsized'),
---     (select ssvs.size_id from size_scheme_variant_size ssvs
---         join size_scheme ss on ss.id = ssvs.size_scheme_id
---         join size s on s.id = ssvs.size_id
---     where
---         ss.name = 'Unsized'
---     and
---         s.size = 'Unsized'
---     )
--- );
---
COMMIT;
