
-- DCA-1864 - Rename Wall of Totes and Cached

BEGIN;



UPDATE runtime_property
    SET description = 'Count of how many additional Containers of staged Allocations can be inducted to the Pack Area'
    WHERE name = 'induction_capacity'
;


UPDATE allocation_status
    SET
        status      = 'staged',
        description = 'Picked allocations that need to be inducted to the pack-lane'
    WHERE status = 'cached'
;


UPDATE system_config.parameter
    SET name = 'staging_area_size'
    WHERE name = 'wall_of_totes_size'
;


COMMIT;
