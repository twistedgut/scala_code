-- CANDO-2354: Add the CMS Keys and Subjects for the
--             Pre-Order Emails

BEGIN WORK;

UPDATE  correspondence_templates
    SET subject     =
            CASE name
                WHEN 'Pre Order - Complete'     THEN 'Your [% brand_name %] pre-order confirmation - [% pre_order_number %]'
                WHEN 'Pre Order - Size Change'  THEN 'Your [% brand_name %] pre-order - [% pre_order_number %]'
                WHEN 'Pre Order - Cancel'       THEN 'Your [% brand_name %] pre-order cancellation - [% pre_order_number %]'
                ELSE NULL
            END,
        id_for_cms  =
            CASE name
                WHEN 'Pre Order - Complete'     THEN 'TT_PRE_ORDER_COMPLETE'
                WHEN 'Pre Order - Size Change'  THEN 'TT_PRE_ORDER_SIZE_CHANGE'
                WHEN 'Pre Order - Cancel'       THEN 'TT_PRE_ORDER_CANCEL'
                ELSE id_for_cms
            END
WHERE   name LIKE 'Pre Order -%'
AND     id_for_cms IS NULL
;

COMMIT WORK;
