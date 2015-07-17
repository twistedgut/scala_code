--
-- CANDO-880: create Marketing Campaign sub-menu

BEGIN;

INSERT INTO
 public.authorisation_sub_section
    (authorisation_section_id, sub_section, ord)
VALUES (
    (SELECT id FROM public.authorisation_section WHERE section='NAP Events'),
    'In The Box',
    (SELECT max(ord) + 1 FROM authorisation_sub_section WHERE authorisation_section_id = (SELECT id FROM authorisation_section WHERE section = 'NAP Events'))
);

COMMIT;
