-- DCA-1602: Add page for performing Putaway prep for items that comes from locations (actually from Packing exception)
-- Handler = XTracker::Stock::GoodsIn::PutawayPrepPackingException
-- URL = /GoodsIn/PutawayPrepPackingException

BEGIN;

INSERT INTO authorisation_sub_section (authorisation_section_id, sub_section, ord)
VALUES (
    (SELECT id FROM authorisation_section WHERE section = 'Goods In'),
    'Putaway Prep Packing Exception',
    (   SELECT MAX(ord) + 1
        FROM authorisation_sub_section
        WHERE authorisation_section_id = (
            SELECT id
            FROM authorisation_section
            WHERE section = 'Goods In'
        )
    )
);

COMMIT;
