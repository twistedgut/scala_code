--
-- SHIP-384: Enable "Next Day" shipping to Germany
--

BEGIN;

    -- Update the description
    INSERT INTO shipping.description
        (name, public_name, title, public_title, short_delivery_description, long_delivery_description, estimated_delivery, delivery_confirmation, shipping_charge_id)
        VALUES (
            'Germany Next Business Day',
            'Next Business Day',
            'Next Business Day',
            'Next Business Day',
            'For orders placed Mon-Fri by 4 PM',
            '&bull;Delivery between 9am-5pm, Monday to Friday <br />&bull;  Orders placed before 4pm CEST Monday to Friday will be delivered next business day <br  />&bull; Orders placed after 4pm CEST on Friday, or on Saturday or on Sunday will be delivered on Tuesday',
            'Delivery: next business day, Mon-Fri, 9am-5pm',
            'You will receive an email confirming the dispatch of your order and your Air Waybill number.',
            (SELECT id FROM shipping_charge WHERE sku = '9000524-004')
        );

        -- Update the region_charge
        -- (using region as the price is the same all over the Europe)
        INSERT INTO shipping.region_charge (shipping_charge_id, region_id, currency_id, charge) VALUES
        (
            (SELECT id FROM shipping_charge WHERE sku = '9000524-004'),
            (SELECT id FROM region WHERE region = 'Europe'),
            (SELECT id FROM currency WHERE currency = 'EUR'),
            '25.00'
        ),
        (
            (SELECT id FROM shipping_charge WHERE sku = '9000524-004'),
            (SELECT id FROM region WHERE region = 'Europe Other'),
            (SELECT id FROM currency WHERE currency = 'EUR'),
            '25.00'
        );

COMMIT;
