-- this is intended to be used for storing information that can/will be used
-- in the UI level; e.g. icons, colours ...

BEGIN;
    CREATE SCHEMA display;
    GRANT ALL ON SCHEMA display TO www;

    CREATE TABLE display.list_itemstate (
        id                  serial      primary key,
        background_colour   varchar(7),
        icon                text,

        comment             text
    );
    GRANT ALL ON display.list_itemstate TO www;
    GRANT ALL ON display.list_itemstate_id_seq TO www;
    
    INSERT INTO display.list_itemstate (comment,background_colour, icon)
    VALUES (
        'Photography Awaiting Approval',
        '#6495ED',
        '/images/icons/eye.png'
    );
    INSERT INTO display.list_itemstate (comment,background_colour, icon)
    VALUES (
        'Photography Final Approval',
        '#3B3178',
        '/images/icons/accept.png'
    );
    INSERT INTO display.list_itemstate (comment,background_colour, icon)
    VALUES (
        'Photography Approved',
        '#FF00FF',
        '/images/icons/tick.png'
    );
    INSERT INTO display.list_itemstate (comment,background_colour, icon)
    VALUES (
        'Photography Rejected',
        '#FF0033',
        '/images/icons/exclamation.png'
    );

COMMIT;
