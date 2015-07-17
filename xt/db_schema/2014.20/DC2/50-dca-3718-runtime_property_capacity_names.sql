
--
-- DCA-3718 - picking overview missing DCD picking remaining capacity
--

BEGIN;



update runtime_property
    set description = 'How many more allocations can still be assigned to the Full PRL'
    where name = 'full_picking_remaining_capacity'
;
update runtime_property
    set description = 'How many more allocations can still be assigned to the DCD PRL'
    where name = 'dcd_picking_remaining_capacity'
;
update runtime_property
    set description = 'How many more allocations can still be assigned to the GOH PRL'
    where name = 'goh_picking_remaining_capacity'
;

update runtime_property
    set sort_order = 20
    where name = 'induction_capacity'
;



COMMIT;
