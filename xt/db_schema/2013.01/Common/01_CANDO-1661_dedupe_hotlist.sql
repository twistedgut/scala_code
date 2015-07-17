-- CANDO-1661: Dedupe the 'hotlist_value' table
--             across all 4 columns.

BEGIN WORK;

CREATE TEMP TABLE hotlist_value_dupes (
    field_id        integer,
    value           character varying(255),
    channel_id      integer,
    order_nr        character varying(20),
    dupe_count      integer,
    min_id          integer
);
INSERT INTO hotlist_value_dupes
SELECT  hotlist_field_id,
        LOWER(value),
        channel_id,
        COALESCE(order_nr,''),
        COUNT(*),
        MIN(id)
FROM    hotlist_value
GROUP BY 1,2,3,4
HAVING COUNT(*) > 1
;

DELETE FROM hotlist_value
WHERE id IN (
    SELECT  hv.id
    FROM    hotlist_value hv
            JOIN hotlist_value_dupes hvd ON
                        hvd.field_id    = hv.hotlist_field_id
                    AND LOWER(hvd.value)= LOWER(hv.value)
                    AND hvd.channel_id  = hv.channel_id
                    AND ( hvd.order_nr  = hv.order_nr
                        OR ( COALESCE(hvd.order_nr,'') = COALESCE(hv.order_nr,'') )
                    )
    WHERE   hv.id NOT IN (
        SELECT  min_id
        FROM    hotlist_value_dupes
    )
)
;

CREATE UNIQUE INDEX hotlist_value_dupe_key ON hotlist_value( hotlist_field_id, LOWER(value::text), channel_id, COALESCE(order_nr, ''::character varying) );

COMMIT WORK;
