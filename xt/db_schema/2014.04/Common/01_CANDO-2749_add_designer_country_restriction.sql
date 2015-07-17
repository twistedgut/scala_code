-- CANDO-2749: Add a designer country restriction to
--             ShippingRestrictionActions in the system config tables and make
--             the public.country table column 'code' unique.

BEGIN WORK;

-- Add the new system configuration settings.
INSERT INTO system_config.config_group_setting (
    config_group_id,
    setting,
    value,
    sequence,
    active
)
VALUES (
    -- Used to restrict shipments by designer country.
    ( SELECT id FROM system_config.config_group WHERE name = 'ShippingRestrictionActions' ),
    'Designer Country',
    'restrict',
    0,
    TRUE
),(
    -- Used when the designer service fails in some way when determining the
    -- above shipping restriction. We're using a new restriction type of
    -- 'silent_restrict', which does exactly what it says in the tin, it is
    -- identical to restrict, except it doesn't include it in email alerts.
    -- See: Shipment::restrictions in XT::Rules::Definitions for more details.
    ( SELECT id FROM system_config.config_group WHERE name = 'ShippingRestrictionActions' ),
    'Designer Service Error',
    'silent_restrict',
    0,
    TRUE
);

-- To ensure that when we lookup a country by name, we are also guaranteed to
-- get a unique country code (they're already unique, this is just to ensure
-- it remains that way).
ALTER TABLE public.country
    ADD UNIQUE ( code );

COMMIT WORK;

