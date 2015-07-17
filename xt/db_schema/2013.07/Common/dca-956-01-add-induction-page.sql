-- DCA-956: Add packing induction page (only for early-use PRL system in DC2)
-- Handler = Order/Fulfilment/Induction.pm
-- URL = /Fulfilment/Induction

BEGIN;

INSERT INTO authorisation_sub_section (authorisation_section_id, sub_section, ord)
     VALUES (
                (SELECT id FROM authorisation_section WHERE section = 'Fulfilment'),
                'Induction',
                (SELECT MAX(ord) + 1 FROM authorisation_sub_section
                  WHERE authorisation_section_id
                            = (SELECT id FROM authorisation_section WHERE section = 'Fulfilment')
                )
);

COMMIT;
