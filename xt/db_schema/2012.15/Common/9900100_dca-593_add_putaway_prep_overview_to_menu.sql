-- DCA-593 DCA-911: Enable the 'Putaway Prep Admin' page (part of Goods In)
-- Handler = PutawayAdmin.pm
-- URL = /GoodsIn/PutawayAdmin

BEGIN;

INSERT INTO authorisation_sub_section (authorisation_section_id, sub_section, ord)
     VALUES (
                (SELECT id FROM authorisation_section WHERE section = 'Goods In'),
                'Putaway Admin',
                (SELECT MAX(ord) + 1 FROM authorisation_sub_section
                  WHERE authorisation_section_id
                            = (SELECT id FROM authorisation_section WHERE section = 'Goods In')
                )
);

COMMIT;
