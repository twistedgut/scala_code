BEGIN;

---
--- Rename MrPorter.com to MRPORTER.COM
---

update channel set name='MRPORTER.COM' where name='MrPorter.com';
update business set name='MRPORTER.COM' where name='MrPorter.com';

COMMIT;
