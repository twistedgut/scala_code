BEGIN;

delete from stock_process
where group_id in (
    2300017, 2300119, 2389808, 2389868, 2389957, 2390006, 2390010, 2390012,
    2390014, 2449069, 2495000, 2297491, 2297493
) -- list from spreadsheet in request DCOP-570
and type_id=3 -- surplus
;

COMMIT;
