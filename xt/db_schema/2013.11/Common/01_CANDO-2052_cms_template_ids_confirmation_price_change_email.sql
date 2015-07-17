-- CANDO-2052: Updating correspondence_templates table to have CMS ID for 'Confirmation Price Change' Email.
BEGIN WORK;

UPDATE  correspondence_templates
SET     subject    = 'Your order - [% order_number %]',
        id_for_cms = 'TT_CONFIRM_PRICE_CHANGE'
WHERE   name       = 'Confirm Price Change'
AND     id_for_cms IS NULL;

COMMIT WORK;
