BEGIN;
    ALTER TABLE voucher.code
        ADD COLUMN expiry_date timestamp with time zone,
        ADD COLUMN source text,
        ADD COLUMN send_reminder_email boolean NOT NULL default FALSE
    ;

    ALTER TABLE voucher.credit_log DROP COLUMN currency_id;
    ALTER TABLE voucher.credit_log RENAME shipment_id TO spent_on_shipment_id;
    CREATE INDEX code_id_idx ON voucher.credit_log(code_id);
    CREATE INDEX spent_on_shipment_id_idx ON voucher.credit_log(spent_on_shipment_id);
COMMIT;
