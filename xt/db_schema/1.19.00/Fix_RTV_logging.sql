/********************************
* Fix the RTV action problem
*
********************************/

BEGIN;

-- drop foreign key to rtv_action table
ALTER TABLE log_rtv_stock DROP CONSTRAINT log_rtv_stock_rtv_action_id_fkey;

-- clear out rtv_action table
DELETE FROM rtv_action;

-- reset auto increment
ALTER SEQUENCE rtv_action_id_seq RESTART WITH 1;

-- populate actions
INSERT INTO rtv_action (action) VALUES ('Quarantined');               -- Transfered to Quarantine - in
INSERT INTO rtv_action (action) VALUES ('Quarantine Fixed');          -- Quarantine item to Putaway ('Fixed Quarantine') - out
INSERT INTO rtv_action (action) VALUES ('Quarantine RTV');            -- Quarantine item to Putaway ('RTV') - out
INSERT INTO rtv_action (action) VALUES ('Quarantine Dead');           -- Quarantine item to Putaway ('Dead') - out
INSERT INTO rtv_action (action) VALUES ('GI Faulty Fixed');           -- RTV Workstation item to Putaway ('RTV Fixed') - out
INSERT INTO rtv_action (action) VALUES ('GI Faulty RTV');             -- RTV Workstation item to Putaway ('RTV') - out
INSERT INTO rtv_action (action) VALUES ('GI Faulty Dead');            -- RTV Workstation item to Putaway ('Dead') - out
INSERT INTO rtv_action (action) VALUES ('CR Faulty Fixed');           -- out
INSERT INTO rtv_action (action) VALUES ('CR Faulty RTV');             -- out
INSERT INTO rtv_action (action) VALUES ('CR Faulty Dead');            -- out
INSERT INTO rtv_action (action) VALUES ('Repair RTV');                -- in
INSERT INTO rtv_action (action) VALUES ('Repair Dead');               -- out
INSERT INTO rtv_action (action) VALUES ('Non-Faulty');                -- in
INSERT INTO rtv_action (action) VALUES ('Putaway - RTV Goods In');    -- in
INSERT INTO rtv_action (action) VALUES ('Putaway - RTV Process');     -- in
INSERT INTO rtv_action (action) VALUES ('Putaway - Dead');            -- in
INSERT INTO rtv_action (action) VALUES ('System Transfer');           -- in or out
INSERT INTO rtv_action (action) VALUES ('RTV Shipment Pick');         -- out
INSERT INTO rtv_action (action) VALUES ('Manual Adjustment');         -- in or out

-- update log entries to new actions
UPDATE log_rtv_stock SET rtv_action_id = (SELECT id FROM rtv_action WHERE action = 'Non-Faulty') WHERE rtv_action_id = 2;
UPDATE log_rtv_stock SET rtv_action_id = (SELECT id FROM rtv_action WHERE action = 'RTV Shipment Pick') WHERE rtv_action_id = 7;
UPDATE log_rtv_stock SET rtv_action_id = (SELECT id FROM rtv_action WHERE action = 'Quarantine Fixed') WHERE rtv_action_id = 9;

-- add foreign key to rtv_action table
ALTER TABLE log_rtv_stock ADD CONSTRAINT log_rtv_stock_rtv_action_id_fkey FOREIGN KEY (rtv_action_id) REFERENCES rtv_action(id) MATCH FULL;


COMMIT;
