-- designer channel data for Mr Porter, channel 5
-- fix for CH-416

BEGIN;

INSERT INTO designer_channel (
    designer_id, page_id, website_state_id, description, description_is_live, channel_id
)
SELECT
    designer_id, page_id, website_state_id, description, description_is_live, 5
    FROM designer_channel
    WHERE channel_id=1
    AND designer_id NOT IN (SELECT designer_id FROM designer_channel WHERE channel_id=5)
;


COMMIT;
