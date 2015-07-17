/****************************************************
* Quarantine Routing (Non-Faulty)
*
* Changes to allow non-faulty items to be routed
* to RTV Process via putaway, rather than requiring
* inspection at RTV Workstation.
****************************************************/

BEGIN;

/* add 'RTV Transfer Pending' location */
INSERT INTO location (location, type_id) VALUES ('RTV Transfer Pending', (SELECT id FROM location_type WHERE type = 'In Transit'));


/* add 'RTV Non-Faulty' stock process type */
SELECT setval('stock_process_type_id_seq', (SELECT max(id) FROM stock_process_type));
INSERT INTO stock_process_type (type) VALUES ('RTV Non-Faulty');


/* add 'RTV Non-Faulty' stock_action */
SELECT setval('stock_action_id_seq', (SELECT max(id) FROM stock_action));
INSERT INTO stock_action (action) VALUES ('RTV Non-Faulty');


/* add 'RTV Non-Faulty' pws_action */
SELECT setval('pws_action_id_seq', (SELECT max(id) FROM pws_action));
INSERT INTO pws_action (action) VALUES ('RTV Non-Faulty');

COMMIT;
