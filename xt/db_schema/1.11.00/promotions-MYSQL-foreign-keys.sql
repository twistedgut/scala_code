START TRANSACTION;

-- fix up stupid mysql automatic NOT NULL/DEFAULT VALUE crap!
ALTER TABLE detail MODIFY COLUMN end_date timestamp null;

-- add missing FKs
ALTER TABLE coupon_restriction
    ADD CONSTRAINT FOREIGN KEY
        (group_id) REFERENCES coupon_restriction_group(id)
;

ALTER TABLE detail
    ADD CONSTRAINT FOREIGN KEY
        (target_city_id) REFERENCES target_city(id)
;

ALTER TABLE detail
    ADD CONSTRAINT FOREIGN KEY
        (coupon_target_id) REFERENCES coupon_target(id)
;

ALTER TABLE detail
    ADD CONSTRAINT FOREIGN KEY
        (coupon_restriction_id) REFERENCES coupon_restriction(id)
;

ALTER TABLE detail
    ADD CONSTRAINT FOREIGN KEY
        (price_group_id) REFERENCES price_group(id)
;

ALTER TABLE detail_websites
    ADD CONSTRAINT FOREIGN KEY
        (detail_id) REFERENCES detail(id)
;

ALTER TABLE detail_websites
    ADD CONSTRAINT FOREIGN KEY
        (website_id) REFERENCES website(id)
;

ALTER TABLE detail_seasons
    ADD CONSTRAINT FOREIGN KEY
        (detail_id) REFERENCES detail(id)
;

--ALTER TABLE detail_seasons
--    ADD CONSTRAINT FOREIGN KEY
--        (season_id) REFERENCES season(id)
--;

ALTER TABLE detail_designers
    ADD CONSTRAINT FOREIGN KEY
        (detail_id) REFERENCES detail(id)
;

--ALTER TABLE detail_designers
--    ADD CONSTRAINT FOREIGN KEY
--        (designer_id) REFERENCES designer(id)
--;

ALTER TABLE detail_producttypes
    ADD CONSTRAINT FOREIGN KEY
        (detail_id) REFERENCES detail(id)
;

--ALTER TABLE detail_producttypes
--    ADD CONSTRAINT FOREIGN KEY
--        (producttype_id) REFERENCES product_type(id)
--;

ALTER TABLE detail_shippingoptions
    ADD CONSTRAINT FOREIGN KEY
        (detail_id) REFERENCES detail(id)
;

ALTER TABLE detail_shippingoptions
    ADD CONSTRAINT FOREIGN KEY
        (shippingoption_id) REFERENCES shipping_option(id)
;

ALTER TABLE coupon
    ADD CONSTRAINT FOREIGN KEY
        (usage_type_id) REFERENCES coupon_restriction_group(id)
;

COMMIT;
