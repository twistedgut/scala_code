BEGIN;

-- Deactivate this stage for this DC

UPDATE fulfilment_overview_stage SET is_active = FALSE WHERE stage = 'Not Displayed';

COMMIT;
