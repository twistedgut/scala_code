BEGIN;

CREATE TABLE credit_hold_threshold (
    id serial primary key NOT NULL,
    channel_id integer NOT NULL references channel(id),
    name varchar(255) NOT NULL,
    value int NOT NULL,
    UNIQUE (channel_id, name)
);

GRANT ALL ON credit_hold_threshold TO www;
GRANT ALL ON credit_hold_threshold_id_seq TO www;


INSERT INTO credit_hold_threshold (channel_id, name, value) VALUES ( (SELECT id FROM channel WHERE name = 'NET-A-PORTER'), 'Single Order Value', 1000);
INSERT INTO credit_hold_threshold (channel_id, name, value) VALUES ( (SELECT id FROM channel WHERE name = 'NET-A-PORTER'), 'Weekly Order Value', 2000);
INSERT INTO credit_hold_threshold (channel_id, name, value) VALUES ( (SELECT id FROM channel WHERE name = 'NET-A-PORTER'), 'Total Order Value', 5000);
INSERT INTO credit_hold_threshold (channel_id, name, value) VALUES ( (SELECT id FROM channel WHERE name = 'NET-A-PORTER'), 'Weekly Order Count', 5);
INSERT INTO credit_hold_threshold (channel_id, name, value) VALUES ( (SELECT id FROM channel WHERE name = 'NET-A-PORTER'), 'Daily Order Count', 3);


INSERT INTO credit_hold_threshold (channel_id, name, value) VALUES ( (SELECT id FROM channel WHERE name = 'The Outnet'), 'Single Order Value', 500);
INSERT INTO credit_hold_threshold (channel_id, name, value) VALUES ( (SELECT id FROM channel WHERE name = 'The Outnet'), 'Weekly Order Value', 1500);
INSERT INTO credit_hold_threshold (channel_id, name, value) VALUES ( (SELECT id FROM channel WHERE name = 'The Outnet'), 'Total Order Value', 3000);
INSERT INTO credit_hold_threshold (channel_id, name, value) VALUES ( (SELECT id FROM channel WHERE name = 'The Outnet'), 'Weekly Order Count', 4);
INSERT INTO credit_hold_threshold (channel_id, name, value) VALUES ( (SELECT id FROM channel WHERE name = 'The Outnet'), 'Daily Order Count', 3);

COMMIT;