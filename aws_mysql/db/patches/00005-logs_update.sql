-- liquibase formatted sql
-- changeset j.maslen:5

ALTER TABLE log MODIFY reason_id BIGINT UNSIGNED NOT NULL;
ALTER TABLE log MODIFY quantity_id BIGINT UNSIGNED NOT NULL;

ALTER TABLE log ADD FOREIGN KEY (reason_id) REFERENCES reason(id);
ALTER TABLE log ADD FOREIGN KEY (quantity_id) REFERENCES quantity(id);

ALTER TABLE log
    ADD COLUMN business_id BIGINT UNSIGNED,
    ADD FOREIGN KEY (business_id) REFERENCES business(id);
