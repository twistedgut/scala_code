-- This patch bumps the sequence for following events, leaving space for fixed
-- events and promotions (via JT's script)
BEGIN;
    SELECT setval('event.detail_id_seq', 299);
COMMIT;
