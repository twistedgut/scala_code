BEGIN;

update channel set name = 'NET-A-PORTER.COM' where name = 'NET-A-PORTER';
update channel set name = 'theOutnet.com' where name = 'The Outnet';

update correspondence_templates set content = replace(content, 'The Outnet', 'theOutnet.com');

COMMIT;