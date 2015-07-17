
BEGIN;

-- Enable the 'Putaway Problem Resolution' process as part of Goods In
-- Handler: XTracker::Stock::GoodsIn::PutawayProblemResolution
-- URL: /GoodsIn/PutawayProblemResolution

INSERT INTO authorisation_sub_section (authorisation_section_id, sub_section, ord)
    VALUES (
        (SELECT id FROM authorisation_section WHERE section = 'Goods In'),
        'Putaway Problem Resolution',
        (SELECT MAX(ord) + 1 FROM authorisation_sub_section
            WHERE authorisation_section_id =
                (SELECT id FROM authorisation_section WHERE section = 'Goods In')
        )
);

COMMIT;
