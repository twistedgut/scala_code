-- CANDO-2910: Add Payment Method to 'orders.payment' table
--             also Create 2 new tables:
--                  'orders.payment_method_class'
--                  'orders.payment_method'

BEGIN WORK;

--
-- Create 'orders.payment_method_class'
--
CREATE TABLE orders.payment_method_class (
    id                      SERIAL PRIMARY KEY,
    payment_method_class    CHARACTER VARYING(255) NOT NULL UNIQUE
);

ALTER TABLE orders.payment_method_class OWNER TO postgres;
GRANT ALL ON TABLE orders.payment_method_class TO www;
GRANT ALL ON SEQUENCE orders.payment_method_class_id_seq TO www;

-- Populate 'orders.payment_method_class' table
INSERT INTO orders.payment_method_class (payment_method_class) VALUES
('Card'),
('Third Party PSP')
;


--
-- Create 'orders.payment_method'
--
CREATE TABLE orders.payment_method (
    id                      SERIAL PRIMARY KEY,
    payment_method          CHARACTER VARYING (255) NOT NULL UNIQUE,
    payment_method_class_id INTEGER NOT NULL REFERENCES orders.payment_method_class(id),
    string_from_psp         CHARACTER VARYING (255) NOT NULL UNIQUE
);

ALTER TABLE orders.payment_method OWNER TO postgres;
GRANT ALL ON TABLE orders.payment_method TO www;
GRANT ALL ON SEQUENCE orders.payment_method_id_seq TO www;

--
-- Populate 'orders.payment_method' table
--
-- Deliberately specifiy the 'id' so that it can be used in a
-- DEFAULT when adding a new column to 'orders.payment'
--
INSERT INTO orders.payment_method VALUES
( 1, 'Credit Card', ( SELECT id FROM orders.payment_method_class WHERE payment_method_class = 'Card' ), 'CREDITCARD' ),
( 2, 'PayPal', ( SELECT id FROM orders.payment_method_class WHERE payment_method_class = 'Third Party PSP' ), 'PAYPAL' )
;

-- Now Reset the Next Id so it's correct for future Inserts
SELECT  SETVAL(
    'orders.payment_method_id_seq',
    ( SELECT MAX(id) FROM orders.payment_method )
)
;


--
-- Create a table of Internal Third Party Statuses
-- that will be used by the System and mapped to the
-- actual Statuses sent from a Third Party.
--
CREATE TABLE orders.internal_third_party_status (
    id      SERIAL PRIMARY KEY,
    status  CHARACTER VARYING (255) NOT NULL UNIQUE
);

ALTER TABLE orders.internal_third_party_status OWNER TO postgres;
GRANT ALL ON TABLE orders.internal_third_party_status TO www;
GRANT ALL ON SEQUENCE orders.internal_third_party_status_id_seq TO www;

--
-- Create a table of Third Party Statuses that Map
-- to the Internal Statuses used by the System
--
CREATE TABLE orders.third_party_payment_method_status_map (
    id                  SERIAL PRIMARY KEY,
    payment_method_id   INTEGER NOT NULL REFERENCES orders.payment_method(id),
    third_party_status  CHARACTER VARYING (255) NOT NULL,
    internal_status_id  INTEGER NOT NULL REFERENCES orders.internal_third_party_status(id),
    UNIQUE (payment_method_id,third_party_status,internal_status_id)
);

ALTER TABLE orders.third_party_payment_method_status_map OWNER TO postgres;
GRANT ALL ON TABLE orders.third_party_payment_method_status_map TO www;
GRANT ALL ON SEQUENCE orders.third_party_payment_method_status_map_id_seq TO www;

--
-- Populate the Third Party Status tables
--

-- orders.internal_third_party_status
INSERT INTO orders.internal_third_party_status (status) VALUES
('Pending'),
('Accepted'),
('Rejected')
;

-- orders.third_party_payment_method_status_map
INSERT INTO orders.third_party_payment_method_status_map (payment_method_id,third_party_status,internal_status_id) VALUES
(
    ( SELECT id FROM orders.payment_method WHERE payment_method = 'PayPal' ),
    'PENDING',
    ( SELECT id FROM orders.internal_third_party_status WHERE status = 'Pending' )
),
(
    ( SELECT id FROM orders.payment_method WHERE payment_method = 'PayPal' ),
    'ACCEPTED',
    ( SELECT id FROM orders.internal_third_party_status WHERE status = 'Accepted' )
),
(
    ( SELECT id FROM orders.payment_method WHERE payment_method = 'PayPal' ),
    'REJECTED',
    ( SELECT id FROM orders.internal_third_party_status WHERE status = 'Rejected' )
)
;


--
-- Change the 'orders.payment' table to have a Payment
-- Method Id, using the default of 'Credit Card'
--
ALTER TABLE orders.payment
    ADD COLUMN payment_method_id INTEGER NOT NULL DEFAULT 1,
    ADD CONSTRAINT payment_method_id_fkey FOREIGN KEY (payment_method_id) REFERENCES orders.payment_method(id)
;

ALTER TABLE orders.payment
    ALTER COLUMN payment_method_id DROP DEFAULT
;

CREATE INDEX idx_orders_payment_method_id ON orders.payment(payment_method_id);


COMMIT WORK;
