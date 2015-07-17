BEGIN;

INSERT INTO credit_hold_threshold (
    channel_id, name, value
) VALUES (
    (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'),
    'Single Order Value',
    1750);

INSERT INTO credit_hold_threshold (
    channel_id, name, value
) VALUES (
    (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'),
    'Weekly Order Value',
    2750);

INSERT INTO credit_hold_threshold (
    channel_id, name, value
) VALUES (
    (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'),
    'Total Order Value',
    5000);

INSERT INTO credit_hold_threshold (
    channel_id, name, value
) VALUES (
    (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'),
    'Weekly Order Count',
    5);

INSERT INTO credit_hold_threshold (
    channel_id, name, value
) VALUES (
    (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'),
    'Daily Order Count',
    3);


COMMIT;
