BEGIN;

CREATE TABLE dhl_delivery_file (
    id                        serial primary key,
    filename                  text not null,
    remote_modification_epoch integer not null,
    processed                 boolean not null default false,
    failures                  integer not null default 0,
    successful                boolean,
    created_date              timestamp with time zone not null default now(),
    last_updated              timestamp with time zone not null default now(),
    processed_at              timestamp with time zone
);

GRANT ALL ON TABLE dhl_delivery_file TO www;
GRANT ALL ON SEQUENCE dhl_delivery_file_id_seq TO www;

CREATE UNIQUE INDEX idx_dhl_delivery_file_filename ON dhl_delivery_file(filename);

CREATE TRIGGER dhl_delivery_file_last_updated_tr BEFORE UPDATE ON dhl_delivery_file FOR EACH ROW EXECUTE PROCEDURE last_updated_func();

COMMENT ON TABLE dhl_delivery_file IS 'Records which files from DHL regarding delivery times have been processed';

COMMIT;
