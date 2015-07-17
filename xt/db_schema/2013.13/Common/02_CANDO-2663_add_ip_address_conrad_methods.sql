-- CANDO-2663 Fraud Rules methods to check if ip address used before
--
--

BEGIN WORK;

INSERT INTO fraud.method ( description,
                           object_to_use,
                           method_to_call,
                           method_parameters,
                           return_value_type_id
                         )
VALUES
( 'Orders from this IP Address within 2 hours before order',
  'Public::Orders',
  'ip_address_used_before',
  '[{ "date_condition":"order", "include_cancelled":1, "period":"hour", "count":2 }]',
  1
),
( 'Orders from this IP Address within 24 hours before order',
  'Public::Orders',
  'ip_address_used_before',
  '[{ "date_condition":"order", "include_cancelled":1, "period":"hour", "count":24 }]',
  1
),
( 'Orders from this IP Address within week before order',
  'Public::Orders',
  'ip_address_used_before',
  '[{ "date_condition":"order", "include_cancelled":1, "period":"week", "count":1 }]',
  1
),
( 'Cancelled Order from this IP Address within 2 hour before order',
  'Public::Orders',
  'ip_address_used_before',
  '[{ "date_condition":"order", "cancelled_only":1, "period":"hour", "count":2 }]',
  1
),
( 'Cancelled Orders from this IP Address within 24 hours before order',
  'Public::Orders',
  'ip_address_used_before',
  '[{ "date_condition":"order", "cancelled_only":1, "period":"hour", "count":24 }]',
  1
),
( 'Cancelled Orders from this IP Address within week before order',
  'Public::Orders',
  'ip_address_used_before',
  '[{ "date_condition":"order", "cancelled_only":1, "period":"week", "count":1 }]',
  1
);

COMMIT WORK;
