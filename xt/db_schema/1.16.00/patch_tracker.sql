BEGIN WORK;

    -- stick it in it's own namespace, to keep out of people's way
    CREATE SCHEMA dbadmin;
    ALTER SCHEMA dbadmin OWNER TO www;

    CREATE TABLE dbadmin.applied_patch (
        id              SERIAL              primary key,
        created         timestamp with time zone
                        not null default CURRENT_TIMESTAMP,
        filename        text                not null,
        basename        text                not null,
        succeeded       boolean             default(false),
        output          text
    );
    ALTER TABLE dbadmin.applied_patch OWNER TO www;

    CREATE INDEX idx_dbadmin_applied_patch_basename
        ON dbadmin.applied_patch(basename);

    -- so we skip ourself
    INSERT INTO dbadmin.applied_patch
    (id, filename, basename, succeeded, output)
    VALUES
    (0, '<DUMMY>/patch_tracker.sql', 'patch_tracker.sql', true,
        'Making sure we do not re-run the patch schema creation');

COMMIT;
