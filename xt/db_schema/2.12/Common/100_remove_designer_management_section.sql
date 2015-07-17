BEGIN;
    delete from public.authorisation_sub_section
        where sub_section = 'Designer Management'
        AND authorisation_section_id = (SELECT id from authorisation_section WHERE section = 'Retail');
COMMIT;
