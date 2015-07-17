-- CANDO-8484: Add a method for CONRAD to use that
--             can return TRUE when 'Klarna' has
--             been used as the Payment Provider

BEGIN WORK;

INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    processing_cost
) VALUES (
    'Paid Using Klarna',
    'Public::Orders',
    'is_paid_using_the_third_party_psp',
    '["Klarna"]',
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    2
)
;

COMMIT WORK;
