-- CANDO-2156: Populates fraud.method table with available methods

BEGIN WORK;

--
-- Customer is an EIP
--
INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    rule_action_helper_method,
    processing_cost ) VALUES
    ('Customer is an EIP', 'Public::Customer', 'is_an_eip', NULL,
    (SELECT id FROM fraud.return_value_type WHERE type = 'boolean'), NULL, '1' );

--
-- Customer is Staff Member
--
INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    rule_action_helper_method,
    processing_cost ) VALUES
    ('Customer is Staff Member', 'Public::Customer', 'is_category_staff', NULL,
    (SELECT id FROM fraud.return_value_type WHERE type = 'boolean'), NULL,'1');

--
-- Customer is Staff Member (ALL CHANNELS)
--
INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    rule_action_helper_method,
    processing_cost ) VALUES
    ('Customer is Staff Member (ALL CHANNELS)', 'Public::Customer',
    'is_staff_on_any_channel', NULL,
    (SELECT id FROM fraud.return_value_type WHERE type = 'boolean'), NULL, '5');

--
-- Customer is on Finance Watch
--
INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    rule_action_helper_method,
    processing_cost ) VALUES
    ('Customer is on Finance Watch',
    'Public::Customer',
    'has_finance_watch_flag',
    NULL,
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    NULL,
    '5');

--
-- Customer is on Finance Watch ( ALL CHANNELS )
--
INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    rule_action_helper_method,
    processing_cost ) VALUES
    ('Customer is on Finance Watch (ALL CHANNELS)',
    'Public::Customer',
    'is_on_finance_watch_on_any_channel',
    NULL,
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    NULL,
    '15');

--
-- Customer has order on Credit Hold
--
INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    rule_action_helper_method,
    processing_cost ) VALUES
    ('Customer has order on Credit Hold',
    'Public::Customer',
    'has_orders_on_credit_hold',
    '[{"exclude_order_id":P[SMC.Public::Orders.id:nocache]}]',
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    NULL,
    '10');

--
-- Customer has order on Credit Hold ( ALL CHANNELS )
--
INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    rule_action_helper_method,
    processing_cost ) VALUES
    ('Customer has order on Credit Hold (ALL CHANNELS)',
    'Public::Customer',
    'has_orders_on_credit_hold_on_any_channel',
    '[{"exclude_order_id":P[SMC.Public::Orders.id:nocache]}]',
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    NULL,
    '20');

--
-- Customer has order on Credit Check
--
INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    rule_action_helper_method,
    processing_cost ) VALUES
    ('Customer has order on Credit Check',
    'Public::Customer',
    'has_order_on_credit_check',
    '[{"exclude_order_id":P[SMC.Public::Orders.id:nocache]}]',
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    NULL,
    '10');

--
-- Customer has order on Credit Check ( ALL CHANNELS )
--
INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    rule_action_helper_method,
    processing_cost ) VALUES
    ('Customer has order on Credit Check (ALL CHANNELS)',
    'Public::Customer',
    'has_order_on_credit_check_on_any_channel',
    '[{"exclude_order_id":P[SMC.Public::Orders.id:nocache]}]',
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    NULL,
    '20');

--
-- Number of orders in last 7 days ( ALL CHANNELS )
--
INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    rule_action_helper_method,
    processing_cost ) VALUES
    ('Number of Orders in last 7 days (ALL CHANNELS)',
    'Public::Customer',
    'number_of_orders_in_last_n_periods',
    '[{"count":7,"period":"day","on_all_channels":1}]',
    ( SELECT id FROM fraud.return_value_type WHERE type = 'integer' ),
    NULL,
    '20');

--
-- Number of orders in last 7 days
--
INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    rule_action_helper_method,
    processing_cost ) VALUES
    ('Number of Orders in last 7 days',
    'Public::Customer',
    'number_of_orders_in_last_n_periods',
    '[{"count":7,"period":"day"}]',
    ( SELECT id FROM fraud.return_value_type WHERE type = 'integer' ),
    NULL,
    '10');

--
-- Number of orders in last 24 Hours ( ALL CHANNELS )
--
INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    rule_action_helper_method,
    processing_cost ) VALUES
    ('Number of Orders in last 24 Hours (ALL CHANNELS)',
    'Public::Customer',
    'number_of_orders_in_last_n_periods',
    '[{"count":24,"period":"hour","on_all_channels":1}]',
    ( SELECT id FROM fraud.return_value_type WHERE type = 'integer' ),
    NULL,
    '10');

