-- DCA-2357

BEGIN;
    -- Add sort_order and last_updated columns
    alter table runtime_property add column sort_order int;
    alter table runtime_property add column last_updated timestamp with time zone;

    -- Re-use the function created for WHM-811
    create trigger runtime_property_last_updated_tr before update on runtime_property
    for each row execute procedure last_updated_func();

    -- Update the description and sort order for the existing induction_capacity
    update runtime_property SET
        description = 'Number of containers at staging that we will currently allow to be inducted to packing',
        sort_order  = 100
        where name = 'induction_capacity';

    -- Add more runtime properties, for keeping track of pick scheduler variables
    select setval('runtime_property_id_seq', (select max(id) from runtime_property));
    insert into runtime_property (name, value, description, sort_order) values
        ( 'allocations_in_picking_full', '', 'Number of allocations being picked in the FW PRL (not pick_complete)', 10),
        ( 'containers_in_staging', '', 'Number of containers in the staging area from FW PRL (pick_complete)', 20),
        ( 'staging_capacity', '', 'Remaining staging capacity (Staging pool size - containers_in_staging - allocations_in_picking_full)', 30),
        ( 'totes_at_packing', '', 'Containers at packing + Containers en-route', 40),
        ( 'allocations_in_picking_dms', '', 'Number of allocations being picked in DMS (not pick_complete)', 50),
        ( 'packing_capacity', '', 'Remaining tote capacity at packing (Packing pool size – totes_at_packing - allocations_in_picking_dms)', 60)
    ;
COMMIT;
