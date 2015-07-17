-- Correct the tracking URI for DHL Express in DC3

BEGIN;

    UPDATE carrier
        SET tracking_uri = 'http://www.dhl.com.hk/en/express/tracking.shtml?brand=DHL&AWB=<TOKEN>'
        WHERE name = 'DHL Express';

COMMIT;