--
-- Number of orders in last 24 Hours
--
INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    rule_action_helper_method,
    processing_cost ) VALUES
    ('Number of Orders in last 24 Hours',
    'Public::Customer',
    'number_of_orders_in_last_n_periods',
    '[{"count":24,"period":"hour"}]',
    ( SELECT id FROM fraud.return_value_type WHERE type = 'integer' ),
    NULL,
    '5');

--
-- Has placed any orders in last 1 month ( ALL CHANNELS )
--
INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    rule_action_helper_method,
    processing_cost ) VALUES
    ('Has placed any orders in last 1 Month (ALL CHANNELS)',
    'Public::Customer',
    'has_placed_order_in_last_n_periods',
    '[{"count":1,"period":"month","on_all_channels":1}]',
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    NULL,
    '20');

--
-- Has placed any orders in last 1 months
--
INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    rule_action_helper_method,
    processing_cost ) VALUES
    ('Has placed any orders in last 1 Month',
    'Public::Customer',
    'has_placed_order_in_last_n_periods',
    '[{"count":1,"period":"month"}]',
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    NULL,
    '20');

--
-- Has placed any orders in last 2 months ( ALL CHANNELS )
--
INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    rule_action_helper_method,
    processing_cost ) VALUES
    ('Has placed any orders in last 2 Months (ALL CHANNELS)',
    'Public::Customer',
    'has_placed_order_in_last_n_periods',
    '[{"count":2,"period":"month","on_all_channels":1}]',
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    NULL,
    '20');

--
-- Has placed any orders in last 2 months
--
INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    rule_action_helper_method,
    processing_cost ) VALUES
    ('Has placed any orders in last 2 Months',
    'Public::Customer',
    'has_placed_order_in_last_n_periods',
    '[{"count":2,"period":"month"}]',
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    NULL,
    '20');

--
-- Has placed any orders in last 3 months ( ALL CHANNELS )
--
INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    rule_action_helper_method,
    processing_cost ) VALUES
    ('Has placed any orders in last 3 Months (ALL CHANNELS)',
    'Public::Customer',
    'has_placed_order_in_last_n_periods',
    '[{"count":3,"period":"month","on_all_channels":1}]',
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    NULL,
    '20');

--
-- Has placed any orders in last 3 months
--
INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    rule_action_helper_method,
    processing_cost ) VALUES
    ('Has placed any orders in last 3 Months',
    'Public::Customer',
    'has_placed_order_in_last_n_periods',
    '[{"count":3,"period":"month"}]',
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    NULL,
    '20');

--
-- Has placed any orders in last 4 months ( ALL CHANNELS )
--
INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    rule_action_helper_method,
    processing_cost ) VALUES
    ('Has placed any orders in last 4 Months (ALL CHANNELS)',
    'Public::Customer',
    'has_placed_order_in_last_n_periods',
    '[{"count":4,"period":"month","on_all_channels":1}]',
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    NULL,
    '20');

--
-- Has placed any orders in last 4 months
--
INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    rule_action_helper_method,
    processing_cost ) VALUES
    ('Has placed any orders in last 4 Months',
    'Public::Customer',
    'has_placed_order_in_last_n_periods',
    '[{"count":4,"period":"month"}]',
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    NULL,
    '20');

--
-- Has placed any orders in last 5 months ( ALL CHANNELS )
--
INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    rule_action_helper_method,
    processing_cost ) VALUES
    ('Has placed any orders in last 5 Months (ALL CHANNELS)',
    'Public::Customer',
    'has_placed_order_in_last_n_periods',
    '[{"count":5,"period":"month","on_all_channels":1}]',
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    NULL,
    '20');

--
-- Has placed any orders in last 5 months
--
INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    rule_action_helper_method,
    processing_cost ) VALUES
    ('Has placed any orders in last 5 Months',
    'Public::Customer',
    'has_placed_order_in_last_n_periods',
    '[{"count":5,"period":"month"}]',
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    NULL,
    '20');

--
-- Has placed any orders in last 6 months ( ALL CHANNELS )
--
INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    rule_action_helper_method,
    processing_cost ) VALUES
    ('Has placed any orders in last 6 Months (ALL CHANNELS)',
    'Public::Customer',
    'has_placed_order_in_last_n_periods',
    '[{"count":6,"period":"month","on_all_channels":1}]',
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    NULL,
    '20');

