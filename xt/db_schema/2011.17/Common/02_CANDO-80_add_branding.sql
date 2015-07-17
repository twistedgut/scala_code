-- CANDO-80: Add some more Branding to be
--           used in Premier Delivery Alerts

BEGIN WORK;

INSERT INTO branding (code,description) VALUES
('PREM_NAME', 'Public Name for Premier Service'),
('EMAIL_SIGNOFF', 'The Signoff for Emails' ),
('PLAIN_NAME', 'Just the Company Name without any ''.com'' in it' )
;

COMMIT WORK;
