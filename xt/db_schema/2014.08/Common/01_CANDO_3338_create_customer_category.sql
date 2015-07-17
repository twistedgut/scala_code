
--
-- CANDO-3338: Create Customer Category submenu
--
BEGIN;

INSERT INTO
 public.authorisation_sub_section
 (authorisation_section_id, sub_section, ord)
VALUES (
 (SELECT id FROM public.authorisation_section WHERE section='Customer Care'),
 'Customer Category',
 (SELECT max(ord) + 1 FROM authorisation_sub_section WHERE authorisation_section_id = (SELECT id FROM authorisation_section WHERE section = 'Customer Care'))
);

COMMIT;
