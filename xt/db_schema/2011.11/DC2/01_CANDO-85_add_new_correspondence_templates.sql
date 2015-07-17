-- CANDO-85: Add additonal templates to the 'correspondence_templates' table (DC2)

BEGIN WORK;

INSERT INTO
    correspondence_templates ( name, access, department_id, content )
VALUES
    ( 'Reimbursement-NAP-AM', 0, ( SELECT id FROM department WHERE department = 'Finance' ),
'Dear [% customer.first_name %]

Thank you for shopping at NET-A-PORTER.COM.

We''re sorry for the current delay in dispatching your shopping.

[% content %]

We know you will be anxious to receive your [% plural(order_count, ''order'', ''orders'') %] so once [% plural(order_count, ''it has'', ''they have'') %] been shipped, we''ll send you an email containing your air waybill number to track [% plural(order_count, ''its'', ''their'') %] progress.

As it''s taking longer than usual to send out your [% plural(order_count, ''package'', ''packages'') %], we will credit your NET-A-PORTER account with [% credit.amount %] [% credit.currency %]. This will automatically be deducted from the value of your purchase the next time you shop with us and you can redeem this at any time over the next 12 months.

In the meantime, thank you for your patience. 

Best regards,
Customer Care

For assistance 24 hours a day, seven days a week, call 1 877 6789 NAP (627) or email customercare.usa@net-a-porter.com'
    ),
    ( 'Reimbursement-MRP-AM', 0, ( SELECT id FROM department WHERE department = 'Finance' ),
'Dear [% customer.title %] [% customer.last_name %]

We are sorry for the current delay in dispatching your [% plural(order_count, ''order'', ''orders'') %].

[% content %]

We know you will be eager to receive your [% plural(order_count, ''order'', ''orders'') %] so once [% plural(order_count, ''it has'', ''they have'') %] been shipped, we will send you an email containing your air waybill number to track [% plural(order_count, ''its'', ''their'') %] progress.

As it is taking longer than usual to send out your [% plural(order_count, ''package'', ''packages'') %], we will credit your MR PORTER account with [% credit.amount %] [% credit.currency %]. This will automatically be deducted from the value of your purchase the next time you place an order with us and you can redeem this at any time over the next 12 months.

In the meantime, thank you for your patience. 

Yours sincerely,
Customer Care  

NEED ASSISTANCE? Simply email customercare.usa@mrporter.com or call +1 877 5353 MRP (677), 24 hours a day, seven days a week'
    ),
    ( 'Reimbursement-OUTNET-AM', 0, ( SELECT id FROM department WHERE department = 'Finance' ),
'Dear [% customer.first_name %]

Thank you for shopping at THE OUTNET, the most fashionable fashion outlet.

We''re sorry for the current delay in dispatching your [% plural(order_count, ''order'', ''orders'') %].

[% content %]

We know you’ll be anxious to receive your fabulous finds so once your [% plural(order_count, ''order'', ''orders'') %] [% plural(order_count, ''has'', ''have'') %] been shipped, we''ll send you an email containing your air waybill number to track [% plural(order_count, ''its'', ''their'') %] progress.

As it''s taking longer than usual to send out your [% plural(order_count, ''package'', ''packages'') %], we will credit your account at THE OUTNET with [% credit.amount %] [% credit.currency %]. This will automatically be deducted from the value of your purchase the next time you shop with us and you can redeem this at any time over the next 12 months.

In the meantime, thank you for your patience. 

Sincerely, 
Customer Care

We''re here to help you seven days a week! Call 1 888 9 OUTNET (688638) (8am-8pm EST weekdays, 9am-5.30pm EST weekends) or email customercare.usa@theoutnet.com'
    );

--ROLLBACK;
COMMIT;

/*
    Column     |          Type          | Notes
---------------+------------------------+-----------------------------------------------------------------------
 id            | integer                | - Exclude
 name          | character varying(255) | + Include
 operator_id   | bigint                 | ? Do we need to populate this (all existing ones are NULL)
 access        | smallint               | ? What's this used for
 content       | text                   | + Include
 department_id | integer                | + Include (finance)
 ordering      | integer                | ? What's this used for
*/

