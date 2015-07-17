-- CANDO-696: Set the starting value for the
--            'pre_order.id' field for DC1

BEGIN WORK;

SELECT setval('pre_order_id_seq',1351267);

COMMIT WORK;
