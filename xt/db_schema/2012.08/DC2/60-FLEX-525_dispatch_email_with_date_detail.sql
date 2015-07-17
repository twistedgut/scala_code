BEGIN;

-- FLEX-525 replace 'Monday to Friday' in Dispatch Order template with
-- TT to give more desriptive date
UPDATE correspondence_templates SET
content = regexp_replace(
    content,
    'Monday through Friday',
    '[% IF shipment_row.nominated_delivery_date -%]
on [% shipment_row.nominated_delivery_date.strftime("%A, %B %e") %]
[%- ELSE -%]
Monday through Friday
[%- END %]',
    'g'
)
WHERE name ilike '%Dispatch Order%';

SELECT id,content FROM correspondence_templates WHERE
    name ilike '%Dispatch Order%';

COMMIT;

