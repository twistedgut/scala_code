BEGIN;
--------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------
--                  Fix sequence before insertion
-------------------------------------------------------------------------
select setval('public.correspondence_templates_id_seq',(select max(id) from public.correspondence_templates));
--------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------
--                  NAP INTL email templates Despatch SLA
-------------------------------------------------------------------------
insert into public.correspondence_templates
(access,name,content) VALUES
(0,'Dispatch-SLA-Breach-NAP-INTL-NonSale',
'Dear [% customer_email %],

We\'re sorry it is taking longer than usual to dispatch your purchase and would like to assure you that your items will be with you as soon as possible.

Once your package has been dispatched we\'ll send you an email with your air waybill number so you can track its progess.

Please let us know if we can assist you further.

Kind regards,
Customer Care

For assistance 24 hours a day, seven days a week, call 08456 751 321 from the UK, +44 (0)203 471 4510 from the rest of the world or email customercare@net-a-porter.com');
insert into public.correspondence_templates
(access,name,content) VALUES
(0,'Dispatch-SLA-Breach-NAP-INTL-Sale',
'Dear [% customer_name %],

We\'re sorry it is taking longer than usual to dispatch your recent purchase in our sale and would like to assure you that your items will be with you as soon as possible.

Once your package has been dispatched we\'ll send you an email with your air waybill number so you can track its progress.

Please let us know if we can assist you further. 

Kind regards, 
Customer Care

For assistance 24 hours a day, seven days a week, call 08456 751 321 from the UK, +44 (0)203 471 4510 from the rest of the world or email customercare@net-a-porter.com'); 
-------------------------------------------------------------------------
--                  NAP AM email templates Despatch SLA
------------------------------------------------------------------------- 
insert into public.correspondence_templates
(access,name,content) VALUES
(0,'Dispatch-SLA-Breach-NAP-AM-NonSale',
'Dear [% customer_email %],

We\'re sorry it is taking longer than usual to dispatch your purchase and would like to assure you that your items will be with you as soon as possible. 

Once your package has been dispatched we\'ll send you an email with your air waybill number so you can track its progress.

Please let us know if we can assist you further. 

Best regards, 
Customer Care

For assistance 24 hours a day, seven days a week, call 1 800 481 1064 or email customercare.usa@net-a-porter.com');
insert into public.correspondence_templates
(access,name,content) VALUES
(0,'Dispatch-SLA-Breach-NAP-AM-Sale',
'Dear [% customer_name %],

We\'re sorry it is taking longer than usual to dispatch your recent purchase in our sale and would like to assure you that your items will be with you as soon as possible.

Once your package has been dispatched we\'ll send you an email with your air waybill number so you can track its progress.

Please let us know if we can assist you further. 

Best regards, 
Customer Care

For assistance 24 hours a day, seven days a week, call 1 800 481 1064 or email customercare.usa@net-a-porter.com'); 
-------------------------------------------------------------------------
--                  NAP INTL email template Returns QC SLA
-------------------------------------------------------------------------
insert into public.correspondence_templates
(access,name,content) VALUES
(0,'ReturnsQC-SLA-Breach-NAP-INTL',
'Dear [% customer_name %],

We\'re sorry it is taking longer than usual to process your return. We are working 
as quickly as we can and would like to assure you that this will be completed as soon as 
possible.

Once your refund or exchange has progressed, we\'ll notify you by email. 

Please let us know if we can assist you further. 

Kind regards, 
Customer Care

For assistance 24 hours a day, seven days a week, call 08456 751 321 from the UK, +44 (0)203 471 4510 from the rest of the world or email customercare@net-a-porter.com'); 
-------------------------------------------------------------------------
--                  NAP AM email template Returns QC SLA
-------------------------------------------------------------------------
insert into public.correspondence_templates
(access,name,content) VALUES
(0,'ReturnsQC-SLA-Breach-NAP-AM',
'Dear [% customer_name %],

We\'re sorry it is taking longer than usual to process your return. We are working as quickly as we can and would like to assure you that this will be completed as soon as possible.

Once your refund or exchange has progressed, we\'ll notify you by email. 

Please let us know if we can assist you further. 

Best regards, 
Customer Care

For assistance 24 hours a day, seven days a week, call 1 800 481 1064 or email customercare.usa@net-a-porter.com');  
--------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------
--                  OUT INTL email templates Despatch SLA
-------------------------------------------------------------------------
insert into public.correspondence_templates
(access,name,content) VALUES
(0,'Dispatch-SLA-Breach-OUTNET-INTL-NonSale',
'Dear [% customer_name %],
 
At theOutnet.com, we always aim to dispatch customers\' orders within 48 hours. We\'re sorry it\'s taking longer than usual this time – we\'re working as quickly as we can to get your items to you as soon as possible. 
 
Once your package has been dispatched, we\’ll send you an email with your air waybill number so you can track its progress.

If we can help you further, please let us know.
    
Kind regards,
The Service Team

We\'re here to help seven days a week! Call 0800 011 4250 from the UK, +44 (0)203 471 4777 from the rest of the world (8am-8pm GMT weekdays, 9am-5pm GMT weekends) or email serviceteam@theOutnet.com');
insert into public.correspondence_templates
(access,name,content) VALUES
(0,'Dispatch-SLA-Breach-OUTNET-INTL-Sale',
'Dear [% customer_name %],
 
At theOutnet.com, we always aim to dispatch customers\' orders within 48 hours. We\'re sorry it\'s taking longer than usual this time – we\'re working as quickly as we can to get your items to you as soon as possible. 
 
Once your package has been dispatched, we\’ll send you an email with your air waybill number so you can track its progress.

If we can help you further, please let us know.
        
Kind regards,
The Service Team
    
We\'re here to help seven days a week! Call 0800 011 4250 from the UK, +44 (0)203 471 4777 from the rest of the world (8am-8pm GMT weekdays, 9am-5pm GMT weekends) or email serviceteam@theOutnet.com');
-------------------------------------------------------------------------
--                  OUT AM email templates Despatch SLA
-------------------------------------------------------------------------  
insert into public.correspondence_templates
(access,name,content) VALUES
(0,'Dispatch-SLA-Breach-OUTNET-AM-NonSale',
'Dear [% customer_email %],

At theOutnet.com, we always aim to dispatch customers\' orders within 48 hours. We\'re sorry it\'s taking longer than usual this time – we\'re working as quickly as we can to get your items to you as soon as possible. 
 
Once your package has been dispatched, we’ll send you an email with your air waybill number so you can track its progress.

If we can help you further, please let us know.
    
Sincerely, 
The Service Team

We\'re here to help you seven days a week! Call 1 866 785 8246 (8am-8pm EST weekdays, 9am-5.30pm EST weekends) or email serviceteam.usa@theoutnet.com');
insert into public.correspondence_templates
(access,name,content) VALUES
(0,'Dispatch-SLA-Breach-OUTNET-AM-Sale',
'Dear [% customer_email %],

At theOutnet.com, we always aim to dispatch customers\' orders within 48 hours. We\'re sorry it\'s taking longer than usual this time – we\'re working as quickly as we can to get your items to you as soon as possible. 
 
Once your package has been dispatched, we’ll send you an email with your air waybill number so you can track its progress.

If we can help you further, please let us know.
    
Sincerely, 
The Service Team

We\'re here to help you seven days a week! Call 1 866 785 8246 (8am-8pm EST weekdays, 9am-5.30pm EST weekends) or email serviceteam.usa@theoutnet.com'); 
-------------------------------------------------------------------------
--                  OUT INTL email template Returns In SLA
-------------------------------------------------------------------------
insert into public.correspondence_templates
(access,name,content) VALUES
(0,'ReturnsQC-SLA-Breach-OUTNET-INTL',
'Dear [% customer_name %],

We\'re sorry it is taking longer than usual to process your returns. We hope this doesn\'t cause you too much inconvenience.
 
Please be assured that we\'re working as quickly as we can and will update you on the status of your refund or exchange as soon as this is complete.

If we can help you further, please let us know.

Kind regards,
The Service Team

We\'re here to help seven days a week! Call 0800 011 4250 from the UK, +44 (0)203 471 4777 from the rest of the world (8am-8pm GMT weekdays, 9am-5pm GMT weekends) or email serviceteam@theOutnet.com');
-------------------------------------------------------------------------
--                  OUT AM email template Returns In SLA
-------------------------------------------------------------------------
insert into public.correspondence_templates
(access,name,content) VALUES
(0,'ReturnsQC-SLA-Breach-OUTNET-AM',
'Dear [% customer_name %],

We\'re sorry it is taking longer than usual to process your returns. We hope this doesn\'t cause you too much inconvenience.
 
Please be assured that we\'re working as quickly as we can and will update you on the status of your refund or exchange as soon as this is complete.

If we can help you further, please let us know.
    
Sincerely,
The Service Team

We\'re here to help you seven days a week! Call 1 866 785 8246 (8am-8pm EST weekdays, 9am-5.30pm EST weekends) or email serviceteam.usa@theoutnet.com');  
--------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------
COMMIT;
