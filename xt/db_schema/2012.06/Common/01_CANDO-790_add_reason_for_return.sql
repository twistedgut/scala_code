--CANDO-790: Add Reason for Return

BEGIN WORK;

-- Add a Uniqie Index
CREATE UNIQUE INDEX customer_issue_type_description_idx ON customer_issue_type(description);

-- make sure sequence is upto-date
SELECT setval('customer_issue_type_id_seq', max(id)) FROM customer_issue_type;

-- Insert the new return reasons
INSERT INTO customer_issue_type (group_id, description, pws_reason)
VALUES ( 
        (
            SELECT id  FROM customer_issue_type_group WHERE description = 'Return Reasons'
        ),
        'Item returned - No RMA',
        'UNWANTED'
        );

COMMIT WORK;
