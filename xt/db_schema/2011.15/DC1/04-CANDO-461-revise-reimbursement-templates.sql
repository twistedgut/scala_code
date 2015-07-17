--
-- CANDO-461
--

BEGIN TRANSACTION;

DELETE
  FROM correspondence_templates
 WHERE name IN (
         'Reimbursement-NAP-INTL',
         'Reimbursement-MRP-INTL',
         'Reimbursement-OUTNET-INTL'
       )
     ;

INSERT INTO
    correspondence_templates ( name, access, department_id, content )
VALUES
    ( 'Reimbursement-NAP-INTL', 0, ( SELECT id FROM department WHERE department = 'Finance' ),
'Dear [% customer.first_name %],

Thank you for shopping at NET-A-PORTER.COM.

[% content %]

We will shortly be crediting your NET-A-PORTER account with [% credit.amount %] [% credit.currency %] to compensate for this inconvenience. This amount will be deducted automatically from the value of your purchase the next time you shop with us, and you can redeem this at any time over the next 12 months.

Thank you for your patience.  If we can be of further assistance, please don''t hesitate to contact us.

Kind regards,
Customer Care

For assistance 24 hours a day, seven days a week, call 0800 044 5700 from the UK, +44 (0)20 3471 4510 from the rest of the world or email customercare@net-a-porter.com'
    ),
    ( 'Reimbursement-MRP-INTL', 0, ( SELECT id FROM department WHERE department = 'Finance' ),
'Dear [% customer.title %] [% customer.last_name %],

Thank you for shopping at MRPORTER.COM.

[% content %]

We will shortly be crediting your MR PORTER account with [% credit.amount %] [% credit.currency %] to compensate for this inconvenience. This amount will be deducted automatically from the value of your purchase the next time you place an order with us, and you can redeem this at any time over the next 12 months.

Thank you for your patience.  If we can be of further assistance, please do not hesitate to contact us.

Yours sincerely,
Customer Care

NEED ASSISTANCE? Simply email customercare@mrporter.com or call 0800 044 5705 from the UK, +44 (0)20 3471 4090 from the rest of the world, 24 hours a day, seven days a week'
    ),
    ( 'Reimbursement-OUTNET-INTL', 0, ( SELECT id FROM department WHERE department = 'Finance' ),
'Dear [% customer.first_name %],

Thank you for shopping at THE OUTNET, the most fashionable fashion outlet.

[% content %]

We will shortly be crediting your account at THE OUTNET with [% credit.amount %] [% credit.currency %] to compensate for this inconvenience.  This amount will be deducted automatically from the value of your purchase the next time you shop with us, and you can redeem this at any time over the next 12 months.

Thank you for your patience.  If we can be of further assistance, please don''t hesitate to contact us.

Kind regards,
Customer Care

We''re here to help 24 hours a day, seven days a week! Call 0800 011 4250 from the UK, +44 (0)20 3471 4777 from the rest of the world or email customercare@theoutnet.com'
    );



COMMIT WORK;
