BEGIN;
    CREATE SCHEMA operator;
    ALTER SCHEMA operator OWNER TO www;

    CREATE TABLE operator.message (
        id              SERIAL                      primary key,
        subject         text                        not null        DEFAULT '[No Subject]',
        body            text                        not null,
        created         timestamp with time zone    not null        DEFAULT CURRENT_TIMESTAMP,
        recipient_id    integer                     not null,
        sender_id       integer                     not null,

        viewed          boolean                     not null        DEFAULT false,
        deleted         boolean                     not null        DEFAULT false
    );
    ALTER TABLE operator.message OWNER TO www;
COMMIT;
