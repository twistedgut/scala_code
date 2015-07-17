-- CANDO-85: Create table 'bulk_reimbursement_status'.
-- CANDO-85: Create table 'bulk_reimbursement'.
-- CANDO-85: Create table 'link_bulk_reimbursement__orders'.

BEGIN WORK;

-- CANDO-85: Create table 'bulk_reimbursement_status'.

    -- Create Table
    CREATE TABLE bulk_reimbursement_status (
        id SERIAL NOT NULL,
        status character varying(255) NOT NULL,
        --
        CONSTRAINT bulk_reimbursement_status_pkey
            PRIMARY KEY (id),
        CONSTRAINT bulk_reimbursement_status_status_unique
            UNIQUE (status)
    );

    -- Apply Permissions
    ALTER TABLE bulk_reimbursement_status OWNER TO postgres;
    GRANT ALL ON TABLE bulk_reimbursement_status TO postgres;
    GRANT ALL ON TABLE bulk_reimbursement_status TO www;
    GRANT SELECT ON TABLE bulk_reimbursement_status TO perlydev;
    GRANT USAGE ON SEQUENCE bulk_reimbursement_status_id_seq TO postgres;
    GRANT USAGE ON SEQUENCE bulk_reimbursement_status_id_seq TO www;
    GRANT USAGE ON SEQUENCE bulk_reimbursement_status_id_seq TO perlydev;

    -- Populate Table.
    INSERT INTO bulk_reimbursement_status (id, status) VALUES
        (1, 'Pending'),
        (2, 'Done'),
        (3, 'Error');
-- TODO: Should we let the sequence take care of the id, as hard coding them will put it out of sync?
-- TODO: Add completed flag to link_bulk_reimbursement__orders? (or duplicate status)

-- CANDO-85: Create table 'bulk_reimbursement'.

    -- Create Table
    CREATE TABLE bulk_reimbursement (
        id SERIAL NOT NULL,
        created_timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        operator_id INTEGER NOT NULL,
        channel_id INTEGER NOT NULL,
        bulk_reimbursement_status_id INTEGER NOT NULL,
        credit_amount NUMERIC(10, 3) NOT NULL,
        reason CHARACTER VARYING(250) NOT NULL,
        send_email BOOLEAN NOT NULL,
        email_subject CHARACTER VARYING(255), -- from email_template.subject
        email_message TEXT,
        --
        CONSTRAINT bulk_reimbursement_pkey
            PRIMARY KEY (id),
        CONSTRAINT bulk_reimbursement_operator_id_fkey
            FOREIGN KEY (operator_id) REFERENCES operator (id) MATCH SIMPLE,
        CONSTRAINT bulk_reimbursement_channel_id_fkey
            FOREIGN KEY (channel_id) REFERENCES channel (id) MATCH SIMPLE,
        CONSTRAINT bulk_reimbursement_bulk_reimbursement_status_id_fkey
            FOREIGN KEY (bulk_reimbursement_status_id) REFERENCES bulk_reimbursement_status (id) MATCH SIMPLE
    );

    -- Apply Permissions
    ALTER TABLE bulk_reimbursement OWNER TO postgres;
    GRANT ALL ON TABLE bulk_reimbursement TO postgres;
    GRANT ALL ON TABLE bulk_reimbursement TO www;
    GRANT SELECT ON TABLE bulk_reimbursement TO perlydev;
    GRANT USAGE ON SEQUENCE bulk_reimbursement_id_seq TO postgres;
    GRANT USAGE ON SEQUENCE bulk_reimbursement_id_seq TO www;
    GRANT USAGE ON SEQUENCE bulk_reimbursement_id_seq TO perlydev;

-- CANDO-85: Create table 'link_bulk_reimbursement__orders'.

    -- Create Table
    CREATE TABLE link_bulk_reimbursement__orders (
        bulk_reimbursement_id INTEGER NOT NULL,
        order_id INTEGER NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        --
        CONSTRAINT link_bulk_reimbursement__orders_pkey
            PRIMARY KEY (bulk_reimbursement_id, order_id),
        CONSTRAINT link_bulk_reimbursement__orders_bulk_reimbursement_id_fkey
            FOREIGN KEY (bulk_reimbursement_id) REFERENCES bulk_reimbursement (id) MATCH SIMPLE,
        CONSTRAINT link_bulk_reimbursement__orders_order_id_fkey
            FOREIGN KEY (order_id) REFERENCES orders (id) MATCH SIMPLE
    );

    -- Apply Permissions
    ALTER TABLE link_bulk_reimbursement__orders OWNER TO postgres;
    GRANT ALL ON TABLE link_bulk_reimbursement__orders TO postgres;
    GRANT ALL ON TABLE link_bulk_reimbursement__orders TO www;
    GRANT SELECT ON TABLE link_bulk_reimbursement__orders TO perlydev;

    -- Create Indexes
    CREATE INDEX idx_link_bulk_reimbursement__orders_bulk_reimbursement_id
        ON link_bulk_reimbursement__orders (bulk_reimbursement_id);

    CREATE INDEX idx_link_bulk_reimbursement__orders_order_id
        ON link_bulk_reimbursement__orders (order_id);

--ROLLBACK;
COMMIT;

