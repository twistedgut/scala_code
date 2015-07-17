BEGIN;

UPDATE correspondence_templates
 SET content = replace( content,
     'IF return.exchange_shipment_id > 0 ',
     'IF return.exchange_shipment_id.defined AND return.exchange_shipment_id  > 0 ')
 WHERE name = 'Return Received';

UPDATE correspondence_templates
 SET content = regexp_replace( content,
     E'\\m(\\w+)(\\.size\\s*>\\s*\\d)',
     E'\\1.defined AND \\1\\2',
     'g');

COMMIT;

