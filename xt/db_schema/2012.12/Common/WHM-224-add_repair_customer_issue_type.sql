-- Add new 'Repair' customer issue type (return reason)

BEGIN WORK;

    INSERT INTO customer_issue_type( group_id, description, pws_reason )
        VALUES (
            ( SELECT id FROM customer_issue_type_group WHERE description = 'Return Reasons' ),
            'Return for Repair',
            'DEFECTIVE'
        );

COMMIT;
