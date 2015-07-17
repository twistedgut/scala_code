BEGIN;

DELETE FROM dbadmin.applied_patch
WHERE NOT succeeded
AND basename IN (
'070-dca-2996-add-pi-cycle-count-tables.sql',
'071-dca-3024-add-new-pi-resolution.sql',
'090-dca3025-add_pi_location_view.sql',
'091-add-modified-trigger.sql',
'092-dca-3114-add-dates-to-location.sql',
'091-dca3025-add-indexes.sql'
);

COMMIT;
