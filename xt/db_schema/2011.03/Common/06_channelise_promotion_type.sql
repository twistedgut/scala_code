BEGIN;

ALTER TABLE promotion_type OWNER TO www;

ALTER TABLE promotion_type
    ADD channel_id INTEGER REFERENCES channel(id) DEFERRABLE;


-- the current welcome packs are all for NAP
UPDATE promotion_type SET channel_id = (
        SELECT id FROM channel WHERE web_name ilike 'NAP%'
    ) WHERE name ilike 'Welcome Pack%';

-- there are some promotion_types already labelled sensibly
UPDATE promotion_type SET channel_id = (
        SELECT id FROM channel WHERE web_name ilike 'NAP%'
    ) WHERE name ilike 'NET-A-PORTER%';

-- MRP postcard for NAP customers
UPDATE promotion_type SET channel_id = (
        SELECT id FROM channel WHERE web_name ilike 'NAP%'
    ) WHERE name = 'MR PORTER Postcard';

-- the rest are old NAP ones
UPDATE promotion_type SET channel_id = (
        SELECT id FROM channel WHERE web_name ilike 'NAP%'
    ) WHERE channel_id IS NULL;

COMMIT;
