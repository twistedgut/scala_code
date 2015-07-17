BEGIN;
    update correspondence_templates 
    set content = replace(
        content,
E'[% IF shipment.carrier == \'DHL Ground\' %]We can advise that your order has been shipped and your DHL Tracking [% IF shipment_boxes.size > 1 %]numbers are:\r\n\r\n[% FOREACH boxid = shipment_boxes.keys %]JD00022[% shipment_boxes.$boxid.licence_plate_number %]\r\n[% END %][% ELSE %]number is [% FOREACH bxid = shipment_boxes.keys %]JD00022[% shipment_boxes.$boxid.licence_plate_number %][% END %]\r\n[% END %]\r\nUsing [% IF shipment_boxes.size > 1 %]these numbers[% ELSE %]this number[% END %] you can track your package on our site [% channel.url %].  Simply SIGN IN, select MY ACCOUNT followed by ORDER STATUS.\r\n\r\nPlease be aware that, while your shipment has been processed and dispatched, it will take several hours before your number will register on the DHL website.[% ELSE %]We can advise that your order has been shipped and your DHL Airway bill number is [% shipment.outward_airway_bill %]\r\n\r\nUsing this number you can track your package on our site [% channel.url %].  Simply SIGN IN, select MY ACCOUNT followed by ORDER STATUS.\r\n\r\nPlease be aware that, while your shipment has been processed and dispatched, it will take several hours before your number will register on the DHL website.[% END %]',
E'[% IF shipment.carrier == \'DHL Ground\' %]We can advise that your order has been shipped and your DHL Tracking [% IF shipment_boxes.size > 1 %]numbers are:\r\n\r\n[% FOREACH boxid = shipment_boxes.keys %]JD00022[% shipment_boxes.$boxid.tracking_number %]\r\n[% END %][% ELSE %]number is [% FOREACH boxid = shipment_boxes.keys %]JD00022[% shipment_boxes.$boxid.tracking_number %][% END %]\r\n[% END %]\r\nUsing [% IF shipment_boxes.size > 1 %]these numbers[% ELSE %]this number[% END %] you can track your package on our site [% channel.url %].  Simply SIGN IN, select MY ACCOUNT followed by ORDER STATUS.\r\n\r\nPlease be aware that, while your shipment has been processed and dispatched, it will take several hours before your number will register on the DHL website.[% ELSE %]We can advise that your order has been shipped and your DHL Airway bill number is [% shipment.outward_airway_bill %]\r\n\r\nUsing this number you can track your package on our site [% channel.url %].  Simply SIGN IN, select MY ACCOUNT followed by ORDER STATUS.\r\n\r\nPlease be aware that, while your shipment has been processed and dispatched, it will take several hours before your number will register on the DHL website.[% END %]'
    );
COMMIT;