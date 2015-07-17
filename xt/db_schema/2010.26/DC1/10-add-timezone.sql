BEGIN;

    alter table channel add column timezone varchar default 'Europe/London';
    update channel set timezone='Europe/London'; 

COMMIT;
