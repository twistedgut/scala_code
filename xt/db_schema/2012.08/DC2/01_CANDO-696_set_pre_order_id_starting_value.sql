-- CANDO-696: Set the starting value for the
--            'pre_order.id' field for DC2

BEGIN WORK;

SELECT setval('pre_order_id_seq',2351267);

COMMIT WORK;
