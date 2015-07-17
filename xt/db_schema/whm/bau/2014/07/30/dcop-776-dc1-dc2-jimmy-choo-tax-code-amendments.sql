BEGIN;

-- Update DC1 and DC2 tax code entries for Jimmy Choo for the following countries

UPDATE country_tax_code
    SET code = 'AT U684670425'
    WHERE country_id = (SELECT id FROM country WHERE country = 'Austria')
    AND channel_id = (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM');

UPDATE country_tax_code
	SET code = 'BE 0535799888'
	WHERE country_id = (SELECT id FROM country WHERE country = 'Belgium')
	AND channel_id = (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM');

UPDATE country_tax_code
	SET code = 'DK 12708718'
	WHERE country_id = (SELECT id FROM country WHERE country = 'Denmark')
	AND channel_id = (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM');

UPDATE country_tax_code
	SET code = 'FI 26061901'
	WHERE country_id = (SELECT id FROM country WHERE country = 'Finland')
	AND channel_id = (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM');

UPDATE country_tax_code
	SET code = 'FR 82790465504'
	WHERE country_id = (SELECT id FROM country WHERE country = 'France')
	AND channel_id = (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM');

UPDATE country_tax_code
	SET code = 'DE 288 845 864'
	WHERE country_id = (SELECT id FROM country WHERE country = 'Germany')
	AND channel_id = (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM');

UPDATE country_tax_code
	SET code = 'EL 997354360'
	WHERE country_id = (SELECT id FROM country WHERE country = 'Greece')
	AND channel_id = (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM');

UPDATE country_tax_code
	SET code = 'IE 3184732EH'
	WHERE country_id = (SELECT id FROM country WHERE country = 'Ireland')
	AND channel_id = (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM');

UPDATE country_tax_code
	SET code = 'IT 001582279998'
	WHERE country_id = (SELECT id FROM country WHERE country = 'Italy')
	AND channel_id = (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM');

UPDATE country_tax_code
	SET code = 'FR 82790465504'
	WHERE country_id = (SELECT id FROM country WHERE country = 'Monaco')
	AND channel_id = (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM');

UPDATE country_tax_code
	SET code = 'PT 980506484'
	WHERE country_id = (SELECT id FROM country WHERE country = 'Portugal')
	AND channel_id = (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM');

UPDATE country_tax_code
	SET code = 'RO 32948386'
	WHERE country_id = (SELECT id FROM country WHERE country = 'Romania')
	AND channel_id = (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM');

UPDATE country_tax_code
	SET code = 'SK 4020435606'
	WHERE country_id = (SELECT id FROM country WHERE country = 'Slovakia')
	AND channel_id = (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM');

UPDATE country_tax_code
	SET code = 'ES N8263493B'
	WHERE country_id = (SELECT id FROM country WHERE country = 'Spain')
	AND channel_id = (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM');

UPDATE country_tax_code
	SET code = 'SE 502071996801'
	WHERE country_id = (SELECT id FROM country WHERE country = 'Sweden')
	AND channel_id = (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM');

-- Create new DC1 and DC2 Jimmy Choo tax code entry for Poland
		
INSERT INTO country_tax_code
    (country_id, code, channel_id)
VALUES
    (
        (SELECT id FROM country WHERE country = 'Poland'),
        'PL 5263096514',
        (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM')
    );

COMMIT;
