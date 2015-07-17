BEGIN;

-- Link table

DELETE FROM acl.link_authorisation_role__authorisation_sub_section link
WHERE link.authorisation_role_id = (
    SELECT id FROM acl.authorisation_role role
    WHERE authorisation_role = 'app_canManagePrinters'
) AND link.authorisation_sub_section_id = (
    SELECT id FROM authorisation_sub_section submenu
    WHERE authorisation_section_id = (
        SELECT id FROM authorisation_section menu WHERE section = 'Admin'
        AND submenu.sub_section = 'Printers'
    )
);

-- Submenu

DELETE FROM authorisation_sub_section submenu
WHERE authorisation_section_id = (
    SELECT id FROM authorisation_section menu WHERE section = 'Admin'
) AND submenu.sub_section = 'Printers'
;

-- Role table
-- QUESTION: Does this have any other purpose except for allowing access to http://xtracker/Admin/Printers ?

DELETE FROM acl.authorisation_role role
WHERE authorisation_role = 'app_canManagePrinters';

COMMIT;
