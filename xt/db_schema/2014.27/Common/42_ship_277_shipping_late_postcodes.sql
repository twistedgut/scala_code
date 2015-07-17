BEGIN;

    -- SHIP-277: Notify customers for shipments to postcodes that we can not (and could
    -- never have) fulfilled the delivery promise for
    CREATE TABLE public.shipping_charge_late_postcode (
        id SERIAL PRIMARY KEY,
        shipping_charge_id INT NOT NULL REFERENCES public.shipping_charge(id),
        country_id INT NOT NULL REFERENCES public.country(id),
        postcode TEXT NOT NULL
    );
    COMMENT ON TABLE public.shipping_charge_late_postcode
        IS 'Identifies postcodes where we can never fulfil the delivery promise for a particular shipping option';
    ALTER TABLE public.shipping_charge_late_postcode OWNER TO www;

COMMIT;