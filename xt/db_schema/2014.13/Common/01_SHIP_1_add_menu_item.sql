BEGIN;

-- Add new navigation menu item under "Admin"

insert into public.authorisation_sub_section
    (authorisation_section_id, sub_section, ord, acl_controlled)
values
    (
        (select id from authorisation_section where section = 'Admin'),
        'Shipping Config',
        (select max(ord) + 10
        from authorisation_sub_section ass
        join authorisation_section asec on ass.authorisation_section_id = asec.id
        where asec.section = 'Admin'),
        'f'
     );
COMMIT;