--
-- Has placed any orders in last 6 months
--
INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    rule_action_helper_method,
    processing_cost ) VALUES
    ('Has placed any orders in last 6 Months',
    'Public::Customer',
    'has_placed_order_in_last_n_periods',
    '[{"count":6,"period":"month"}]',
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    NULL,
    '20');

--
-- Has placed any orders in last 9 months ( ALL CHANNELS )
--
INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    rule_action_helper_method,
    processing_cost ) VALUES
    ('Has placed any orders in last 9 Months (ALL CHANNELS)',
    'Public::Customer',
    'has_placed_order_in_last_n_periods',
    '[{"count":9,"period":"month","on_all_channels":1}]',
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    NULL,
    '20');

--
-- Has placed any orders in last 9 months
--
INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    rule_action_helper_method,
    processing_cost ) VALUES
    ('Has placed any orders in last 9 Months',
    'Public::Customer',
    'has_placed_order_in_last_n_periods',
    '[{"count":9,"period":"month"}]',
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    NULL,
    '20');

--
-- Has placed any orders in last 12 months ( ALL CHANNELS )
--
INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    rule_action_helper_method,
    processing_cost ) VALUES
    ('Has placed any orders in last 12 Months (ALL CHANNELS)',
    'Public::Customer',
    'has_placed_order_in_last_n_periods',
    '[{"count":12,"period":"month","on_all_channels":1}]',
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    NULL,
    '20');

--
-- Has placed any orders in last 12 months
--
INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    rule_action_helper_method,
    processing_cost ) VALUES
    ('Has placed any orders in last 12 Months',
    'Public::Customer',
    'has_placed_order_in_last_n_periods',
    '[{"count":12,"period":"month"}]',
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    NULL,
    '20');

--
-- Has placed any orders in last 18 months ( ALL CHANNELS )
--
INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    rule_action_helper_method,
    processing_cost ) VALUES
    ('Has placed any orders in last 18 Months (ALL CHANNELS)',
    'Public::Customer',
    'has_placed_order_in_last_n_periods',
    '[{"count":18,"period":"month","on_all_channels":1}]',
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    NULL,
    '20');

--
-- Has placed any orders in last 18 months
--
INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    rule_action_helper_method,
    processing_cost ) VALUES
    ('Has placed any orders in last 18 Months',
    'Public::Customer',
    'has_placed_order_in_last_n_periods',
    '[{"count":18,"period":"month"}]',
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    NULL,
    '20');

--
-- Customer has placed 4 or more orders ( ALL CHANNELS )
--
INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    rule_action_helper_method,
    processing_cost ) VALUES
    ('Customer has placed 4 or more orders (ALL CHANNELS)',
    'Public::Customer',
    'has_placed_4_or_more_orders',
    '[{"on_all_channels":1}]',
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    NULL,
    '20');

--
-- Customer has placed 4 or more orders
--
INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    rule_action_helper_method,
    processing_cost ) VALUES
    ('Customer has placed 4 or more orders',
    'Public::Customer',
    'has_placed_4_or_more_orders',
    NULL,
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    NULL,
    '15');

--
-- Total Customer Spend over six months
--
INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    rule_action_helper_method,
    processing_cost ) VALUES
    ('Customer Total Spend over 6 months',
    'Public::Customer',
    'total_spend_in_last_n_period',
    '[{"count":6,"period":"month"}]',
    ( SELECT id FROM fraud.return_value_type WHERE type = 'decimal' ),
    NULL,
    '75');

--
-- Total Customer Spend over six months (ALL CHANNELS)
--
INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    rule_action_helper_method,
    processing_cost ) VALUES
    ('Customer Total Spend over 6 months (ALL CHANNELS)',
    'Public::Customer',
    'total_spend_in_last_n_period_on_all_channels',
    '[{"count":6,"period":"month"}]',
    ( SELECT id FROM fraud.return_value_type WHERE type = 'decimal' ),
    NULL,
    '100');

--
-- Total Customer Spend over 7 days
--
INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    rule_action_helper_method,
    processing_cost ) VALUES
    ('Customer Total Spend over 7 days',
    'Public::Customer',
    'total_spend_in_last_n_period',
    '[{"count":7,"period":"day"}]',
    ( SELECT id FROM fraud.return_value_type WHERE type = 'decimal' ),
    NULL,
    '50');

