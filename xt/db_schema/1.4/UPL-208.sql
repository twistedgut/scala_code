-- This patch file addresses UPL-208; http://animal/browse/UPL-208
--
-- New Status "has been retouched but not colour corrected" required

BEGIN;

    -- new state: IN_COLOUR_CORRECTION
    INSERT INTO photography.image_status
        (status, display_colour, description, icon)
        VALUES
        (   'IN_COLOUR_CORRECTION',
            '#3D9140',
            'Shot Needs Colour Correction',
            '/images/icons/rainbow.png'
        )
    ;

    -- NEEDS RETOUCHING --> IN_COLOUR_CORRECTION (operator)
    INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
    VALUES (
        (SELECT id FROM photography.image_status   WHERE status='RETOUCH'),
        (SELECT id FROM photography.image_status   WHERE status='IN_COLOUR_CORRECTION'),
        (SELECT id FROM public.authorisation_level WHERE description='Operator')
    );
    -- NEEDS RETOUCHING --> IN_COLOUR_CORRECTION (manager)
    INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
    VALUES (
        (SELECT id FROM photography.image_status   WHERE status='RETOUCH'),
        (SELECT id FROM photography.image_status   WHERE status='IN_COLOUR_CORRECTION'),
        (SELECT id FROM public.authorisation_level WHERE description='Manager')
    );

    -- IN_COLOUR_CORRECTION --> RETOUCHED (operator)
    INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
    VALUES (
        (SELECT id FROM photography.image_status   WHERE status='IN_COLOUR_CORRECTION'),
        (SELECT id FROM photography.image_status   WHERE status='RETOUCHED'),
        (SELECT id FROM public.authorisation_level WHERE description='Operator')
    );
    -- IN_COLOUR_CORRECTION --> RETOUCHED (manager)
    INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
    VALUES (
        (SELECT id FROM photography.image_status   WHERE status='IN_COLOUR_CORRECTION'),
        (SELECT id FROM photography.image_status   WHERE status='RETOUCHED'),
        (SELECT id FROM public.authorisation_level WHERE description='Manager')
    );

    -- IN_COLOUR_CORRECTION --> UPLOADED (operator)
    INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
    VALUES (
        (SELECT id FROM photography.image_status   WHERE status='IN_COLOUR_CORRECTION'),
        (SELECT id FROM photography.image_status   WHERE status='UPLOADED'),
        (SELECT id FROM public.authorisation_level WHERE description='Operator')
    );
    -- IN_COLOUR_CORRECTION --> UPLOADED (manager)
    INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
    VALUES (
        (SELECT id FROM photography.image_status   WHERE status='IN_COLOUR_CORRECTION'),
        (SELECT id FROM photography.image_status   WHERE status='UPLOADED'),
        (SELECT id FROM public.authorisation_level WHERE description='Manager')
    );

COMMIT;
