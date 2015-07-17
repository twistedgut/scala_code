BEGIN;

    ALTER TABLE promotion.detail
        ADD COLUMN restrict_by_weeks
            boolean NOT NULL default false
    ;

    ALTER TABLE promotion.detail
        ADD COLUMN restrict_x_weeks
            integer NOT NULL default 6
    ;

COMMIT;
