-- CANDO-31: Add Indexes to various tables to speed up queries used in the Customer Value calculations

BEGIN WORK;

--
-- speed up X::D::Customer::get_customer_value() that goes in on a
-- subset of renumerations by date range;
--
-- (where 'date' is actually a timestamp, just to confuse you)
--
CREATE INDEX idx_renumeration_status_log_date
    ON renumeration_status_log(date);

-- 'shipment_status_log' table
CREATE INDEX shipment_status_log_shipment_id_idx
    ON shipment_status_log(shipment_id);

-- 'return_item' table
CREATE INDEX return_item_shipment_item_id_idx
    ON return_item(shipment_item_id);

-- 'customer' table
CREATE INDEX customer_email_idx_lower_case
    ON customer(lower(email::text));

COMMIT WORK;
