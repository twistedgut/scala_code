BEGIN;

    alter table channel add column timezone varchar default 'America/Chicago';
    update channel set timezone='America/Chicago'; 

COMMIT;
