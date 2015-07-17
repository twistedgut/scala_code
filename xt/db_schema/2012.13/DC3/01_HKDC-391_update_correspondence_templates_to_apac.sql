-- HKDC-391: Cannot execute bulk reimbursements, email missing.

BEGIN WORK;

UPDATE  correspondence_templates
SET     name = 'Reimbursement-OUTNET-APAC'
WHERE   name = 'Reimbursement-OUTNET-AM';

UPDATE  correspondence_templates
SET     name = 'Reimbursement-MRP-APAC'
WHERE   name = 'Reimbursement-MRP-AM';

UPDATE  correspondence_templates
SET     name = 'Reimbursement-NAP-APAC'
WHERE   name = 'Reimbursement-NAP-AM';

UPDATE  correspondence_templates
SET     name = 'Dispatch-SLA-Breach-NAP-APAC-NonSale'
WHERE   name = 'Dispatch-SLA-Breach-NAP-AM-NonSale';

UPDATE  correspondence_templates
SET     name = 'Dispatch-SLA-Breach-NAP-APAC-Sale'
WHERE   name = 'Dispatch-SLA-Breach-NAP-AM-Sale';

UPDATE  correspondence_templates
SET     name = 'Dispatch-SLA-Breach-OUTNET-APAC-NonSale'
WHERE   name = 'Dispatch-SLA-Breach-OUTNET-AM-NonSale';

UPDATE  correspondence_templates
SET     name = 'Dispatch-SLA-Breach-OUTNET-APAC-Sale'
WHERE   name = 'Dispatch-SLA-Breach-OUTNET-AM-Sale';

UPDATE  correspondence_templates
SET     name = 'ReturnsQC-SLA-Breach-NAP-APAC'
WHERE   name = 'ReturnsQC-SLA-Breach-NAP-AM';

UPDATE  correspondence_templates
SET     name = 'ReturnsQC-SLA-Breach-OUTNET-APAC'
WHERE   name = 'ReturnsQC-SLA-Breach-OUTNET-AM';

UPDATE  correspondence_templates
SET     name = 'Reservation Notification-MRP-APAC'
WHERE   name = 'Reservation Notification-MRP-AM';

UPDATE  correspondence_templates
SET     name = 'Reservation Notification-NAP-APAC'
WHERE   name = 'Reservation Notification-NAP-AM';

UPDATE  correspondence_templates
SET     name = 'Reservation Notification-OUTNET-APAC'
WHERE   name = 'Reservation Notification-OUTNET-AM';

UPDATE  correspondence_templates
SET     name = 'Reservation Notification - Product Advisors-NAP-APAC'
WHERE   name = 'Reservation Notification - Product Advisors-NAP-AM';

UPDATE  correspondence_templates
SET     name = 'Reservation Notification - Product Advisors-OUTNET-APAC'
WHERE   name = 'Reservation Notification - Product Advisors-OUTNET-AM';

COMMIT;
