BEGIN;

    alter table business add column email_valediction char(50);

    update business set email_valediction='Kind regards,' where name <> 'MRPORTER.COM';
    update business set email_valediction='Yours sincerely,' where name = 'MRPORTER.COM';
        
COMMIT;
