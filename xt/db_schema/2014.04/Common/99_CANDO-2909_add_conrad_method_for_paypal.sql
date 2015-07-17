--
--
--

BEGIN WORK;

INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    processing_cost
) VALUES (
    'Paid Using PayPal',
    'Public::Orders',
    'is_paid_using_the_third_party_psp',
    '["PayPal"]',
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    2
);

COMMIT WORK;
