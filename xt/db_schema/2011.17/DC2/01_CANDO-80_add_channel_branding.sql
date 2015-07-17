-- CANDO-80: Add Branding to Sales Channels for:
--           Premier Name, Email Signoff & Plain Name

BEGIN WORK;

--
-- Premier Name
--
INSERT INTO channel_branding (channel_id,branding_id,value)
SELECT  ch.id,
        ( SELECT id FROM branding WHERE code = 'PREM_NAME' ),
        CASE b.config_section
            WHEN 'NAP'
                THEN 'New York Premier'
            WHEN 'MRP'
                THEN 'New York Premier'
        END
FROM    channel ch
        JOIN business b ON b.id = ch.business_id
                        AND b.config_section IN ('NAP','MRP')
ORDER BY ch.id
;


--
-- Email Signoff
--
INSERT INTO channel_branding (channel_id,branding_id,value)
SELECT  ch.id,
        ( SELECT id FROM branding WHERE code = 'EMAIL_SIGNOFF' ),
        CASE b.config_section
            WHEN 'NAP'
                THEN 'Best regards'
            WHEN 'MRP'
                THEN 'Yours sincerely'
        END
FROM    channel ch
        JOIN business b ON b.id = ch.business_id
                        AND b.config_section IN ('NAP','MRP')
ORDER BY ch.id
;


--
-- Plain Name
--
INSERT INTO channel_branding (channel_id,branding_id,value)
SELECT  ch.id,
        ( SELECT id FROM branding WHERE code = 'PLAIN_NAME' ),
        CASE b.config_section
            WHEN 'NAP'
                THEN 'NET-A-PORTER'
            WHEN 'OUTNET'
                THEN 'THE OUTNET'
            WHEN 'MRP'
                THEN 'MR PORTER'
            WHEN 'JC'
                THEN 'JIMMY CHOO'
        END
FROM    channel ch
        JOIN business b ON b.id = ch.business_id
ORDER BY ch.id
;

COMMIT WORK;