--
-- Total Customer Spend over six months (ALL CHANNELS)
--
INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    rule_action_helper_method,
    processing_cost ) VALUES
    ('Customer Total Spend over 7 days (ALL CHANNELS)',
    'Public::Customer',
    'total_spend_in_last_n_period_on_all_channels',
    '[{"count":7,"period":"day"}]',
    ( SELECT id FROM fraud.return_value_type WHERE type = 'decimal' ),
    NULL,
    '75');

--
-- Customer has been credit checked
--
INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    rule_action_helper_method,
    processing_cost ) VALUES
    ('Customer has been credit checked',
    'Public::Customer',
    'is_credit_checked',
    NULL,
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    NULL,
    '10');

--
-- Customer has orders older than six months (ALL CHANNELS)
--
INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    rule_action_helper_method,
    processing_cost ) VALUES
    ('Customer has orders older than six months (ALL CHANNELS)',
    'Public::Customer',
    'has_orders_older_than_not_cancelled',
    '[{"count":6,"period":"month"}]',
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    NULL,
    '15');

--
-- Customer has orders older than nine months (ALL CHANNELS)
--
INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    rule_action_helper_method,
    processing_cost ) VALUES
    ('Customer has orders older than 9 months (ALL CHANNELS)',
    'Public::Customer',
    'has_orders_older_than_not_cancelled',
    '[{"count":9,"period":"month"}]',
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    NULL,
    '15');

--
-- Customer Class
--
INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    rule_action_helper_method,
    processing_cost ) VALUES
    ('Customer Class',
    'Public::Customer',
    'customer_class_id',
    NULL,
    ( SELECT id FROM fraud.return_value_type WHERE type = 'dbid' ),
    'Public::CustomerClass->search( { id => { "!=" => 0 } }, { order_by => "class", select => [ "id", "class" ], as => [ "id", "value" ] } )',
    '1');

--
-- Customer Category
--
INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    rule_action_helper_method,
    processing_cost ) VALUES
    ('Customer Category',
    'Public::Customer',
    'category_id',
    NULL,
    ( SELECT id FROM fraud.return_value_type WHERE type = 'dbid' ),
    'Public::CustomerCategory->search( { id => { "!=" => 0 } }, { order_by => "category", select => [ "id", "category" ], as => [ "id", "value" ] } )',
    '1');

--
-- Warning - Order has 'High Value' flag
--
INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    rule_action_helper_method,
    processing_cost ) VALUES
    ('Warning - Order has ''High Value'' Flag',
    'Public::Orders',
    'has_flag',
    '["High Value"]',
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    NULL,
    '2');

--
-- Warning - Order has 'Total Order Value Limit' flag
--
INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    rule_action_helper_method,
    processing_cost ) VALUES
    ('Warning - Order Has ''Total Order Value Limit'' Flag',
    'Public::Orders',
    'has_flag',
    '["Total Order Value Limit"]',
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    NULL,
    '2');

--
-- Warning - Order has 'Weekly Order Value Limit' flag
--
INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    rule_action_helper_method,
    processing_cost ) VALUES
    ('Warning - Order Has ''Weekly Order Value Limit'' Flag',
    'Public::Orders',
    'has_flag',
    '["Weekly Order Value Limit"]',
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    NULL,
    '2');

--
-- Warning - Order has 'Weekly Order Count Limit' flag
--
INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    rule_action_helper_method,
    processing_cost ) VALUES
    ('Warning - Order Has ''Weekly Order Count Limit'' Flag',
    'Public::Orders',
    'has_flag',
    '["Weekly Order Count Limit"]',
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    NULL,
    '2');

--
-- Warning - Order has 'Daily Order Count Limit' flag
--
INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    rule_action_helper_method,
    processing_cost ) VALUES
    ('Warning - Order Has ''Daily Order Count Limit'' Flag',
    'Public::Orders',
    'has_flag',
    '["Daily Order Count Limit"]',
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    NULL,
    '2');

--
-- Warning - Order has 'Delivery Signature Opt Out' flag
--
INSERT INTO fraud.method (
    description,
    object_to_use,
    method_to_call,
    method_parameters,
    return_value_type_id,
    rule_action_helper_method,
    processing_cost ) VALUES
    ('Warning - Order Has ''Delivery Signature Opt Out'' Flag',
    'Public::Orders',
    'has_flag',
    '["Delivery Signature Opt Out"]',
    ( SELECT id FROM fraud.return_value_type WHERE type = 'boolean' ),
    NULL,
    '2');


COMMIT WORK;
