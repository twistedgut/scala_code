
-- DCA-3481: GOH: create table
-- allocation_status_pack_space_allocation_time

BEGIN TRANSACTION;


CREATE TABLE allocation_status_pack_space_allocation_time (
    id                                SERIAL PRIMARY KEY,
    allocation_status_id              INTEGER NOT NULL REFERENCES allocation_status(id),
    prl_pack_space_allocation_time_id INTEGER NOT NULL REFERENCES prl_pack_space_allocation_time(id),
    is_pack_space_allocated           BOOLEAN  NOT NULL,
    CONSTRAINT unique_allocation_status_id_prl_pack_space_allocation_time_id
        UNIQUE (allocation_status_id, prl_pack_space_allocation_time_id)
);
ALTER TABLE allocation_status_pack_space_allocation_time OWNER to www;

COMMENT ON TABLE allocation_status_pack_space_allocation_time IS
'Link between an allocation_status and a
prl_pack_space_allocation_time, which models which statuses indicate
that pack space is allocated for a certain
prl_pack_space_allocation_time';

COMMENT ON COLUMN allocation_status_pack_space_allocation_time.is_pack_space_allocated IS
'Whether this status/pack_space_allocation_time combo indicates that
pack space is now allocated. The rows encode this table:

| pack_space_allocation_time | fulfilment_status      | Example PRL |
|----------------------------+------------------------+-------------|
| induction                  | picked                 | Full        |
| pick                       | picking, and following | DCD         |
| pick_complete              | after picking          | GOH         |

After picking = preparing/staged/picked and following.
';


COMMENT ON TABLE allocation_status IS
'
We don''t have workflows in XT, but the order is
| requested
| allocated
| picking
|\    (optional) [delivery]
| | preparing
| | prepared
| | delivering
| | delivered
|/
|\    (optional) [induction point]
| | staged
|/
| picked
';



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
        not in ('picking', 'preparing', 'prepared', 'delivering', 'delivered', 'staged', 'picked');
INSERT INTO allocation_status_pack_space_allocation_time (prl_pack_space_allocation_time_id, allocation_status_id, is_pack_space_allocated)
    select (select id from prl_pack_space_allocation_time where
        name = 'pick'), allocation_status.id,
        true
    from allocation_status where allocation_status.status
        in ('picking', 'preparing', 'prepared', 'delivering', 'delivered', 'staged', 'picked');

-- Pick Complete, After 'picking' (preparing and following)
INSERT INTO allocation_status_pack_space_allocation_time (prl_pack_space_allocation_time_id, allocation_status_id, is_pack_space_allocated)
    select (select id from prl_pack_space_allocation_time where
        name = 'pick_complete'), allocation_status.id,
        false
    from allocation_status where allocation_status.status
        not in ('preparing', 'prepared', 'delivering', 'delivered', 'staged', 'picked');
INSERT INTO allocation_status_pack_space_allocation_time (prl_pack_space_allocation_time_id, allocation_status_id, is_pack_space_allocated)
    select (select id from prl_pack_space_allocation_time where
        name = 'pick_complete'), allocation_status.id,
        true
    from allocation_status where allocation_status.status
        in ('preparing', 'prepared', 'delivering', 'delivered', 'staged', 'picked');



COMMIT;
