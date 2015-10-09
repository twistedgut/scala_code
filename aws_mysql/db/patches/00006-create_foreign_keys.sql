-- liquibase formatted sql
-- changeset j.maslen:6

ALTER TABLE box MODIFY dc_id BIGINT UNSIGNED NOT NULL;
ALTER TABLE box ADD FOREIGN KEY (dc_id) REFERENCES dc(id);

ALTER TABLE link_business__box MODIFY box_id BIGINT UNSIGNED NOT NULL;
ALTER TABLE link_business__box ADD FOREIGN KEY (box_id) REFERENCES box(id);

ALTER TABLE link_business__box MODIFY business_id BIGINT UNSIGNED NOT NULL;
ALTER TABLE link_business__box ADD FOREIGN KEY (business_id) REFERENCES business(id);

ALTER TABLE quantity MODIFY box_id BIGINT UNSIGNED NOT NULL;
ALTER TABLE quantity ADD FOREIGN KEY (box_id) REFERENCES box(id);
