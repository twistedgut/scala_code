BEGIN;

  UPDATE correspondence_templates
     SET content = '[% THROW "DB copy not used - now lives in root/base/email/rma/" %];'
   WHERE name IN ( 'Add Return Item',
                   'Remove Return Item',
                   'Cancel Return',
                   'Return/Exchange',
                   'Convert to Exchange',
                   'Cancel Exchange'
                 );

COMMIT;
