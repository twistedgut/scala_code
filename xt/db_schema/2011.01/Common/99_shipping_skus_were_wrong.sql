BEGIN;
    update packaging_type set channel_id=null;
COMMIT;
