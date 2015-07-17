
-- rename Datacash Reporting section to Transaction Reporting to allow for Paymentech

BEGIN;

update authorisation_sub_section set sub_section = 'Transaction Reporting' where sub_section = 'Datacash Reporting';

COMMIT;
