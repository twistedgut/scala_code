-- this fixes a stupid stupid stupid typo
BEGIN;
    UPDATE photography.image_next_state
    SET current_state_id = (SELECT id FROM photography.image_status WHERE status='IN_RETOUCHING')
    WHERE current_state_id IS NULL;

    ALTER TABLE photography.image_next_state ALTER COLUMN current_state_id SET NOT NULL;
    ALTER TABLE photography.image_next_state ALTER COLUMN next_state_id SET NOT NULL;
COMMIT;
