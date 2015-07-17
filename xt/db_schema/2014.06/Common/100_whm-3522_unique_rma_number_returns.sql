BEGIN;

-- WHM-3522: Avoid creating duplicate RMAs for samples

-- 1. Cancel any recent duplicate returns (only recent returns will have uncancelled duplicates, as we've already fixed old ones)
-- See also RES-W101 at http://confluence.net-a-porter.com/display/WHM/RES-W101+Cancel+duplicate+sample+RMA
-- 1.1 Produce list of returns to cancel - just for reference
select r1.rma_number, r1.creation_date, r2.rma_number , r2.creation_date, q.channel_id
from return r1 join shipment s on s.id=r1.shipment_id
join link_stock_transfer__shipment lsts on lsts.shipment_id=s.id
join return r2 on s.id=r2.shipment_id
join shipment_item si on si.shipment_id=s.id
join quantity q on q.variant_id=si.variant_id
where q.status_id = (select id from flow.status where name = 'Transfer Pending')
and q.quantity = 1
and r1.return_status_id = (select id from return_status where status = 'Awaiting Return')
and r2.return_status_id = (select id from return_status where status = 'Complete')
order by r1.id;
-- 1.2 Do the update - set status to cancelled for duplicates
update return set cancellation_date = current_timestamp, return_status_id = (select id from return_status where status = 'Cancelled')
where id in (
    select r1.id
    from return r1 join shipment s on s.id=r1.shipment_id
    join link_stock_transfer__shipment lsts on lsts.shipment_id=s.id
    join return r2 on s.id=r2.shipment_id
    join shipment_item si on si.shipment_id=s.id
    join quantity q on q.variant_id=si.variant_id
    where q.status_id = (select id from flow.status where name = 'Transfer Pending')
    and q.quantity = 1
    and r1.return_status_id = (select id from return_status where status = 'Awaiting Return')
    and r2.return_status_id = (select id from return_status where status = 'Complete')
);

-- 2. Change any duplicate RMA numbers (only the cancelled ones) to something unique
CREATE TEMP TABLE temp_return_duplicate_grouped AS
    SELECT rma_number, COUNT(*), MAX(creation_date)
    FROM return
    GROUP BY rma_number
    HAVING COUNT(*) > 1
    ORDER BY MAX(creation_date) DESC;
CREATE TEMP TABLE temp_return_duplicate_all AS
    SELECT rma_number, return_status_id, creation_date FROM return WHERE rma_number IN (
        SELECT rma_number FROM temp_return_duplicate_grouped
    );
-- 2.1 Mark any recent duplicates as such
UPDATE return SET rma_number = rma_number || 'd' || id WHERE rma_number IN (
    SELECT rma_number FROM temp_return_duplicate_all WHERE creation_date >= '2014-01-01 00:00:00'
        AND return_status_id = (SELECT id FROM return_status WHERE status IN ('Awaiting Return'))
);

-- 3. Mark historical duplicates as such
UPDATE return SET rma_number = rma_number || 'd' || id WHERE rma_number IN (
    SELECT rma_number FROM return WHERE creation_date < '2014-01-01 00:00:00' GROUP BY rma_number HAVING COUNT(rma_number) > 1
);

-- 4. Add a unique constraint so this doesn't happen again
ALTER TABLE return ADD CONSTRAINT return__rma_number_unique UNIQUE (rma_number);

-- 5. Leave a clue for other developers
COMMENT ON COLUMN return.rma_number IS 'RMA numbers containing "d", e.g. R124569-21149d023110 are historical duplicates created in error before March 2014';

COMMIT;
