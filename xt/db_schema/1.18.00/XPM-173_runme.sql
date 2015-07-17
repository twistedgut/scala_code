--
--  XPM-173
--      Coupon maximum usages - text box to freely enter quantity usage
--      http://jira:8080/browse/XPM-173
--
--      Assignee:  	 Chisel Wright

BEGIN;

    -- limit to (freeform) items
    \set grpsql '(select id from promotion.coupon_restriction_group where name=\'Item Limit\')'
    INSERT INTO promotion.coupon_restriction
        (id, idx, description, group_id, usage_limit)
    VALUES
        (25, 59, 'limited to [ __ ] items', :grpsql, -1)
    ;

    -- limit to (freeform) orders
    \set grpsql '(select id from promotion.coupon_restriction_group where name=\'Order Limit\')'
    INSERT INTO promotion.coupon_restriction
        (id, idx, description, group_id, usage_limit)
    VALUES
        (26, 119, 'limited to [ __ ] orders', :grpsql, -1)
    ;

    -- the new field required to store the custom value
    ALTER TABLE promotion.detail
        ADD COLUMN coupon_custom_limit integer
    ;

    -- add missing columns to audit table
    ALTER TABLE audit.promotion_detail
        ADD COLUMN restrict_by_weeks boolean;
    ALTER TABLE audit.promotion_detail
        ADD COLUMN restrict_x_weeks integer;
    ALTER TABLE audit.promotion_detail
        ADD COLUMN coupon_custom_limit integer;
COMMIT;
