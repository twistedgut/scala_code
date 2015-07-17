BEGIN;


update correspondence_templates set content = replace(content, 'http://www.net-a-porter.com', '[% channel.url %]');

update correspondence_templates set content = replace(content, 'www.net-a-porter.com', '[% channel.url %]');

update correspondence_templates set content = replace(content, 'customercare@net-a-porter.com', '[% customercare_email %]');
update correspondence_templates set content = replace(content, 'customercare.usa@net-a-porter.com', '[% customercare_email %]');

update correspondence_templates set content = replace(content, 'returns@net-a-porter.com', '[% returns_email %]');
update correspondence_templates set content = replace(content, 'returns.usa@net-a-porter.com', '[% returns_email %]');

update correspondence_templates set content = replace(content, 'shipping@net-a-porter.com', '[% shipping_email %]');
update correspondence_templates set content = replace(content, 'shipping.usa@net-a-porter.com', '[% shipping_email %]');

update correspondence_templates set content = replace(content, 'NET-A-PORTER.COM', '[% channel.business %]');

update correspondence_templates set content = replace(content, 'NET-A-PORTER', '[% channel.business %]');


-- change Customer Care sign off to channel variable
update correspondence_templates set content = replace(content, 'Customer Care', '[% channel.email_signoff %]');

-- DC1 CREATE RETURN

update correspondence_templates set content = replace(content, 
'Then book your free collection with DHL, quoting our account number: [% IF shipment_info.shipment_type_id < 4 %]135469417[% ELSE %]961504478[% END %]. To find the telephone number of DHL, visit www.dhl.com and select your country. Please ensure your [% IF num_return_items > 1 %]items are[% ELSE %]item is[% END %] returned to us within 14 days of receiving this email.', 
'[% IF shipment_info.carrier == "DHL Ground" %]DHL will then call you direct to arrange your free collection on a convenient day.[% ELSE %]Then book your free collection with DHL, quoting our account number: [% IF shipment_info.shipment_type_id < 4 %]135469417[% ELSE %]961504478[% END %]. To find the telephone number of DHL, visit www.dhl.com and select your country. Please ensure your [% IF num_return_items > 1 %]items are[% ELSE %]item is[% END %] returned to us within 14 days of receiving this email.[% END %]'
);  

-- DC1 CONVERT TO EX

update correspondence_templates set content = replace(content, 
'Then book your free collection with DHL, quoting our account number: [% IF shipment_info.shipment_type_id < 4 %]135469417[% ELSE %]961504478[% END %]. To find the telephone number of DHL, visit www.dhl.com and select your country. Please ensure your item(s) is/are returned to us within 14 days of receiving this email.', 
'[% IF shipment_info.carrier == "DHL Ground" %]DHL will then call you direct to arrange your free collection on a convenient day.[% ELSE %]Then book your free collection with DHL, quoting our account number: [% IF shipment_info.shipment_type_id < 4 %]135469417[% ELSE %]961504478[% END %]. To find the telephone number of DHL, visit www.dhl.com and select your country. Please ensure your item(s) is/are returned to us within 14 days of receiving this email.[% END %]'
);

-- DC1 Dispatch email

update correspondence_templates set content = replace(content, 
'We can advise that your order has been shipped and your DHL Airway bill number is [% shipment.outward_airway_bill %]\r\n\r\nUsing this number you can track your package on our site [% channel.url %].  Simply SIGN IN, select MY ACCOUNT followed by ORDER STATUS.\r\n\r\nPlease be aware that, while your shipment has been processed and dispatched, it will take several hours before your number will register on the DHL website.', 
'[% IF shipment.carrier == \'DHL Ground\' %]We can advise that your order has been shipped and your DHL Tracking [% IF shipment_boxes.size > 1 %]numbers are:\r\n\r\n[% FOREACH boxid = shipment_boxes.keys %]JD00022[% shipment_boxes.$boxid.licence_plate_number %]\r\n[% END %][% ELSE %]number is [% FOREACH boxid = shipment_boxes.keys %]JD00022[% shipment_boxes.$boxid.licence_plate_number %][% END %]\r\n[% END %]\r\nUsing [% IF shipment_boxes.size > 1 %]these numbers[% ELSE %]this number[% END %] you can track your package on our site [% channel.url %].  Simply SIGN IN, select MY ACCOUNT followed by ORDER STATUS.\r\n\r\nPlease be aware that, while your shipment has been processed and dispatched, it will take several hours before your number will register on the DHL website.[% ELSE %]We can advise that your order has been shipped and your DHL Airway bill number is [% shipment.outward_airway_bill %]\r\n\r\nUsing this number you can track your package on our site [% channel.url %].  Simply SIGN IN, select MY ACCOUNT followed by ORDER STATUS.\r\n\r\nPlease be aware that, while your shipment has been processed and dispatched, it will take several hours before your number will register on the DHL website.[% END %]'
);


-- DC1 contact telephone
update correspondence_templates set content = replace(content, 
'+44 (0)1473 32 30 32', 
'[% contact_telephone %]'
);

-- DC2 contact telephone
update correspondence_templates set content = replace(content, 
'+1 800 481 1064', 
'[% contact_telephone %]'
);


-- DC2 CREATE RETURN

update correspondence_templates set content = replace(content, 
'[% IF shipment_info.shipment_type_id < 4 %]To book your free collection with UPS, please go to www.ups.com or call 1-800-PICK-UPS (742-5877), quoting our UPS account number: 3XA051.[% ELSE %]Then book your free collection with UPS, quoting our account number: 3XA051. To find the telephone number of your nearest UPS branch, visit www.ups.com and select your country.[% END %]',
'[% IF shipment_info.shipment_type_id < 4 %]To book your free collection with UPS, please go to www.ups.com or call 1-800-PICK-UPS (742-5877), quoting our UPS account number: [% IF channel.name == \'The Outnet\' %]539522[% ELSE %]3XA051[% END %].[% ELSE %]Then book your free collection with UPS, quoting our account number: [% IF channel.name == \'The Outnet\' %]539522[% ELSE %]3XA051[% END %]. To find the telephone number of your nearest UPS branch, visit www.ups.com and select your country.[% END %]'
);

-- DC2 CONVERT TO EX

update correspondence_templates set content = replace(content, 
'Then book your free collection with UPS, quoting our account number: [% IF shipment_info.shipment_type_id < 4 %]3XA051[% ELSE %]3XA051[% END %]', 
'Then book your free collection with UPS, quoting our account number: [% IF channel.name == \'The Outnet\' %]539522[% ELSE %]3XA051[% END %]'
);

COMMIT;