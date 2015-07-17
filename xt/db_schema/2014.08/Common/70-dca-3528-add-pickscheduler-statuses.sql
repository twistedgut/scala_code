
-- DCA-3528: GOH: add missing, and change obsolete statuses and
-- config. Redo the entire list of
-- allocation_status_pack_space_allocation_time values.

BEGIN TRANSACTION;


-- Rename ready_to_deliver --> allocating_pack_space
UPDATE allocation_status
    SET status      = 'allocating_pack_space',
        description = 'If the PRL "Allocates pack space at" allocating_pack_space, this is the status it goes for after "picking", while waiting for pack space capacity'
    WHERE status    = 'ready_to_deliver';


COMMENT ON TABLE allocation_status IS
'
We don''t have workflows in XT, but the order is
| requested
| allocated
| picking
|\    (optional) [prl_allocates_pack_space_at: allocating_pack_space, e.g. GOH ]
| | allocating_pack_space
|/
|\    (optional) [delivery, e.g. GOH]
| | preparing
| | prepared
| | delivering
| | delivered
|/
|\    (optional) [induction point, e.g. Full]
| | staged
|/
| picked
| packed
';



-- Rename pick_complete to allocating_pack_space
UPDATE prl_pack_space_allocation_time
    SET name         = 'allocating_pack_space',
        display_name = 'Allocating Pack Space'
    WHERE name       = 'pick_complete';






-- Add "packed"
INSERT INTO allocation_status (status, description)
    VALUES (
        'packed',
        'Once the Shipment is packed the allocation is "packed", and no longer takes up packing capacity'
    );





-- Redo all these values, delete and re-insert

COMMENT ON COLUMN allocation_status_pack_space_allocation_time.is_pack_space_allocated IS
'Whether this status/pack_space_allocation_time combo indicates that
pack space is now allocated. The rows encode this table:

| pack_space_allocation_time | fulfilment_status                    | Example PRL |
|----------------------------+--------------------------------------+-------------|
| induction                  | picked                               | Full        |
| pick                       | picking, and following               | DCD         |
| allocating_pack_space      | after allocating_pack_space          | GOH         |

After picking = preparing/staged/picked and following.
';


DELETE FROM allocation_status_pack_space_allocation_time;


-- Induction, 'picked' only
INSERT INTO allocation_status_pack_space_allocation_time (prl_pack_space_allocation_time_id, allocation_status_id, is_pack_space_allocated)
    select (select id from prl_pack_space_allocation_time where
        name = 'induction'), allocation_status.id,
        false
    from allocation_status where allocation_status.status
        not in ('picked');
INSERT INTO allocation_status_pack_space_allocation_time (prl_pack_space_allocation_time_id, allocation_status_id, is_pack_space_allocated)
    select (select id from prl_pack_space_allocation_time where
        name = 'induction'), allocation_status.id,
        true
    from allocation_status where allocation_status.status
        in ('picked');

-- Pick, 'picking' and following
INSERT INTO allocation_status_pack_space_allocation_time (prl_pack_space_allocation_time_id, allocation_status_id, is_pack_space_allocated)
    select (select id from prl_pack_space_allocation_time where
        name = 'pick'), allocation_status.id,
        false
    from allocation_status where allocation_status.status
        not in ('picking', 'allocating_pack_space', 'preparing', 'prepared', 'delivering', 'delivered', 'staged', 'picked');
INSERT INTO allocation_status_pack_space_allocation_time (prl_pack_space_allocation_time_id, allocation_status_id, is_pack_space_allocated)
    select (select id from prl_pack_space_allocation_time where
        name = 'pick'), allocation_status.id,
        true
    from allocation_status where allocation_status.status
        in ('picking', 'allocating_pack_space', 'preparing', 'prepared', 'delivering', 'delivered', 'staged', 'picked');

-- Allocating Pack Space, After 'picking' (preparing and following)
INSERT INTO allocation_status_pack_space_allocation_time (prl_pack_space_allocation_time_id, allocation_status_id, is_pack_space_allocated)
    select (select id from prl_pack_space_allocation_time where
        name = 'allocating_pack_space'), allocation_status.id,
        false
    from allocation_status where allocation_status.status
        not in ('preparing', 'prepared', 'delivering', 'delivered', 'staged', 'picked');
INSERT INTO allocation_status_pack_space_allocation_time (prl_pack_space_allocation_time_id, allocation_status_id, is_pack_space_allocated)
    select (select id from prl_pack_space_allocation_time where
        name = 'allocating_pack_space'), allocation_status.id,
        true
    from allocation_status where allocation_status.status
        in ('preparing', 'prepared', 'delivering', 'delivered', 'staged', 'picked');



COMMIT;
