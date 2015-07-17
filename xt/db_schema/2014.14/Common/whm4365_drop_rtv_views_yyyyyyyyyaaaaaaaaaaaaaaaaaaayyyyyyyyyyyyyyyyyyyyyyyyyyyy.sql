-- Drop a nasty old rtv view

BEGIN;
    DROP VIEW IF EXISTS vw_rtv_inspection_validate_pick, vw_rtv_inspection_list;
COMMIT;
