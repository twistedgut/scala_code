-- navigation colour mapping for Mr Porter, channel 6
-- no-one quite knows what it does exactly, but uploads don't work without it
-- we're just copying what's there for channel 2 at the moment

BEGIN;

INSERT INTO navigation_colour_mapping (
    colour_filter_id, colour_navigation_id, channel_id
)
SELECT
    colour_filter_id, colour_navigation_id, 6
    FROM navigation_colour_mapping
    WHERE channel_id=2
;


COMMIT;
