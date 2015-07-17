-- NAPAC-212 Update contents of channel.is_enable so only NAP APAC is enabled

BEGIN WORK;

-- disable anything not NAP APAC
UPDATE channel SET is_enabled = FALSE WHERE
    business_id != (SELECT id FROM business WHERE config_section = 'NAP');

COMMIT WORK;
