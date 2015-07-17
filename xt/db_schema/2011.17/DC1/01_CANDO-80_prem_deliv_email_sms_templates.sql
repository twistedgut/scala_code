-- CANDO-80: New Email/SMS Correspondence Templates for
--           notifying Premier Customers about their Deliveries

BEGIN WORK;

INSERT INTO correspondence_templates (name,access,content,department_id)
SELECT  t.name || ' ' || m.method,
        0,
        t.name,
        ( SELECT id FROM department WHERE department = 'Shipping' )
FROM    (
            SELECT 'Premier - Order/Exchange Delivery/Collection' AS name UNION
            SELECT 'Premier - Delivery Failed 1st and 2nd Attempt' AS name UNION
            SELECT 'Premier - Hold Order Delivery' AS name UNION
            SELECT 'Premier - Delivery Success' AS name UNION
            SELECT 'Premier - Collection Failed' AS name UNION
            SELECT 'Premier - Collection Success' AS name
        ) t,
        (
            SELECT 'EMAIL-PLAIN' AS method UNION
            SELECT 'SMS' AS method
        ) m
ORDER BY t.name,m.method
;


--
-- These are the Email/SMS TT Template texts
--

-- Premier - Order/Exchange Delivery/Collection EMAIL-PLAIN
UPDATE correspondence_templates
    SET content =
'Dear [% channel_info.salutation %],

Our [% channel_info.branding.${db_constant("BRANDING__PREM_NAME")} %] driver, [% schedule.driver %], will [% is_shipment ? "deliver" : "collect" %] the item[% IF items.size > 1 %]s[% END %] below (order – [% order_nr %]) [% is_shipment ? "to" : "from" %] [% ship_addr.address_line_1 %], [% ship_addr.postcode %] between [% schedule.task_window %] on [% schedule.task_window_date.day_name %], [% channel.business.branded_date( schedule.task_window_date ) %].

[% FOREACH item IN items %]
[% IF !item.is_voucher %]
- [% item.item_info.designer %] [% item.item_info.name %] - size [% item.item_info.designer_size +%]
[% ELSE %]
- [% item.item_info.name +%]
[% END %]
[% END %]
[% IF channel.can_premier_send_alert_by("SMS") %]

We have also sent a text message confirming your [% is_shipment ? "delivery" : "collection" %] to your mobile number [% shipment.mobile_telephone %].
[% END %]

If this time is inconvenient for you, please contact us as soon as possible.

[% channel_info.branding.${db_constant("BRANDING__EMAIL_SIGNOFF")} %],
[% channel_info.branding.${db_constant("BRANDING__PREM_NAME")} +%]

For assistance call [% channel_info.company_detail.premier_tel %] ([% channel_info.company_detail.premier_contact_hours %]) or email [% channel_info.email_address.premier_email %]
'
WHERE   department_id   = ( SELECT id FROM department WHERE department = 'Shipping' )
AND     name            = 'Premier - Order/Exchange Delivery/Collection EMAIL-PLAIN'
;

-- Premier - Order/Exchange Delivery/Collection SMS
UPDATE correspondence_templates
    SET content =
'[% channel_info.branding.${db_constant("BRANDING__PREM_NAME")} %] will [% is_shipment ? "deliver your" : "collect your return from" %] order [% order_nr %] on [% schedule.task_window_date.day_abbr %], [% schedule.task_window_date.month_abbr %] [% schedule.task_window_date.day %] between [% schedule.task_window %]. For assistance please call us on [% channel_info.company_detail.premier_tel %].'
WHERE   department_id   = ( SELECT id FROM department WHERE department = 'Shipping' )
AND     name            = 'Premier - Order/Exchange Delivery/Collection SMS'
;

-- Premier - Delivery Failed 1st and 2nd Attempt EMAIL-PLAIN
UPDATE correspondence_templates
    SET content =
'Dear [% channel_info.salutation %],

Our [% channel_info.branding.${db_constant("BRANDING__PREM_NAME")} %] driver, [% schedule.driver %], attempted to deliver your order [% order_nr %] on [% schedule.task_window_date.day_name %], [% channel.business.branded_date( schedule.task_window_date ) %] to [% ship_addr.address_line_1 %].

