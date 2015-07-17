-- designer channel data for Mr Porter, channel 6
-- fix for CH-416

BEGIN;

INSERT INTO designer_channel (
    designer_id, page_id, website_state_id, description, description_is_live, channel_id
)
SELECT
    designer_id, page_id, website_state_id, description, description_is_live, 6
    FROM designer_channel
    WHERE channel_id=2
    AND designer_id NOT IN (SELECT designer_id FROM designer_channel WHERE channel_id=6)
;


COMMIT;
