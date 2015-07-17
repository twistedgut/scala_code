--
-- CANDO-1723: Add 'Order Placed on Wrong Site' to cancel_reason list
--

BEGIN WORK;

INSERT INTO customer_issue_type ( description, group_id ) VALUES (
    'Order placed on wrong site',
    (select id from customer_issue_type_group where description = 'Cancellation Reasons')
);

COMMIT WORK;
