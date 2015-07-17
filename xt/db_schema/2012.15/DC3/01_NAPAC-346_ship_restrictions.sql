BEGIN;

ALTER TABLE ship_restriction_location
  DROP CONSTRAINT ship_restriction_location_ship_restriction_id_fkey;

ALTER TABLE ship_restriction_location
  ADD FOREIGN KEY (ship_restriction_id) REFERENCES ship_restriction(id);

INSERT INTO ship_restriction (title, code) VALUES ('Chinese Origin', 'CH_ORIGIN');
INSERT INTO ship_restriction (title, code) VALUES ('CITES', 'CITES');
INSERT INTO ship_restriction (title, code) VALUES ('Fish & Wildlife', 'FISH_WILD');
INSERT INTO ship_restriction (title, code) VALUES ('Fine Jewelry', 'FINE_JEWEL');
INSERT INTO ship_restriction (title, code) VALUES ('Figures', 'FIGURES');
INSERT INTO ship_restriction (title, code) VALUES ('Goose Feathers', 'GOOSE');
INSERT INTO ship_restriction (title, code) VALUES ('Middle East', 'MIDDLEEAST');
INSERT INTO ship_restriction (title, code) VALUES ('Non-Hazmat beauty', 'NONHMB');

INSERT INTO ship_restriction_location
            (ship_restriction_id, location, type)
            (SELECT
               (SELECT id FROM ship_restriction WHERE code = 'CH_ORIGIN'),
               code,
               'COUNTRY'
             FROM country
             WHERE code IN ('TR','MX')
            );

INSERT INTO ship_restriction_location
            (ship_restriction_id, location, type)
            (SELECT
               (SELECT id FROM ship_restriction WHERE code = 'CITES'),
               code,
               'COUNTRY'
             FROM country
             WHERE code != ''
            );

COMMIT;
