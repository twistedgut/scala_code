BEGIN WORK;
-- CANDO-1459 : Updating correspondence_templates table to have CMS Id's

UPDATE correspondence_templates  SET id_for_cms='TT_ORDER_DISPATCHED' WHERE   name = 'Dispatch Order';
UPDATE correspondence_templates  SET id_for_cms='TT_ORDER_CREDIT_OR_DEBIT_COMPLETED' WHERE   name = 'Credit/Debit Completed';
UPDATE correspondence_templates  SET id_for_cms='TT_RMA_RETURN_RECEIVED' WHERE   name = 'Return Received';
UPDATE correspondence_templates  SET id_for_cms='TT_DDU_REQUEST_ACCEPT_SHIPPING_TERMS' WHERE   name = 'DDU Order - Request accept shipping terms';
UPDATE correspondence_templates  SET id_for_cms='TT_DDU_FOLLOW_UP' WHERE   name = 'DDU Order - Follow Up';
UPDATE correspondence_templates  SET id_for_cms='TT_RMA_CONVERT_FROM_EXCHANGE' WHERE   name LIKE 'RMA - Convert From Exchange %';
UPDATE correspondence_templates  SET id_for_cms='TT_RMA_CONVERT_TO_EXCHANGE' WHERE   name LIKE 'RMA - RMA - Convert To Exchange %';
UPDATE correspondence_templates  SET id_for_cms='TT_RMA_CREATE_RETURN' WHERE   name LIKE 'RMA - Create Return -%';
UPDATE correspondence_templates  SET id_for_cms='TT_RMA_ADD_ITEM' WHERE   name LIKE 'RMA - Add Item -%';
UPDATE correspondence_templates  SET id_for_cms='TT_RMA_CANCEL_RETURN' WHERE   name LIKE 'RMA - Cancel Return - %';
UPDATE correspondence_templates  SET id_for_cms='TT_RMA_REMOVE_ITEM' WHERE   name LIKE 'RMA - Remove Item -%';

COMMIT WORK;
