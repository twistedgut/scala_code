-- We don't have carrier automation in DC3

BEGIN;
    DELETE FROM authorisation_sub_section WHERE sub_section = 'Carrier Automation';
COMMIT;
