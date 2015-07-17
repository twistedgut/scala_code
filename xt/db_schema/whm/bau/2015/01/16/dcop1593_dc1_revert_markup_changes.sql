-- To update wording for UK next day shipment option
UPDATE shipping.description
SET public_title = 'Next Business Day',
    public_name = 'Next Business Day',
    estimated_delivery = 'Delivery: next business day, 9am-5pm, Mon-Fri',
    long_delivery_description = '&bull; Delivery between 9am-5pm, Monday to Friday<br/>&bull; Orders placed before 3pm Monday to Friday will be delivered next business day<br/>&bull; Orders placed after 3pm on Friday will be delivered on Tuesday'
WHERE name = 'UK Next Business Day';

-- To update wording for France next day shipment option
UPDATE shipping.description
SET public_title = 'Next Business Day',
    public_name = 'Next Business Day',
    estimated_delivery = 'Delivery: next business day, 9am-5pm, Mon-Fri',
    long_delivery_description = '&bull;  Delivery between 9am-5pm, Monday to Friday <br />&bull;  Orders placed before 4pm Monday to Friday will be delivered next business day <br  />&bull; Orders placed after 4pm on Friday will be delivered on Tuesday'
WHERE name = 'France Next Business Day';

-- To update wording for Germany next day shipment option
UPDATE shipping.description
SET public_title = 'Next Business Day',
    public_name = 'Next Business Day',
    estimated_delivery = 'Delivery: next business day, 9am-5pm, Mon-Fri',
    long_delivery_description = '&bull;  Delivery between 9am-5pm, Monday to Friday <br />&bull;  Orders placed before 4pm Monday to Friday will be delivered next business day <br  />&bull; Orders placed after 4pm on Friday will be delivered on Tuesday'
WHERE name = 'Germany Next Business Day';