-- Remove obsolete view

BEGIN;
    DROP VIEW IF EXISTS vw_rtv_workstation_stock;
COMMIT;
