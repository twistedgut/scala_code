BEGIN;

alter table container
    add column pack_lane_id integer references pack_lane(pack_lane_id),
    add column routed_at timestamp with time zone,
    add column arrived_at timestamp with time zone,
    -- null explicitly allowed. has_arrived = false implies it's on its way to the lane
    -- has_arrived = true implies it has arrived at the lane and null implies its nowhere
    -- near the pack lane.
    add column has_arrived boolean;

create index idx_container_has_arrived_packlane on container(has_arrived,pack_lane_id);

comment on column container.has_arrived is 'has arrived is true if at pack lane after routing, false if enroute, or null if not related to pack lane';

COMMIT;
