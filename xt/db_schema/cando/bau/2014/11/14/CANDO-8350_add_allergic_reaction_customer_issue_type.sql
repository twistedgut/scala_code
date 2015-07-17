--
-- CANDO-8350: Add "Allergic Reaction" customer_issue_type
--


BEGIN WORK;

INSERT INTO customer_issue_type (
    group_id,
    description,
    pws_reason
)
VALUES (
    (SELECT id FROM customer_issue_type_group WHERE description = 'Return Reasons' ),
    'Allergic Reaction',
    'ALLERGIC_REACTION'
);

COMMIT WORK;
