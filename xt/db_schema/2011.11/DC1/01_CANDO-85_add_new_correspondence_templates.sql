-- CANDO-85: Add additonal templates to the 'correspondence_templates' table (DC1)

BEGIN WORK;

INSERT INTO
    correspondence_templates ( name, access, department_id, content )
VALUES
    ( 'Reimbursement-NAP-INTL', 0, ( SELECT id FROM department WHERE department = 'Finance' ),
'Dear [% customer.first_name %]

Thank you for shopping at NET-A-PORTER.COM.

We''re sorry for the current delay in dispatching your shopping.

[% content %]

We know you will be anxious to receive your [% plural(order_count, ''order'', ''orders'') %] so once [% plural(order_count, ''it has'', ''they have'') %] been shipped, we''ll send you an email containing your air waybill number to track [% plural(order_count, ''its'', ''their'') %] progress.

As it''s taking longer than usual to send out your [% plural(order_count, ''package'', ''packages'') %], we will credit your NET-A-PORTER account with [% credit.amount %] [% credit.currency %]. This will automatically be deducted from the value of your purchase the next time you shop with us and you can redeem this at any time over the next 12 months.

In the meantime, thank you for your patience. 

Kind regards,
Customer Care

For assistance 24 hours a day, seven days a week, call 0800 044 5700 from the UK, +44 (0)20 3471 4510 from the rest of the world or email customercare@net-a-porter.com'
    ),
    ( 'Reimbursement-MRP-INTL', 0, ( SELECT id FROM department WHERE department = 'Finance' ),
'Dear [% customer.title %] [% customer.last_name %]

We are sorry for the current delay in dispatching your [% plural(order_count, ''order'', ''orders'') %].

[% content %]

We know you will be eager to receive your [% plural(order_count, ''order'', ''orders'') %] so once [% plural(order_count, ''it has'', ''they have'') %] been shipped, we will send you an email containing your air waybill number to track [% plural(order_count, ''its'', ''their'') %] progress.

As it is taking longer than usual to send out your [% plural(order_count, ''package'', ''packages'') %], we will credit your MR PORTER account with [% credit.amount %] [% credit.currency %]. This will automatically be deducted from the value of your purchase the next time you place an order with us and you can redeem this at any time over the next 12 months.

In the meantime, thank you for your patience. 

Yours sincerely,
Customer Care  

NEED ASSISTANCE? Simply email customercare@mrporter.com or call 0800 044 5705 from the UK, +44 (0)20 3471 4090 from the rest of the world, 24 hours a day, seven days a week'
    ),
    ( 'Reimbursement-OUTNET-INTL', 0, ( SELECT id FROM department WHERE department = 'Finance' ),
'Dear [% customer.first_name %]

Thank you for shopping at THE OUTNET, the most fashionable fashion outlet.

We''re sorry for the current delay in dispatching your [% plural(order_count, ''order'', ''orders'') %].

[% content %]

We know you’ll be anxious to receive your fabulous finds so once your [% plural(order_count, ''order'', ''orders'') %] [% plural(order_count, ''has'', ''have'') %] been shipped, we''ll send you an email containing your air waybill number to track [% plural(order_count, ''its'', ''their'') %] progress.

As it''s taking longer than usual to send out your [% plural(order_count, ''package'', ''packages'') %], we will credit your account at THE OUTNET with [% credit.amount %] [% credit.currency %]. This will automatically be deducted from the value of your purchase the next time you shop with us and you can redeem this at any time over the next 12 months.

In the meantime, thank you for your patience. 

Kind regards,
Customer Care

We''re here to help seven days a week! Call 0800 011 4250 from the UK, +44 (0)20 3471 4777 from the rest of the world (8am-8pm GMT weekdays, 9am-5pm GMT weekends) or email customercare@theoutnet.com'
    );

--ROLLBACK;
COMMIT;

