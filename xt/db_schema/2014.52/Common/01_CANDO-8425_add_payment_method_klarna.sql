-- CANDO-8425: Add Payment Method 'Klarna' to the System
--             Also add new fields to 'orders.payment_method'
--             table to cope with Klarna

BEGIN WORK;

--
-- add a couple of new columns
--
ALTER TABLE orders.payment_method
    ADD COLUMN billing_and_shipping_address_always_the_same BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN notify_psp_of_basket_change BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN allow_full_refund_using_only_store_credit BOOLEAN NOT NULL DEFAULT TRUE,
    ADD COLUMN allow_full_refund_using_only_payment BOOLEAN NOT NULL DEFAULT TRUE,
    ADD COLUMN produce_customer_invoice_at_fulfilment BOOLEAN NOT NULL DEFAULT TRUE
;

-- add comments to the new fields
COMMENT ON COLUMN orders.payment_method.billing_and_shipping_address_always_the_same IS 'Set to TRUE when a Payment Method requires that the Billing Address and Shipping Address must be kept the same.';
COMMENT ON COLUMN orders.payment_method.notify_psp_of_basket_change IS 'Indicates that the PSP needs to be notified when any Basket Changes such as Cancelling an Item, are made.';
COMMENT ON COLUMN orders.payment_method.allow_full_refund_using_only_store_credit IS 'Set this to FALSE when a Payment Method (if used to pay for an Order) does not allow NAP Group to Refund ALL of an Order to the Customer using only Store Credit. If the Order is paid in part using Store Credit (and/or Gift Vouchers) then that part of the Amount CAN still be Refunded as Store Credit, but all of the Amount can not be arbitrarily refunded using only Store Credit. For most Payment Methods this field will be TRUE and allow All Store Credit Refunds at the discretion of NAP Group.';
COMMENT ON COLUMN orders.payment_method.allow_full_refund_using_only_payment IS 'Set this to FALSE when a Payment Method (if used to pay for an Order) does not allow NAP Group to Refund ALL of an Order to the Customer using the Payment Method. If the Order is paid in part using Store Credit (and/or Gift Vouchers) then that part of the Amount CAN still be Refunded as to the Payment, but all of the Amount can not be arbitrarily refunded using only the Payment. For most Payment Methods this field will be TRUE and allow All Payment Refunds at the discretion of NAP Group.';
COMMENT ON COLUMN orders.payment_method.produce_customer_invoice_at_fulfilment IS 'Set this to FALSE when a third party will be sending the Invoice to the Customer and NOT NAP Group. For most Payment Methods this will be TRUE.';

--
-- add 'Klarna' to orders.payment_method
--
INSERT INTO orders.payment_method (
    payment_method,
    payment_method_class_id,
    string_from_psp,
    notify_psp_of_address_change,
    billing_and_shipping_address_always_the_same,
    notify_psp_of_basket_change,
    allow_full_refund_using_only_store_credit,
    allow_full_refund_using_only_payment,
    produce_customer_invoice_at_fulfilment
) VALUES (
    'Klarna',
    ( SELECT id FROM orders.payment_method_class WHERE payment_method_class = 'Third Party PSP' ),
    'INVOICE',
    TRUE,       -- Notify PSP of Address Change
    TRUE,       -- Billing & Shipping Address have to be the same
    TRUE,       -- Send Basket Changes to PSP
    FALSE,      -- Don't Allow Store Credit Only Refunds
    FALSE,      -- Don't Allow Payment Only Refunds
    FALSE       -- Don't Produce a Customer Invoice at Fulfilment
)
;

--
-- add the 3rd Party Payment Map for Klarna
--
INSERT INTO orders.third_party_payment_method_status_map ( third_party_status, payment_method_id, internal_status_id ) VALUES
(
    'PENDING',
    ( SELECT id FROM orders.payment_method WHERE payment_method = 'Klarna' ),
    ( SELECT id FROM orders.internal_third_party_status WHERE status = 'Pending' )
),
(
    'ACCEPTED',
    ( SELECT id FROM orders.payment_method WHERE payment_method = 'Klarna' ),
    ( SELECT id FROM orders.internal_third_party_status WHERE status = 'Accepted' )
),
(
    'REJECTED',
    ( SELECT id FROM orders.payment_method WHERE payment_method = 'Klarna' ),
    ( SELECT id FROM orders.internal_third_party_status WHERE status = 'Rejected' )
)
;

COMMIT WORK;
