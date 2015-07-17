--
-- CANDO-2909: Add CONRAD method for 3rd Party payment status
--

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
    'Payment Status',
    'Public::Orders',
    'get_current_payment_status',
    NULL,
    ( SELECT id FROM fraud.return_value_type WHERE type = 'string' ),
    'Orders::ThirdPartyPaymentMethodStatusMap->search( { id => { "!=" => 0 } }, { order_by => "third_party_status", distinct => 1, select => [ "third_party_status", "third_party_status" ], as => [ "id", "value" ] } )',
    1
);

COMMIT WORK;
