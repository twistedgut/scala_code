BEGIN;
    --CREATE INDEX idx_mail_message       ON mail(message);

    CREATE INDEX idx_name_name          ON name(name);

    CREATE INDEX idx_addressing_name    ON addressing(name);
    CREATE INDEX idx_addressing_role    ON addressing(role);
    CREATE INDEX idx_addressing_address ON addressing(address);

    CREATE INDEX idx_address_address    ON address(address);

    CREATE INDEX idx_summary_mail       ON summary(mail);
    CREATE INDEX idx_summary_subject    ON summary(subject);

    CREATE INDEX idx_maildate_date      ON mail_date(date);
COMMIT;
