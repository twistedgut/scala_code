-- CANDO-31: Cleanup up the currency_glyph & link_currency__currency_glyph tables to remove duplicates

BEGIN WORK;

--
-- The MIN(id) check is so all isn't deleted
-- if this gets run twice
--

--
-- Remove the duplicate records in the
-- link_currenct__currency_glyph
--
DELETE FROM link_currency__currency_glyph
WHERE currency_glyph_id = (SELECT MAX(id) FROM currency_glyph WHERE html_entity = '&#36;')
AND currency_glyph_id != (SELECT MIN(id) FROM currency_glyph WHERE html_entity = '&#36;')
;
DELETE FROM link_currency__currency_glyph
WHERE currency_glyph_id = (SELECT MAX(id) FROM currency_glyph WHERE html_entity = '&pound;')
AND currency_glyph_id != (SELECT MIN(id) FROM currency_glyph WHERE html_entity = '&pound;')
;
DELETE FROM link_currency__currency_glyph
WHERE currency_glyph_id = (SELECT MAX(id) FROM currency_glyph WHERE html_entity = '&euro;')
AND currency_glyph_id != (SELECT MIN(id) FROM currency_glyph WHERE html_entity = '&euro;')
;

--
-- Remove the duplciate currency_glyph records
--
DELETE FROM currency_glyph
WHERE html_entity = '&#36;' AND id = ( SELECT MAX(id) FROM currency_glyph WHERE html_entity = '&#36;' )
AND html_entity = '&#36;' AND id != ( SELECT MIN(id) FROM currency_glyph WHERE html_entity = '&#36;' )
;
DELETE FROM currency_glyph
WHERE html_entity = '&pound;' AND id = ( SELECT MAX(id) FROM currency_glyph WHERE html_entity = '&pound;' )
AND html_entity = '&pound;' AND id != ( SELECT MIN(id) FROM currency_glyph WHERE html_entity = '&pound;' )
;
DELETE FROM currency_glyph
WHERE html_entity = '&euro;' AND id = ( SELECT MAX(id) FROM currency_glyph WHERE html_entity = '&euro;' )
AND html_entity = '&euro;' AND id != ( SELECT MIN(id) FROM currency_glyph WHERE html_entity = '&euro;' )
;

COMMIT WORK;
