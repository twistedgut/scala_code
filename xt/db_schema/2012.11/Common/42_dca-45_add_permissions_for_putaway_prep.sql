-- DCA-45: Enable the 'Putaway Prep' process as part of Goods In
-- Handler = PutawayPrep.pm
-- URL = /GoodsIn/PutawayPrep

BEGIN;

INSERT INTO authorisation_sub_section (authorisation_section_id, sub_section, ord)
     VALUES (
                (SELECT id FROM authorisation_section WHERE section = 'Goods In'),
                'Putaway Prep',
                (SELECT MAX(ord) + 1 FROM authorisation_sub_section
                  WHERE authorisation_section_id
                            = (SELECT id FROM authorisation_section WHERE section = 'Goods In')
                )
);

COMMIT;
