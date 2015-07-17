--
--  XPM-173
--      Coupon maximum usages - text box to freely enter quantity usage
--      http://jira:8080/browse/XPM-173
--
--      Assignee:  	 Chisel Wright

BEGIN;

    DELETE FROM promotion.coupon_restriction
        WHERE id IN (25, 26)
    ;

    ALTER TABLE promotion.detail DROP COLUMN coupon_custom_limit;

    ALTER TABLE audit.promotion_detail DROP COLUMN restrict_by_weeks;
    ALTER TABLE audit.promotion_detail DROP COLUMN restrict_x_weeks;
    ALTER TABLE audit.promotion_detail DROP COLUMN coupon_custom_limit;
COMMIT;
