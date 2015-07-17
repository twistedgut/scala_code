BEGIN;

    -- Create the return_delivery table
    CREATE TABLE return_delivery (
        id              serial                                  primary key,
        confirmed       boolean                     not null    default 'F',
        date_confirmed  timestamp with time zone,
        operator_id     integer                                 references operator(id)
    );

    GRANT ALL ON TABLE return_delivery TO www;
    GRANT ALL ON SEQUENCE return_delivery_id_seq TO www;


    -- Drop and create the return_arrival table
    DROP TABLE return_arrival;

    CREATE TABLE return_arrival (
        id                  serial                                  primary key,
        return_airway_bill  varchar(30)                 not null    unique,
        date                timestamp with time zone    not null    default now(),
        dhl_tape_on_box     boolean                     not null    default 'F',
        box_damaged         boolean                     not null    default 'F',
        damage_description  text,
        return_delivery_id  integer                     not null    references return_delivery(id),
        operator_id         integer                     not null    references operator(id)
    );

    GRANT ALL ON TABLE return_arrival TO www;
    GRANT ALL ON SEQUENCE return_arrival_id_seq TO www;

COMMIT;
