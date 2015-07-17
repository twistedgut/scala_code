-- For JimmyChoo (and potentially other 3rd parties) we need to record
-- their SKUs. We can't guarantee the SKUs are composable from other data like
-- NAP SKUs so we're recording it alongside the variant. We're also storing the
-- business_id because we can't guarantee that different third parties will have
-- unique SKUs but we do want the SKUs to be unique per business.

BEGIN;

CREATE TABLE public.third_party_sku (
    id serial PRIMARY KEY,
    variant_id INTEGER REFERENCES variant(id),
    business_id INTEGER REFERENCES business(id),
    third_party_sku VARCHAR(255) NOT NULL
);

ALTER TABLE public.third_party_sku
ADD CONSTRAINT business_id_sku_key UNIQUE (business_id, third_party_sku);

ALTER TABLE public.third_party_sku
ADD CONSTRAINT variant_id_key UNIQUE (variant_id);

GRANT ALL ON TABLE third_party_sku TO postgres;
GRANT ALL ON TABLE third_party_sku TO www;
GRANT SELECT ON TABLE third_party_sku TO perlydev;

GRANT ALL ON SEQUENCE third_party_sku_id_seq TO postgres;
GRANT ALL ON SEQUENCE third_party_sku_id_seq TO www;
GRANT SELECT ON SEQUENCE third_party_sku_id_seq TO perlydev;

COMMIT;
