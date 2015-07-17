-- new states and transitions are required for the photography worklist
-- project

BEGIN;

    -- prevent duplicate states
    ALTER TABLE photography.image_next_state
    ADD UNIQUE(current_state_id, next_state_id,authorisation_level)
    ;

    -- UPL-122 : Retouchers require an undo action
    --
    -- UPLOADED / RETOUCHED --> NEEDS RETOUCHING

    -- UPLOADED --> RETOUCH (operator)
    INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
    VALUES (
        (SELECT id FROM photography.image_status   WHERE status='UPLOADED'),
        (SELECT id FROM photography.image_status   WHERE status='RETOUCH'),
        (SELECT id FROM public.authorisation_level WHERE description='Operator')
    );
    -- UPLOADED --> RETOUCH (manager)
    INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
    VALUES (
        (SELECT id FROM photography.image_status   WHERE status='UPLOADED'),
        (SELECT id FROM photography.image_status   WHERE status='RETOUCH'),
        (SELECT id FROM public.authorisation_level WHERE description='Manager')
    );

    -- RETOUCHED --> RETOUCH (operator)
    INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
    VALUES (
        (SELECT id FROM photography.image_status   WHERE status='RETOUCHED'),
        (SELECT id FROM photography.image_status   WHERE status='RETOUCH'),
        (SELECT id FROM public.authorisation_level WHERE description='Operator')
    );
    -- RETOUCHED --> RETOUCH (manager)
    INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
    VALUES (
        (SELECT id FROM photography.image_status   WHERE status='RETOUCHED'),
        (SELECT id FROM photography.image_status   WHERE status='RETOUCH'),
        (SELECT id FROM public.authorisation_level WHERE description='Manager')
    );



    -- UPL-147 : Reset Image required from Final approval Status
    --
    -- New Status Rejected
    -- Final Approval --> Rejected
    -- Rejected --> Reshoot, Rejected --> Retouch

    -- New Status REJECTED
    INSERT INTO photography.image_status
        (status, display_colour, description, icon)
        VALUES
        (   'REJECTED',
            '#000000',
            'Image Rejected',
            '/images/icons/delete.png'
        )
    ;

    -- FINAL_APPROVAL --> REJECTED (manager)
    INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
    VALUES (
        (SELECT id FROM photography.image_status   WHERE status='FINAL_APPROVAL'),
        (SELECT id FROM photography.image_status   WHERE status='REJECTED'),
        (SELECT id FROM public.authorisation_level WHERE description='Manager')
    );

    -- REJECTED --> AMEND_RESHOOT
    INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
    VALUES (
        (SELECT id FROM photography.image_status   WHERE status='REJECTED'),
        (SELECT id FROM photography.image_status   WHERE status='AMEND_RESHOOT'),
        (SELECT id FROM public.authorisation_level WHERE description='Manager')
    );

    -- REJECTED --> AMEND_RETOUCH
    INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
    VALUES (
        (SELECT id FROM photography.image_status   WHERE status='REJECTED'),
        (SELECT id FROM photography.image_status   WHERE status='AMEND_RETOUCH'),
        (SELECT id FROM public.authorisation_level WHERE description='Manager')
    );


    -- UPL-150 : Missing image status should allow Recheck, Reshoot or Retouch to be selected
    --           [Currently only has "Need Retouching"]
    --
    -- IMAGE_MISSING --> RECHECK, IMAGE_MISSING --> RETOUCH

    -- IMAGE_MISSING -> RECHECK (operator)
    INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
    VALUES (
        (SELECT id FROM photography.image_status   WHERE status='IMAGE_MISSING'),
        (SELECT id FROM photography.image_status   WHERE status='RECHECK'),
        (SELECT id FROM public.authorisation_level WHERE description='Operator')
    );

    -- IMAGE_MISSING -> RECHECK (manager)
    INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
    VALUES (
        (SELECT id FROM photography.image_status   WHERE status='IMAGE_MISSING'),
        (SELECT id FROM photography.image_status   WHERE status='RECHECK'),
        (SELECT id FROM public.authorisation_level WHERE description='Manager')
    );

    -- IMAGE_MISSING -> RESHOOT (operator)
    INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
    VALUES (
        (SELECT id FROM photography.image_status   WHERE status='IMAGE_MISSING'),
        (SELECT id FROM photography.image_status   WHERE status='RESHOOT'),
        (SELECT id FROM public.authorisation_level WHERE description='Operator')
    );

    -- IMAGE_MISSING -> RESHOOT (manager)
    INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
    VALUES (
        (SELECT id FROM photography.image_status   WHERE status='IMAGE_MISSING'),
        (SELECT id FROM photography.image_status   WHERE status='RESHOOT'),
        (SELECT id FROM public.authorisation_level WHERE description='Manager')
    );



    -- UPL-177 : Reshoot Status actions need to be 'Needs Checking', 'Retouching' or 'Image Missing'
    --           [Currently only has "Needs Rechecking"]
    --
    -- RESHOOT --> RETOUCH, RESHOOT --> IMAGE_MISSING

    -- RESHOOT --> RETOUCH (operator)
    INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
    VALUES (
        (SELECT id FROM photography.image_status   WHERE status='RESHOOT'),
        (SELECT id FROM photography.image_status   WHERE status='RETOUCH'),
        (SELECT id FROM public.authorisation_level WHERE description='Operator')
    );

    -- RESHOOT --> RETOUCH (manager)
    INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
    VALUES (
        (SELECT id FROM photography.image_status   WHERE status='RESHOOT'),
        (SELECT id FROM photography.image_status   WHERE status='RETOUCH'),
        (SELECT id FROM public.authorisation_level WHERE description='Manager')
    );

    -- RESHOOT --> IMAGE_MISSING (operator)
    INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
    VALUES (
        (SELECT id FROM photography.image_status   WHERE status='RESHOOT'),
        (SELECT id FROM photography.image_status   WHERE status='IMAGE_MISSING'),
        (SELECT id FROM public.authorisation_level WHERE description='Operator')
    );

    -- RESHOOT --> IMAGE_MISSING (manager)
    INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
    VALUES (
        (SELECT id FROM photography.image_status   WHERE status='RESHOOT'),
        (SELECT id FROM photography.image_status   WHERE status='IMAGE_MISSING'),
        (SELECT id FROM public.authorisation_level WHERE description='Manager')
    );


    -- Make state transition names more helpful
    UPDATE photography.image_status
    SET    description='Shot needs re-shooting (Amend)'
    WHERE  status='AMEND_RESHOOT';

    UPDATE photography.image_status
    SET    description='Shot needs re-touching (Amend)'
    WHERE  status='AMEND_RETOUCH';
COMMIT;
