BEGIN WORK;

UPDATE correspondence_templates
   SET id_for_cms = 'TT_CHANGE_SIZE',
       subject    = 'Your Order - [% order_number %]'
 WHERE name = 'Change Size of Product';

COMMIT;
