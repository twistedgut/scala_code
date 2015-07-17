BEGIN;

-- Deactivate these stages for this DC

UPDATE fulfilment_overview_stage SET is_active = FALSE WHERE stage in ('Awaiting Labelling', 'Not Displayed');

COMMIT;
