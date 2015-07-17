-- CANDO-557: On the 'routing_schedule' table change the 'external_id'
--            column to being an INTEGER and 'NOT NULL'.
--            On the 'routing_schedule_status' table add a 'rank' column.

BEGIN WORK;

--
-- 'routing_schedule' table
--

-- Clear out NON-Integers in the 'external_id' Column
DELETE FROM link_routing_schedule__return
WHERE routing_schedule_id IN (
            SELECT id
            FROM routing_schedule
            WHERE external_id !~ E'^\\d+$'
        )
;
DELETE FROM link_routing_schedule__shipment
WHERE routing_schedule_id IN (
            SELECT id
            FROM routing_schedule
            WHERE external_id !~ E'^\\d+$'
        )
;
DELETE FROM routing_schedule
WHERE external_id !~ E'^\\d+$'
;

-- Alter the Table
ALTER TABLE routing_schedule
    ALTER COLUMN external_id TYPE INTEGER USING CAST( external_id AS INTEGER ),
    ALTER COLUMN external_id SET NOT NULL
;


--
-- 'routing_schedule_status' table
--

ALTER TABLE routing_schedule_status
    ADD COLUMN rank SMALLINT
;

-- update the rankings for each Status
UPDATE  routing_schedule_status
    SET rank    =
            CASE name
                WHEN 'Scheduled'            THEN 10
                WHEN 'Shipment undelivered' THEN 20
                WHEN 'Shipment uncollected' THEN 20
                WHEN 'Shipment collected'   THEN 20
                WHEN 'Shipment delivered'   THEN 20
                WHEN 'Re-scheduled'         THEN 30
            END
;

-- now set the 'rank' column to being NOT NULL
ALTER TABLE routing_schedule_status
    ALTER COLUMN rank SET NOT NULL
;


COMMIT WORK;