We will be in touch by email/telephone tomorrow with a new two-hour delivery window.

In the meantime, please don’t hesitate to contact us if we can be of further assistance.

[% channel_info.branding.${db_constant("BRANDING__EMAIL_SIGNOFF")} %],
[% channel_info.branding.${db_constant("BRANDING__PREM_NAME")} +%]

For assistance call [% channel_info.company_detail.premier_tel %] ([% channel_info.company_detail.premier_contact_hours %]) or email [% channel_info.email_address.premier_email %]
'
WHERE   department_id   = ( SELECT id FROM department WHERE department = 'Shipping' )
AND     name            = 'Premier - Delivery Failed 1st and 2nd Attempt EMAIL-PLAIN'
;

-- Premier - Delivery Failed 1st and 2nd Attempt SMS
UPDATE correspondence_templates
    SET content =
'[% channel_info.branding.${db_constant("BRANDING__PREM_NAME")} %] attempted to deliver your order [% order_nr %] on [% schedule.task_window_date.day_abbr %], [% schedule.task_window_date.month_abbr %] [% schedule.task_window_date.day %]. We will contact you tomorrow with a new two-hour slot.'
WHERE   department_id   = ( SELECT id FROM department WHERE department = 'Shipping' )
AND     name            = 'Premier - Delivery Failed 1st and 2nd Attempt SMS'
;

-- Premier - Hold Order Delivery EMAIL-PLAIN
UPDATE correspondence_templates
    SET content =
'Dear [% channel_info.salutation %],

Our [% channel_info.branding.${db_constant("BRANDING__PREM_NAME")} %] drivers have attempted to deliver your order [% order_nr %] to [% ship_addr.address_line_1 %].

Please contact us to arrange a more convenient day and time.

We look forward to hearing from you.

[% channel_info.branding.${db_constant("BRANDING__EMAIL_SIGNOFF")} %],
[% channel_info.branding.${db_constant("BRANDING__PREM_NAME")} +%]

For assistance call [% channel_info.company_detail.premier_tel %] ([% channel_info.company_detail.premier_contact_hours %]) or email [% channel_info.email_address.premier_email %]
'
WHERE   department_id   = ( SELECT id FROM department WHERE department = 'Shipping' )
AND     name            = 'Premier - Hold Order Delivery EMAIL-PLAIN'
;

-- Premier - Hold Order Delivery SMS
UPDATE correspondence_templates
    SET content =
'[% channel_info.branding.${db_constant("BRANDING__PREM_NAME")} %] attempted to deliver your order [% order_nr %] on [% schedule.task_window_date.day_abbr %], [% schedule.task_window_date.month_abbr %] [% schedule.task_window_date.day %]. Please call [% channel_info.company_detail.premier_tel %] to arrange a convenient day/time.'
WHERE   department_id   = ( SELECT id FROM department WHERE department = 'Shipping' )
AND     name            = 'Premier - Hold Order Delivery SMS'
;

-- Premier - Delivery Success EMAIL-PLAIN
UPDATE correspondence_templates
    SET content =
'Dear [% channel_info.salutation %],

Our [% channel_info.branding.${db_constant("BRANDING__PREM_NAME")} %] driver, [% schedule.driver %], delivered your order [% order_nr %] on [% schedule.task_window_date.day_name %], [% channel.business.branded_date( schedule.task_window_date ) %] to [% ship_addr.address_line_1 %].

Your purchase[% IF items.size > 1 %]s were[% ELSE %] was[% END %] signed for by [% schedule.signatory FILTER ucfirst %] at [% schedule_record.twelve_hour("signature_time") %].
[% IF channel.can_premier_send_alert_by("SMS") %]

We have also sent a text message to your mobile number [% shipment.mobile_telephone %] to confirm that your order arrived safely.
[% END %]

Thank you for shopping with us.

[% channel_info.branding.${db_constant("BRANDING__EMAIL_SIGNOFF")} %],
[% channel_info.branding.${db_constant("BRANDING__PREM_NAME")} +%]

For assistance call [% channel_info.company_detail.premier_tel %] ([% channel_info.company_detail.premier_contact_hours %]) or email [% channel_info.email_address.premier_email %]
'
WHERE   department_id   = ( SELECT id FROM department WHERE department = 'Shipping' )
AND     name            = 'Premier - Delivery Success EMAIL-PLAIN'
;

