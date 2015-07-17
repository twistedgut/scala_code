-- this file creates requires tables and columns for the new
-- functionality required to alter the status of image comments

BEGIN;

    CREATE TABLE photography.image_note_status (
        id      SERIAL primary key,
        name    varchar(255) not null,

        icon        text,
        span_style  text,

        UNIQUE(name)
    );
    GRANT ALL ON photography.image_note_status TO www;
    GRANT ALL ON photography.image_note_status_id_seq TO www;

    INSERT INTO photography.image_note_status
    (name, span_style)
    VALUES
    ('Acted On', 'color: #aaa;');

    INSERT INTO photography.image_note_status
    (name, span_style)
    VALUES
    ('Use With', 'color: yellow; background-color: #333; font-weight: bold; display: block;');

    INSERT INTO photography.image_note_status
    (name, span_style)
    VALUES
    ('I''m A Moron', 'text-decoration: line-through; color: #444;');



    ALTER TABLE photography.image_note
    ADD COLUMN
        note_status_id  integer
                        references photography.image_note_status(id)
    ;

COMMIT;
