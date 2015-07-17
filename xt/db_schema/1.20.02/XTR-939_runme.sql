-- http://jira:8080/browse/XTR-939
--
--  Remove Item Limitation Options
--
--      Remove Item Limitation options from the Item / Order Limitation drop
--      sown menu on the Promotion Overview tab.
--
--      Will only require Order Limitation and the options to only reflect
--      order limitation.
BEGIN;
    -- drop the FKs on the audit table (!!)
    ALTER TABLE audit.promotion_detail DROP CONSTRAINT promotion_detail_coupon_restriction_id_fkey;
    ALTER TABLE audit.promotion_detail DROP CONSTRAINT promotion_detail_coupon_generation_id_fkey;
    ALTER TABLE audit.promotion_detail DROP CONSTRAINT promotion_detail_coupon_target_id_fkey;
    ALTER TABLE audit.promotion_detail DROP CONSTRAINT promotion_detail_created_by_fkey;
    ALTER TABLE audit.promotion_detail DROP CONSTRAINT promotion_detail_last_modified_by_fkey;
    ALTER TABLE audit.promotion_detail DROP CONSTRAINT promotion_detail_price_group_id_fkey;
    ALTER TABLE audit.promotion_detail DROP CONSTRAINT promotion_detail_target_city_id_fkey;
COMMIT;

BEGIN;
    -- less typing, more readable
    \set orderlimitid '(SELECT id FROM promotion.coupon_restriction_group WHERE name=\'Order Limit\')'
    \set itemlimitid  '(SELECT id FROM promotion.coupon_restriction_group WHERE name=\'Item Limit\' )'

    -- make all coupons into order-limits
    UPDATE  promotion.coupon
    SET     usage_type_id         = :orderlimitid
    ;


    -- change the FK ids in the detail table from item to order
    UPDATE  promotion.detail
    SET     coupon_restriction_id =
            (SELECT id FROM promotion.coupon_restriction WHERE description='limited to 1 order')
    WHERE   coupon_restriction_id =
            (SELECT id FROM promotion.coupon_restriction WHERE description='limited to 1 item')
    ;
    UPDATE  promotion.detail
    SET     coupon_restriction_id =
            (SELECT id FROM promotion.coupon_restriction WHERE description='limited to 2 orders')
    WHERE   coupon_restriction_id =
            (SELECT id FROM promotion.coupon_restriction WHERE description='limited to 2 items')
    ;
    UPDATE  promotion.detail
    SET     coupon_restriction_id =
            (SELECT id FROM promotion.coupon_restriction WHERE description='limited to 3 orders')
    WHERE   coupon_restriction_id =
            (SELECT id FROM promotion.coupon_restriction WHERE description='limited to 3 items')
    ;
    UPDATE  promotion.detail
    SET     coupon_restriction_id =
            (SELECT id FROM promotion.coupon_restriction WHERE description='limited to 4 orders')
    WHERE   coupon_restriction_id =
            (SELECT id FROM promotion.coupon_restriction WHERE description='limited to 4 items')
    ;
    UPDATE  promotion.detail
    SET     coupon_restriction_id =
            (SELECT id FROM promotion.coupon_restriction WHERE description='limited to 5 orders')
    WHERE   coupon_restriction_id =
            (SELECT id FROM promotion.coupon_restriction WHERE description='limited to 5 items')
    ;
    UPDATE  promotion.detail
    SET     coupon_restriction_id =
            (SELECT id FROM promotion.coupon_restriction WHERE description='unlimited orders')
    WHERE   coupon_restriction_id =
            (SELECT id FROM promotion.coupon_restriction WHERE description='unlimited items')
    ;
    UPDATE  promotion.detail
    SET     coupon_restriction_id =
            (SELECT id FROM promotion.coupon_restriction WHERE description='limited to 10 orders')
    WHERE   coupon_restriction_id =
            (SELECT id FROM promotion.coupon_restriction WHERE description='limited to 10 items')
    ;
    UPDATE  promotion.detail
    SET     coupon_restriction_id =
            (SELECT id FROM promotion.coupon_restriction WHERE description='limited to 25 orders')
    WHERE   coupon_restriction_id =
            (SELECT id FROM promotion.coupon_restriction WHERE description='limited to 25 items')
    ;
    UPDATE  promotion.detail
    SET     coupon_restriction_id =
            (SELECT id FROM promotion.coupon_restriction WHERE description='limited to 50 orders')
    WHERE   coupon_restriction_id =
            (SELECT id FROM promotion.coupon_restriction WHERE description='limited to 50 items')
    ;
    UPDATE  promotion.detail
    SET     coupon_restriction_id =
            (SELECT id FROM promotion.coupon_restriction WHERE description='limited to 100 orders')
    WHERE   coupon_restriction_id =
            (SELECT id FROM promotion.coupon_restriction WHERE description='limited to 100 items')
    ;
    UPDATE  promotion.detail
    SET     coupon_restriction_id =
            (SELECT id FROM promotion.coupon_restriction WHERE description='limited to 500 orders')
    WHERE   coupon_restriction_id =
            (SELECT id FROM promotion.coupon_restriction WHERE description='limited to 500 items')
    ;
    UPDATE  promotion.detail
    SET     coupon_restriction_id =
            (SELECT id FROM promotion.coupon_restriction WHERE description='limited to 1000 orders')
    WHERE   coupon_restriction_id =
            (SELECT id FROM promotion.coupon_restriction WHERE description='limited to 1000 items')
    ;
    UPDATE  promotion.detail
    SET     coupon_restriction_id =
            (SELECT id FROM promotion.coupon_restriction WHERE description='limited to [ __ ] orders')
    WHERE   coupon_restriction_id =
            (SELECT id FROM promotion.coupon_restriction WHERE description='limited to [ __ ] items')
    ;


    -- delete item-based menu options
    DELETE  FROM promotion.coupon_restriction
    WHERE   group_id = :itemlimitid
    ;
COMMIT;
