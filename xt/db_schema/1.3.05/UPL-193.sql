-- UPL-193 - Reset Image required from (Provisional) approval Status

BEGIN;

    -- APPROVED --> REJECTED (manager)
    INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
    VALUES (
        (SELECT id FROM photography.image_status   WHERE status='APPROVED'),
        (SELECT id FROM photography.image_status   WHERE status='REJECTED'),
        (SELECT id FROM public.authorisation_level WHERE description='Manager')
    );

COMMIT;
