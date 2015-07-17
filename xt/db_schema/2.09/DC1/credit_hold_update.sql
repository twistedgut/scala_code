-- Update the credit hold thresholds

BEGIN;
    UPDATE credit_hold_threshold SET value=1750
        WHERE name='Single Order Value' AND channel_id=1;

    UPDATE credit_hold_threshold SET value=600
        WHERE name='Single Order Value' AND channel_id=3;

    UPDATE credit_hold_threshold SET value=2750
        WHERE name='Weekly Order Value' AND channel_id=1;
COMMIT;
