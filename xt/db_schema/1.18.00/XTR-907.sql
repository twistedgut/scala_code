
-- move everyone who isn't a shipping manager out of that department so we can use
-- it to restrict access to creating manual refunds

BEGIN;

	update operator set department_id = (select id from department where department = 'Shipping') where department_id = (select id from department where department = 'Shipping Manager') and name not in ('Ben Parsonson', 'Laura Taylor', 'Steve Crease');

COMMIT;