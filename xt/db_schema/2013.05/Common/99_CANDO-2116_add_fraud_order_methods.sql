-- Story:       CANDO-2116
-- Sub-Task:    CANDO-2156
-- Description: Add rows to the fraud.method table for 'Is First Order, 'Is Second Order' and 'Is Third Order'

BEGIN WORK;

INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    rule_action_helper_method,
    processing_cost
) VALUES (
    E'Is Customer\'s First Order',
    'Public::Orders',
    'is_customers_nth_order',
    '[1]',
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    NULL,
    1
) , (
    E'Is Customer\'s Second Order',
    'Public::Orders',
    'is_customers_nth_order',
    '[2]',
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    NULL,
    1
) , (
    E'Is Customer\'s Third Order',
    'Public::Orders',
    'is_customers_nth_order',
    '[3]',
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    NULL,
    1
) , (
    'Order Total Value',
    'Public::Orders',
    'get_total_value_in_local_currency',
    NULL,
    ( SELECT id FROM fraud.return_value_type WHERE type = 'decimal' ),
    NULL,
    1
), (
    'Shipping Address Country',
    'Public::Orders',
    'get_standard_class_shipment_address_country',
    NULL,
    ( SELECT id FROM fraud.return_value_type WHERE type = 'string' ),
    'Public::Country->search( { id => { "!=" => 0 } }, { order_by => "country", select => [ "country", "country" ], as => [ "id", "value" ] } )',
    1
),(
    'Payment Card Type',
    'Public::Orders',
    'payment_card_type',
    NULL,
    ( SELECT id FROM fraud.return_value_type WHERE type = 'string' ),
    NULL,
    1
),(
    'Payment Card AVS Response',
    'Public::Orders',
    'payment_card_avs_response',
    NULL,
    ( SELECT id FROM fraud.return_value_type WHERE type = 'string' ),
    NULL,
    1
),(
    'Is Payment Card New for Customer',
    'Public::Orders',
    'is_payment_card_new_for_customer',
    NULL,
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    NULL,
    1
),(
    'Has this Payment Card Been Used Before',
    'Public::Orders',
    'has_payment_card_been_used_before',
    NULL,
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    NULL,
    1
),(
    'Shipment Type',
    'Public::Orders',
    'get_standard_class_shipment_type_id',
    NULL,
    ( SELECT id FROM fraud.return_value_type WHERE type = 'dbid' ),
    'Public::ShipmentType->search( { id => { "!=" => 0 } }, { order_by => "type", select => [ "id", "type" ], as => [ "id", "value" ] } )',
    1
),(
    'Shipment Address Country is Low Risk',
    'Public::Orders',
    'low_risk_shipping_country',
    NULL,
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    NULL,
    1
),(
    'Shipping Address used before',
    'Public::Orders',
    'shipping_address_used_before',
    NULL,
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    NULL,
    1
),(
    'Shipping Address Used Before By This Customer',
    'Public::Orders',
    'shipping_address_used_before_for_customer',
    NULL,
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    NULL,
    1
),(
    'Order Contains Virtual Voucher',
    'Public::Orders',
    'contains_a_virtual_voucher',
    NULL,
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    NULL,
    1
),(
    'Order Contains Voucher',
    'Public::Orders',
    'contains_a_voucher',
    NULL,
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    NULL,
    1
),(
    'Is In The Hotlist',
    'Public::Orders',
    'is_in_hotlist',
    NULL,
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    NULL,
    1
),(
    'Shipping Address Equal To Billing Address',
    'Public::Orders',
    'standard_shipment_address_matches_invoice_address',
    NULL,
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    NULL,
    1
);

COMMIT;
