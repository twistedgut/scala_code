-- new seasonal conversion rate mapping table
-- to emulate the website logic for calculating
-- product pricing

BEGIN;

CREATE TABLE season_conversion_rate (
    id serial primary key NOT NULL,
    season_id integer NOT NULL references season(id),
    source_currency_id integer NOT NULL,
    destination_currency_id integer NOT NULL,
    conversion_rate numeric(10,2) NOT NULL,
    UNIQUE (season_id, source_currency_id, destination_currency_id)
);

GRANT ALL ON season_conversion_rate TO www;


INSERT INTO season_conversion_rate (season_id, source_currency_id, destination_currency_id, conversion_rate) SELECT id, 1, 1, 1 FROM season;
INSERT INTO season_conversion_rate (season_id, source_currency_id, destination_currency_id, conversion_rate) SELECT id, 1, 2, 1.77 FROM season;
INSERT INTO season_conversion_rate (season_id, source_currency_id, destination_currency_id, conversion_rate) SELECT id, 1, 3, 1.47 FROM season;

INSERT INTO season_conversion_rate (season_id, source_currency_id, destination_currency_id, conversion_rate) SELECT id, 2, 1, 0.57 FROM season;
INSERT INTO season_conversion_rate (season_id, source_currency_id, destination_currency_id, conversion_rate) SELECT id, 2, 2, 1 FROM season;
INSERT INTO season_conversion_rate (season_id, source_currency_id, destination_currency_id, conversion_rate) SELECT id, 2, 3, 0.83 FROM season;

INSERT INTO season_conversion_rate (season_id, source_currency_id, destination_currency_id, conversion_rate) SELECT id, 3, 1, 0.72 FROM season;
INSERT INTO season_conversion_rate (season_id, source_currency_id, destination_currency_id, conversion_rate) SELECT id, 3, 2, 1.20 FROM season;
INSERT INTO season_conversion_rate (season_id, source_currency_id, destination_currency_id, conversion_rate) SELECT id, 3, 3, 1 FROM season;


UPDATE season_conversion_rate SET conversion_rate = 1.28 WHERE season_id = 31 AND source_currency_id = 1 AND destination_currency_id = 3;
UPDATE season_conversion_rate SET conversion_rate = 1.18 WHERE season_id = 32 AND source_currency_id = 1 AND destination_currency_id = 3;

UPDATE season_conversion_rate SET conversion_rate = 1.856 WHERE season_id = 31 AND source_currency_id = 1 AND destination_currency_id = 2;
UPDATE season_conversion_rate SET conversion_rate = 0.539 WHERE season_id = 31 AND source_currency_id = 2 AND destination_currency_id = 1;
UPDATE season_conversion_rate SET conversion_rate = 0.69 WHERE season_id = 31 AND source_currency_id = 2 AND destination_currency_id = 3;

UPDATE season_conversion_rate SET conversion_rate = 0.781 WHERE season_id = 31 AND source_currency_id = 3 AND destination_currency_id = 1;
UPDATE season_conversion_rate SET conversion_rate = 0.847 WHERE season_id = 32 AND source_currency_id = 3 AND destination_currency_id = 1;

UPDATE season_conversion_rate SET conversion_rate = 1.45 WHERE season_id = 31 AND source_currency_id = 3 AND destination_currency_id = 2;


COMMIT;