-- CANDO-3257 : Add Role for Payment Details for Finance

BEGIN WORK;

--
--Add a new Role
--
INSERT INTO acl.authorisation_role (authorisation_role) Values('app_canViewOrderPaymentDetails');

COMMIT WORK;

