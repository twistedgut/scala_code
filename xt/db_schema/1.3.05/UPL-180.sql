-- UPL-180 : 'Being Retouched' action needs to follow the 'Needs Retouching' Status

BEGIN;

    -- RETOUCH --> IN_RETOUCHING (operator)
    INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
    VALUES (
        (SELECT id FROM photography.image_status   WHERE status='RETOUCH'),
        (SELECT id FROM photography.image_status   WHERE status='IN_RETOUCHING'),
        (SELECT id FROM public.authorisation_level WHERE description='Operator')
    );

    -- RETOUCH --> IN_RETOUCHING (manager)
    INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
    VALUES (
        (SELECT id FROM photography.image_status   WHERE status='RETOUCH'),
        (SELECT id FROM photography.image_status   WHERE status='IN_RETOUCHING'),
        (SELECT id FROM public.authorisation_level WHERE description='Manager')
    );

COMMIT;
