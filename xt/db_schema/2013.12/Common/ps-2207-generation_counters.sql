BEGIN;

CREATE SEQUENCE generation_counter_seq CYCLE;
CREATE TABLE generation_counter (
    name TEXT NOT NULL PRIMARY KEY,
    counter BIGINT NOT NULL DEFAULT nextval('generation_counter_seq')
);
ALTER SEQUENCE generation_counter_seq OWNED BY generation_counter.counter;

GRANT ALL ON TABLE generation_counter TO www;
GRANT ALL ON SEQUENCE generation_counter_seq TO www;

COMMIT;
