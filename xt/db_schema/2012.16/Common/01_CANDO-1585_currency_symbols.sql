-- CANDO-1585: New Currency Symbols to support HKD and AUD

BEGIN WORK;

-- Alter the Table to lenghten the glyph
ALTER TABLE currency_glyph
    ALTER COLUMN glyph SET DATA TYPE CHARACTER VARYING(5)
;

-- insert new symbols
INSERT INTO currency_glyph(glyph,html_entity) VALUES ('HK$','HK&#36;');
INSERT INTO currency_glyph(glyph,html_entity) VALUES ('AU$','AU&#36;');

-- remove current links to HKD, CNY & AUD
DELETE FROM link_currency__currency_glyph
WHERE currency_id IN (
        SELECT  id
        FROM    currency
        WHERE   currency IN ('HKD','AUD','CNY')
    )
;

-- Add the Links to HKD, CNY & AUD
INSERT INTO link_currency__currency_glyph (currency_id,currency_glyph_id) VALUES
(
    (
        SELECT  id
        FROM    currency
        WHERE   currency = 'HKD'
    ),
    (
        SELECT  id
        FROM    currency_glyph
        WHERE   html_entity = 'HK&#36;'
    )
)
;
INSERT INTO link_currency__currency_glyph (currency_id,currency_glyph_id) VALUES
(
    (
        SELECT  id
        FROM    currency
        WHERE   currency = 'AUD'
    ),
    (
        SELECT  id
        FROM    currency_glyph
        WHERE   html_entity = 'AU&#36;'
    )
)
;
INSERT INTO link_currency__currency_glyph (currency_id,currency_glyph_id) VALUES
(
    (
        SELECT  id
        FROM    currency
        WHERE   currency = 'CNY'
    ),
    (
        SELECT  id
        FROM    currency_glyph
        WHERE   html_entity = '&yen;'
    )
)
;

COMMIT WORK;
