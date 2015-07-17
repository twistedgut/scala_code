-- Channelising tax codes for JC
-- http://confluence.net-a-porter.com/display/JCXT/Channelising+Tax+Code
-- http://jira.nap:8084/browse/JCXT-11
BEGIN;

CREATE TABLE country_tax_code (
        channel_id int references channel(id) not null,
        country_id int references country(id) not null,
        code varchar(255)
    );
ALTER TABLE country_tax_code ADD CONSTRAINT channel_id_country_id_tax_code_key UNIQUE (channel_id, country_id);

INSERT INTO country_tax_code (channel_id, country_id, code)
SELECT  (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'),
        country_id,
        tax_code              
FROM    country_tax_rate
WHERE   tax_code != ''
;

INSERT INTO country_tax_code (channel_id, country_id, code)
SELECT  (SELECT id FROM channel WHERE name = 'theOutnet.com'),
        country_id,
        tax_code              
FROM    country_tax_rate
WHERE   tax_code != ''
;

INSERT INTO country_tax_code (channel_id, country_id, code)
SELECT  (SELECT id FROM channel WHERE name = 'MRPORTER.COM'),
        country_id,
        tax_code              
FROM    country_tax_rate
WHERE   tax_code != ''
;

INSERT INTO country_tax_code (channel_id, country_id, code) VALUES ((SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), (SELECT id FROM country WHERE country = 'Portugal'), 'GB 849 1509 05');
INSERT INTO country_tax_code (channel_id, country_id, code) VALUES ((SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), (SELECT id FROM country WHERE country = 'Sweden'), 'GB 849 1509 05');
INSERT INTO country_tax_code (channel_id, country_id, code) VALUES ((SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), (SELECT id FROM country WHERE country = 'Slovenia'), 'GB 849 1509 05');
INSERT INTO country_tax_code (channel_id, country_id, code) VALUES ((SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), (SELECT id FROM country WHERE country = 'Slovakia'), 'GB 849 1509 05');
INSERT INTO country_tax_code (channel_id, country_id, code) VALUES ((SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), (SELECT id FROM country WHERE country = 'Canada'), 'GB 849 1509 05');
INSERT INTO country_tax_code (channel_id, country_id, code) VALUES ((SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), (SELECT id FROM country WHERE country = 'France'), 'GB 849 1509 05');
INSERT INTO country_tax_code (channel_id, country_id, code) VALUES ((SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), (SELECT id FROM country WHERE country = 'United Kingdom'), 'GB 849 1509 05');
INSERT INTO country_tax_code (channel_id, country_id, code) VALUES ((SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), (SELECT id FROM country WHERE country = 'Greece'), 'GB 849 1509 05');
INSERT INTO country_tax_code (channel_id, country_id, code) VALUES ((SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), (SELECT id FROM country WHERE country = 'Hungary'), 'GB 849 1509 05');
INSERT INTO country_tax_code (channel_id, country_id, code) VALUES ((SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), (SELECT id FROM country WHERE country = 'Ireland'), 'GB 849 1509 05');
INSERT INTO country_tax_code (channel_id, country_id, code) VALUES ((SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), (SELECT id FROM country WHERE country = 'Bulgaria'), 'GB 849 1509 05');
INSERT INTO country_tax_code (channel_id, country_id, code) VALUES ((SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), (SELECT id FROM country WHERE country = 'Italy'), 'GB 849 1509 05');
INSERT INTO country_tax_code (channel_id, country_id, code) VALUES ((SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), (SELECT id FROM country WHERE country = 'Lithuania'), 'GB 849 1509 05');
INSERT INTO country_tax_code (channel_id, country_id, code) VALUES ((SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), (SELECT id FROM country WHERE country = 'Luxembourg'), 'GB 849 1509 05');
INSERT INTO country_tax_code (channel_id, country_id, code) VALUES ((SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), (SELECT id FROM country WHERE country = 'Latvia'), 'GB 849 1509 05');
INSERT INTO country_tax_code (channel_id, country_id, code) VALUES ((SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), (SELECT id FROM country WHERE country = 'Japan'), 'GB 849 1509 05');
INSERT INTO country_tax_code (channel_id, country_id, code) VALUES ((SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), (SELECT id FROM country WHERE country = 'Monaco'), 'GB 849 1509 05');
INSERT INTO country_tax_code (channel_id, country_id, code) VALUES ((SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), (SELECT id FROM country WHERE country = 'Malta'), 'GB 849 1509 05');
INSERT INTO country_tax_code (channel_id, country_id, code) VALUES ((SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), (SELECT id FROM country WHERE country = 'Romania'), 'GB 849 1509 05');
INSERT INTO country_tax_code (channel_id, country_id, code) VALUES ((SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), (SELECT id FROM country WHERE country = 'Singapore'), 'GB 849 1509 05');
INSERT INTO country_tax_code (channel_id, country_id, code) VALUES ((SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), (SELECT id FROM country WHERE country = 'Netherlands'), 'GB 849 1509 05');
INSERT INTO country_tax_code (channel_id, country_id, code) VALUES ((SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), (SELECT id FROM country WHERE country = 'Norway'), 'GB 849 1509 05');
INSERT INTO country_tax_code (channel_id, country_id, code) VALUES ((SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), (SELECT id FROM country WHERE country = 'Austria'), 'GB 849 1509 05');
INSERT INTO country_tax_code (channel_id, country_id, code) VALUES ((SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), (SELECT id FROM country WHERE country = 'Belgium'), 'GB 849 1509 05');
INSERT INTO country_tax_code (channel_id, country_id, code) VALUES ((SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), (SELECT id FROM country WHERE country = 'Switzerland'), 'GB 849 1509 05');
INSERT INTO country_tax_code (channel_id, country_id, code) VALUES ((SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), (SELECT id FROM country WHERE country = 'Cyprus'), 'GB 849 1509 05');
INSERT INTO country_tax_code (channel_id, country_id, code) VALUES ((SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), (SELECT id FROM country WHERE country = 'Czech Republic'), 'GB 849 1509 05');
INSERT INTO country_tax_code (channel_id, country_id, code) VALUES ((SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), (SELECT id FROM country WHERE country = 'Germany'), 'GB 849 1509 05');
INSERT INTO country_tax_code (channel_id, country_id, code) VALUES ((SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), (SELECT id FROM country WHERE country = 'Denmark'), 'GB 849 1509 05');
INSERT INTO country_tax_code (channel_id, country_id, code) VALUES ((SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), (SELECT id FROM country WHERE country = 'Estonia'), 'GB 849 1509 05');
INSERT INTO country_tax_code (channel_id, country_id, code) VALUES ((SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), (SELECT id FROM country WHERE country = 'Spain'), 'GB 849 1509 05');
INSERT INTO country_tax_code (channel_id, country_id, code) VALUES ((SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), (SELECT id FROM country WHERE country = 'Finland'), 'GB 849 1509 05');

ALTER TABLE country_tax_rate DROP COLUMN tax_code;

ALTER TABLE channel ADD COLUMN company_registration_number VARCHAR(50);
ALTER TABLE channel ADD COLUMN default_tax_code VARCHAR(50);

UPDATE channel SET company_registration_number = '03820604' WHERE name IN ('NET-A-PORTER.COM', 'theOutnet.com', 'MRPORTER.COM');

UPDATE channel SET company_registration_number = '03185783' WHERE name IN ('JIMMYCHOO.COM');

GRANT ALL ON TABLE country_tax_code TO postgres;
GRANT ALL ON TABLE country_tax_code TO www;
GRANT SELECT ON TABLE country_tax_code TO perlydev;

COMMIT;
