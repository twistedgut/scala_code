BEGIN;

update country set is_commercial_proforma = true where country in ('Peru', 'Maldives');

COMMIT;
