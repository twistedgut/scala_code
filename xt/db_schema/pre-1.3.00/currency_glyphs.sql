-- Purpose:
-- Create a new table listing glyphs for currencies (like $, €, £ etc)
-- so that we don't hardcode them

BEGIN;

CREATE TABLE "currency_glyph" (
    id serial PRIMARY KEY NOT NULL,
    glyph CHAR NOT NULL DEFAULT '$',
    html_entity VARCHAR(8) NOT NULL DEFAULT '&36;'
);

INSERT INTO currency_glyph (glyph, html_entity)
SELECT '£', '&pound;' UNION
SELECT '$', '&#36;'    UNION
SELECT '€', '&euro;';

CREATE TABLE "link_currency__currency_glyph" (
    currency_id INTEGER REFERENCES currency(id),
    currency_glyph_id INTEGER REFERENCES currency_glyph(id)
);

INSERT INTO link_currency__currency_glyph (currency_id, currency_glyph_id)
SELECT c.id, cg.id FROM currency c, currency_glyph cg WHERE c.currency='GBP' AND cg.glyph='£' UNION
SELECT c.id, cg.id FROM currency c, currency_glyph cg WHERE c.currency='USD' AND cg.glyph='$' UNION
SELECT c.id, cg.id FROM currency c, currency_glyph cg WHERE c.currency='AUD' AND cg.glyph='$' UNION
SELECT c.id, cg.id FROM currency c, currency_glyph cg WHERE c.currency='EUR' AND cg.glyph='€';


ALTER TABLE public."currency_glyph" OWNER TO postgres;

GRANT ALL ON TABLE "currency_glyph" TO postgres;
GRANT ALL ON TABLE "currency_glyph" TO www;

ALTER TABLE public."link_currency__currency_glyph" OWNER TO postgres;

GRANT ALL ON TABLE "link_currency__currency_glyph" TO postgres;
GRANT ALL ON TABLE "link_currency__currency_glyph" TO www;

COMMIT;