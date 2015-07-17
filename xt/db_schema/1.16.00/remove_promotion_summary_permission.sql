-- This remove a permission that was used in the early stages of the project
-- but later deprecated

BEGIN WORK;

    DELETE FROM authorisation_sub_section
    WHERE id IN 
        (SELECT id 
            FROM authorisation_sub_section 
            WHERE authorisation_section_id IN 
                (SELECT id 
                    FROM authorisation_section 
                    WHERE section='Promotion'
            )
            AND sub_section='Summary'
        )
    ;


COMMIT;
