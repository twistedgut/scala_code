-- This patch file addresses UPL-223; http://animal/browse/UPL-223
--
-- new transition: "image being retouched" ==> "shot requires colour correction"

BEGIN;

    -- IN_RETOUCHING --> IN_COLOUR_CORRECTION (operator)
    INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
    VALUES (
        (SELECT id FROM photography.image_status   WHERE status='IN_RETOUCHING'),
        (SELECT id FROM photography.image_status   WHERE status='IN_COLOUR_CORRECTION'),
        (SELECT id FROM public.authorisation_level WHERE description='Operator')
    );
    -- IN_RETOUCHING --> IN_COLOUR_CORRECTION (manager)
    INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
    VALUES (
        (SELECT id FROM photography.image_status   WHERE status='IN_RETOUCHING'),
        (SELECT id FROM photography.image_status   WHERE status='IN_COLOUR_CORRECTION'),
        (SELECT id FROM public.authorisation_level WHERE description='Manager')
    );

COMMIT;