-- Premier - Delivery Success SMS
UPDATE correspondence_templates
    SET content =
'Your order [% order_nr %] was delivered by [% channel_info.branding.${db_constant("BRANDING__PREM_NAME")} %] on [% schedule.task_window_date.day_abbr %], [% schedule.task_window_date.month_abbr %] [% schedule.task_window_date.day %]. Thank you for shopping at [% channel_info.branding.${db_constant("BRANDING__PF_NAME")} %].'
WHERE   department_id   = ( SELECT id FROM department WHERE department = 'Shipping' )
AND     name            = 'Premier - Delivery Success SMS'
;

-- Premier - Collection Failed EMAIL-PLAIN
UPDATE correspondence_templates
    SET content =
'Dear [% channel_info.salutation %],

Our [% channel_info.branding.${db_constant("BRANDING__PREM_NAME")} %] driver, [% schedule.driver %], attempted to collect the return from your order [% order_nr %] on [% schedule.task_window_date.day_name %], [% channel.business.branded_date( schedule.task_window_date ) %] from [% ship_addr.address_line_1 %].

Please contact us to arrange a more convenient day and time.

We look forward to hearing from you.

[% channel_info.branding.${db_constant("BRANDING__EMAIL_SIGNOFF")} %],
[% channel_info.branding.${db_constant("BRANDING__PREM_NAME")} +%]

For assistance call [% channel_info.company_detail.premier_tel %] ([% channel_info.company_detail.premier_contact_hours %]) or email [% channel_info.email_address.premier_email %]
'
WHERE   department_id   = ( SELECT id FROM department WHERE department = 'Shipping' )
AND     name            = 'Premier - Collection Failed EMAIL-PLAIN'
;

-- Premier - Collection Failed SMS
UPDATE correspondence_templates
    SET content =
'[% channel_info.branding.${db_constant("BRANDING__PREM_NAME")} %] attempted to collect your return on [% schedule.task_window_date.day_abbr %], [% schedule.task_window_date.month_abbr %] [% schedule.task_window_date.day %]. Please call [% channel_info.company_detail.premier_tel %] to arrange a convenient day/time.'
WHERE   department_id   = ( SELECT id FROM department WHERE department = 'Shipping' )
AND     name            = 'Premier - Collection Failed SMS'
;

-- Premier - Collection Success EMAIL-PLAIN
UPDATE correspondence_templates
    SET content =
'Dear [% channel_info.salutation %],

Our [% channel_info.branding.${db_constant("BRANDING__PREM_NAME")} %] driver, [% schedule.driver %], collected your return from order [% order_nr %] on [% schedule.task_window_date.day_name %], [% channel.business.branded_date( schedule.task_window_date ) %] from [% ship_addr.address_line_1 %] at [% schedule_record.twelve_hour("signature_time") %].

This was signed for by [% schedule.signatory FILTER ucfirst %].
[% IF channel.can_premier_send_alert_by("SMS") %]

We have also sent a text message to your mobile number [% shipment.mobile_telephone %] to confirm that your item(s) are now with us.
[% END %]

[% channel_info.branding.${db_constant("BRANDING__EMAIL_SIGNOFF")} %],
[% channel_info.branding.${db_constant("BRANDING__PREM_NAME")} +%]

For assistance call [% channel_info.company_detail.premier_tel %] ([% channel_info.company_detail.premier_contact_hours %]) or email [% channel_info.email_address.premier_email %]
'
WHERE   department_id   = ( SELECT id FROM department WHERE department = 'Shipping' )
AND     name            = 'Premier - Collection Success EMAIL-PLAIN'
;

-- Premier - Collection Success SMS
UPDATE correspondence_templates
    SET content =
'Your return from order [% order_nr %] was collected on [% schedule.task_window_date.day_abbr %], [% schedule.task_window_date.month_abbr %] [% schedule.task_window_date.day %]. We will email you when this has been processed.'
WHERE   department_id   = ( SELECT id FROM department WHERE department = 'Shipping' )
AND     name            = 'Premier - Collection Success SMS'
;


COMMIT WORK;
