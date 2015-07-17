-- this extends the list concept (10017_list_patch.sql) and adds
-- the idea of photography work lists (for products)

BEGIN;

-- new namespace/schema
CREATE SCHEMA photography;
GRANT ALL ON SCHEMA photography TO www;


-- extra information that's specific to lists of products
CREATE TABLE photography.list_info (
    id              serial          primary key
);
-- make sure www can use the table
GRANT ALL ON photography.list_info TO www;
GRANT ALL ON photography.list_info_id_seq TO www;
-- join the list_info to the list.list
CREATE TABLE photography.list_listinfo (
    id              serial          primary key,

    list_id         integer         not null
                    references list.list(id),
    listinfo_id     integer         not null
                    references photography.list_info(id),

    UNIQUE (list_id, listinfo_id)
);
-- make sure www can use the table
GRANT ALL ON photography.list_listinfo TO www;
GRANT ALL ON photography.list_listinfo_id_seq TO www;


-- images get taken in different locations
CREATE TABLE photography.location (
    id              serial          primary key,
    name            varchar(50)     not null,

    UNIQUE (name)
);
GRANT ALL ON photography.location TO www;
GRANT ALL ON photography.location_id_seq TO www;
-- some locations to get the ball rolling
INSERT INTO photography.location (name) VALUES ('Index');
INSERT INTO photography.location (name) VALUES ('Mannequin');
INSERT INTO photography.location (name) VALUES ('Retouch Rail');
INSERT INTO photography.location (name) VALUES ('Sample Room');
INSERT INTO photography.location (name) VALUES ('Upload');




-- the opportunity to give images a meaningful label (since the spec
-- insists on calling them Shot 1 ... Shot 7)
CREATE TABLE photography.image_label (
    id                      serial  primary key,
    idx                     integer,
    description             text        NOT NULL,
    short_description       varchar(20) NOT NULL
);
GRANT ALL ON photography.image_label to www;
GRANT ALL ON photography.image_label_id_seq to www;
CREATE TRIGGER default_label_index_tgr AFTER INSERT OR UPDATE
    ON photography.image_label
        FOR EACH ROW EXECUTE PROCEDURE public.default_index_trigger();

-- a default image for us to use when none is set
INSERT INTO photography.image_label
    (id, description, short_description)
    VALUES
    (0, 'Unclassified', 'XX')
;

INSERT INTO photography.image_label
    (description, short_description)
    VALUES
    ('Index Shot', 'IN')
;
INSERT INTO photography.image_label
    (description, short_description)
    VALUES
    ('Front Shot', 'FR')
;
INSERT INTO photography.image_label
    (description, short_description)
    VALUES
    ('Back Shot', 'BK')
;
INSERT INTO photography.image_label
    (description, short_description)
    VALUES
    ('Mannequin', 'MQ')
;
INSERT INTO photography.image_label
    (description, short_description)
    VALUES
    ('Close-Up', 'CU')
;
INSERT INTO photography.image_label
    (description, short_description)
    VALUES
    ('Outfit Shot', 'OS')
;
INSERT INTO photography.image_label
    (description, short_description)
    VALUES
    ('Extra Shot', 'ES')
;

-- a table for image statuses [statii? ;)] in the studio
CREATE TABLE photography.image_status (
    id              serial  primary key,
    status          varchar(255) not null,
    description     text,
    display_colour  varchar(7), -- #xxyyzz HTML colour values
    icon            text        -- e.g. /images/icons/XXX.png
                    DEFAULT('/images/icons/picture_empty.png'),
    UNIQUE(status)
);
GRANT ALL ON photography.image_status to www;
GRANT ALL ON photography.image_status_id_seq to www;

-- INSERT image_status entries
INSERT INTO photography.image_status
    (status, display_colour, description, icon)
    VALUES
    (   'CHECK',
        NULL,
        'Shot has been taken',
        '/images/icons/picture_go.png'
    )
;
INSERT INTO photography.image_status
    (status, display_colour, description, icon)
    VALUES
    (   'IMAGE_MISSING',
        '#FCD116',
        'Image missing from server',
        '/images/icons/cross.png'
    )
;
INSERT INTO photography.image_status
    (status, display_colour, description, icon)
    VALUES
    (   'RESHOOT',
        '#FFFF99',
        'Needs re-shooting',
        '/images/icons/exclamation.png'
    )
;
INSERT INTO photography.image_status
    (status, display_colour, description, icon)
    VALUES
    (   'RECHECK',
        '#C0C0C0',
        'Shot needs re-checking',
        '/images/icons/picture_go.png'
    )
;
INSERT INTO photography.image_status
    (status, display_colour, description, icon)
    VALUES
    (   'IN_RETOUCHING',
        '#99FF66',
        'Shot is being re-touched',
        '/images/icons/color_wheel.png'
    )
;
INSERT INTO photography.image_status
    (status, display_colour, description, icon)
    VALUES
    (   'RETOUCH',
        '#3D9140',
        'Shot needs re-touching',
        '/images/icons/pencil.png'
    )
;
INSERT INTO photography.image_status
    (status, display_colour, description, icon)
    VALUES
    (   'RETOUCHED',
        '#F3A68F',
        'Shot has been re-touched',
        '/images/icons/picture_edit.png'
    )
;
INSERT INTO photography.image_status
    (status, display_colour, description, icon)
    VALUES
    (   'UPLOADED',
        '#6495ED',
        'Shot has been uploaded',
        '/images/icons/asterisk_yellow.png'
    )
;
INSERT INTO photography.image_status
    (status, display_colour, description, icon)
    VALUES
    (   'AMEND_RESHOOT',
        '#FFFF99',
        'Shot needs re-shooting',
        '/images/icons/exclamation.png'
    )
;
INSERT INTO photography.image_status
    (status, display_colour, description, icon)
    VALUES
    (   'AMEND_RETOUCH',
        '#99FF66',
        'Shot needs re-touching',
        '/images/icons/pencil.png'
    )
;
-- this status is only used as a mini-kludge for the image staus of
-- an ammend comment
INSERT INTO photography.image_status
    (status, display_colour, description, icon)
    VALUES
    (   'AMEND',
        NULL,
        'Amendment',
        '/images/icons/error.png'
    )
;
INSERT INTO photography.image_status
    (status, display_colour, description, icon)
    VALUES
    (   'APPROVED',
        '#FF00FF',
        'Image is Approved',
        '/images/icons/tick.png'
    )
;
INSERT INTO photography.image_status
    (status, display_colour, description, icon)
    VALUES
    (   'FINAL_APPROVAL',
        '#3B3178',
        'Signed Off for Upload',
        '/images/icons/accept.png'
    )
;
INSERT INTO photography.image_status
    (status, display_colour, description, icon)
    VALUES
    (   'RESET',
        '#FF0000',
        'Nuke All Images',
        '/images/icons/bomb.png'
    )
;
INSERT INTO photography.image_status
    (status, display_colour, description, icon)
    VALUES
    (   'RESET_IMAGE',
        '#FF0000',
        'Reset Image',
        '/images/icons/bomb.png'
    )
;
-- this status is a mini-kludge for the comment added when an image is
-- assigned
INSERT INTO photography.image_status
    (status, display_colour, description, icon)
    VALUES
    (   'IMAGE_ASSIGNED',
        NULL,
        'Image Assigned',
        '/images/icons/camera_add.png'
    )
;
INSERT INTO photography.image_status
    (status, display_colour, description, icon)
    VALUES
    (   'NR',
        NULL,
        'Image not required',
        '/images/icons/page_white.png'
    )
;

-- state transition table
CREATE TABLE photography.image_next_state (
    id                  serial          primary key,
    current_state_id    integer         references photography.image_status(id) NOT NULL,
    next_state_id       integer         references photography.image_status(id) NOT NULL,
    authorisation_level integer         references public.authorisation_level,

    UNIQUE(current_state_id, next_state_id,authorisation_level)
);
GRANT ALL ON photography.image_next_state to www;
GRANT ALL ON photography.image_next_state_id_seq to www;
-- state transitions (Operator)
INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
VALUES (
    (SELECT id FROM photography.image_status   WHERE status='NR'),
    (SELECT id FROM photography.image_status   WHERE status='RESET_IMAGE'),
    (SELECT id FROM public.authorisation_level WHERE description='Operator')
);
INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
VALUES (
    (SELECT id FROM photography.image_status   WHERE status='CHECK'),
    (SELECT id FROM photography.image_status   WHERE status='RESET_IMAGE'),
    (SELECT id FROM public.authorisation_level WHERE description='Operator')
);
INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
VALUES (
    (SELECT id FROM photography.image_status   WHERE status='CHECK'),
    (SELECT id FROM photography.image_status   WHERE status='RESHOOT'),
    (SELECT id FROM public.authorisation_level WHERE description='Operator')
);
INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
VALUES (
    (SELECT id FROM photography.image_status WHERE status='CHECK'),
    (SELECT id FROM photography.image_status WHERE status='RETOUCH'),
    (SELECT id FROM public.authorisation_level WHERE description='Operator')
);
INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
VALUES (
    (SELECT id FROM photography.image_status WHERE status='IMAGE_MISSING'),
    (SELECT id FROM photography.image_status WHERE status='RETOUCH'),
    (SELECT id FROM public.authorisation_level WHERE description='Operator')
);
INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
VALUES (
    (SELECT id FROM photography.image_status WHERE status='CHECK'),
    (SELECT id FROM photography.image_status WHERE status='IN_RETOUCHING'),
    (SELECT id FROM public.authorisation_level WHERE description='Operator')
);
INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
VALUES (
    (SELECT id FROM photography.image_status WHERE status='CHECK'),
    (SELECT id FROM photography.image_status WHERE status='IMAGE_MISSING'),
    (SELECT id FROM public.authorisation_level WHERE description='Operator')
);
INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
VALUES (
    (SELECT id FROM photography.image_status WHERE status='CHECK'),
    (SELECT id FROM photography.image_status WHERE status='UPLOADED'),
    (SELECT id FROM public.authorisation_level WHERE description='Operator')
);
INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
VALUES (
    (SELECT id FROM photography.image_status WHERE status='IN_RETOUCHING'),
    (SELECT id FROM photography.image_status WHERE status='UPLOADED'),
    (SELECT id FROM public.authorisation_level WHERE description='Operator')
);
INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
VALUES (
    (SELECT id FROM photography.image_status WHERE status='IN_RETOUCHING'),
    (SELECT id FROM photography.image_status WHERE status='IMAGE_MISSING'),
    (SELECT id FROM public.authorisation_level WHERE description='Operator')
);
INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
VALUES (
    (SELECT id FROM photography.image_status WHERE status='RESHOOT'),
    (SELECT id FROM photography.image_status WHERE status='RECHECK'),
    (SELECT id FROM public.authorisation_level WHERE description='Operator')
);
INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
VALUES (
    (SELECT id FROM photography.image_status WHERE status='RECHECK'),
    (SELECT id FROM photography.image_status WHERE status='RESHOOT'),
    (SELECT id FROM public.authorisation_level WHERE description='Operator')
);
INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
VALUES (
    (SELECT id FROM photography.image_status WHERE status='RECHECK'),
    (SELECT id FROM photography.image_status WHERE status='RETOUCH'),
    (SELECT id FROM public.authorisation_level WHERE description='Operator')
);
-- INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
-- VALUES (
--     (SELECT id FROM photography.image_status WHERE status='RETOUCH'),
--     (SELECT id FROM photography.image_status WHERE status='RETOUCHED'),
--     (SELECT id FROM public.authorisation_level WHERE description='Operator')
-- );
INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
VALUES (
    (SELECT id FROM photography.image_status WHERE status='RETOUCH'),
    (SELECT id FROM photography.image_status WHERE status='UPLOADED'),
    (SELECT id FROM public.authorisation_level WHERE description='Operator')
);
-- INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
-- VALUES (
--     (SELECT id FROM photography.image_status WHERE status='RETOUCHED'),
--     (SELECT id FROM photography.image_status WHERE status='UPLOADED'),
--     (SELECT id FROM public.authorisation_level WHERE description='Operator')
-- );
INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
VALUES (
    (SELECT id FROM photography.image_status WHERE status='AMEND_RESHOOT'),
    (SELECT id FROM photography.image_status WHERE status='RECHECK'),
    (SELECT id FROM public.authorisation_level WHERE description='Operator')
);
INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
VALUES (
    (SELECT id FROM photography.image_status WHERE status='AMEND_RETOUCH'),
    (SELECT id FROM photography.image_status WHERE status='RETOUCHED'),
    (SELECT id FROM public.authorisation_level WHERE description='Operator')
);
INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
VALUES (
    (SELECT id FROM photography.image_status WHERE status='AMEND_RETOUCH'),
    (SELECT id FROM photography.image_status WHERE status='UPLOADED'),
    (SELECT id FROM public.authorisation_level WHERE description='Operator')
);




-- state transitions (Manager) [copy of Operator transitions]
INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
VALUES (
    (SELECT id FROM photography.image_status   WHERE status='NR'),
    (SELECT id FROM photography.image_status   WHERE status='RESET_IMAGE'),
    (SELECT id FROM public.authorisation_level WHERE description='Manager')
);
INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
VALUES (
    (SELECT id FROM photography.image_status   WHERE status='CHECK'),
    (SELECT id FROM photography.image_status   WHERE status='RESET_IMAGE'),
    (SELECT id FROM public.authorisation_level WHERE description='Manager')
);
INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
VALUES (
    (SELECT id FROM photography.image_status   WHERE status='CHECK'),
    (SELECT id FROM photography.image_status   WHERE status='RESHOOT'),
    (SELECT id FROM public.authorisation_level WHERE description='Manager')
);
INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
VALUES (
    (SELECT id FROM photography.image_status WHERE status='CHECK'),
    (SELECT id FROM photography.image_status WHERE status='RETOUCH'),
    (SELECT id FROM public.authorisation_level WHERE description='Manager')
);
INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
VALUES (
    (SELECT id FROM photography.image_status WHERE status='IMAGE_MISSING'),
    (SELECT id FROM photography.image_status WHERE status='RETOUCH'),
    (SELECT id FROM public.authorisation_level WHERE description='Manager')
);
INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
VALUES (
    (SELECT id FROM photography.image_status WHERE status='CHECK'),
    (SELECT id FROM photography.image_status WHERE status='IN_RETOUCHING'),
    (SELECT id FROM public.authorisation_level WHERE description='Manager')
);
INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
VALUES (
    (SELECT id FROM photography.image_status WHERE status='CHECK'),
    (SELECT id FROM photography.image_status WHERE status='IMAGE_MISSING'),
    (SELECT id FROM public.authorisation_level WHERE description='Manager')
);
INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
VALUES (
    (SELECT id FROM photography.image_status WHERE status='CHECK'),
    (SELECT id FROM photography.image_status WHERE status='UPLOADED'),
    (SELECT id FROM public.authorisation_level WHERE description='Manager')
);
INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
VALUES (
    (SELECT id FROM photography.image_status WHERE status='IN_RETOUCHING'),
    (SELECT id FROM photography.image_status WHERE status='UPLOADED'),
    (SELECT id FROM public.authorisation_level WHERE description='Manager')
);
INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
VALUES (
    (SELECT id FROM photography.image_status WHERE status='IN_RETOUCHING'),
    (SELECT id FROM photography.image_status WHERE status='IMAGE_MISSING'),
    (SELECT id FROM public.authorisation_level WHERE description='Manager')
);
INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
VALUES (
    (SELECT id FROM photography.image_status WHERE status='RESHOOT'),
    (SELECT id FROM photography.image_status WHERE status='RECHECK'),
    (SELECT id FROM public.authorisation_level WHERE description='Manager')
);
INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
VALUES (
    (SELECT id FROM photography.image_status WHERE status='RECHECK'),
    (SELECT id FROM photography.image_status WHERE status='RESHOOT'),
    (SELECT id FROM public.authorisation_level WHERE description='Manager')
);
INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
VALUES (
    (SELECT id FROM photography.image_status WHERE status='RECHECK'),
    (SELECT id FROM photography.image_status WHERE status='RETOUCH'),
    (SELECT id FROM public.authorisation_level WHERE description='Manager')
);
-- INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
-- VALUES (
--     (SELECT id FROM photography.image_status WHERE status='RETOUCH'),
--     (SELECT id FROM photography.image_status WHERE status='RETOUCHED'),
--     (SELECT id FROM public.authorisation_level WHERE description='Manager')
-- );
INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
VALUES (
    (SELECT id FROM photography.image_status WHERE status='RETOUCH'),
    (SELECT id FROM photography.image_status WHERE status='UPLOADED'),
    (SELECT id FROM public.authorisation_level WHERE description='Manager')
);
-- INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
-- VALUES (
--     (SELECT id FROM photography.image_status WHERE status='RETOUCHED'),
--     (SELECT id FROM photography.image_status WHERE status='UPLOADED'),
--     (SELECT id FROM public.authorisation_level WHERE description='Manager')
-- );
INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
VALUES (
    (SELECT id FROM photography.image_status WHERE status='AMEND_RESHOOT'),
    (SELECT id FROM photography.image_status WHERE status='RECHECK'),
    (SELECT id FROM public.authorisation_level WHERE description='Manager')
);
INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
VALUES (
    (SELECT id FROM photography.image_status WHERE status='AMEND_RETOUCH'),
    (SELECT id FROM photography.image_status WHERE status='RETOUCHED'),
    (SELECT id FROM public.authorisation_level WHERE description='Manager')
);
INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
VALUES (
    (SELECT id FROM photography.image_status WHERE status='AMEND_RETOUCH'),
    (SELECT id FROM photography.image_status WHERE status='UPLOADED'),
    (SELECT id FROM public.authorisation_level WHERE description='Manager')
);
-- state transitions (Manager) [extra transitions]
INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
VALUES (
    (SELECT id FROM photography.image_status WHERE status='UPLOADED'),
    (SELECT id FROM photography.image_status WHERE status='AMEND_RESHOOT'),
    (SELECT id FROM public.authorisation_level WHERE description='Manager')
);
INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
VALUES (
    (SELECT id FROM photography.image_status WHERE status='UPLOADED'),
    (SELECT id FROM photography.image_status WHERE status='AMEND_RETOUCH'),
    (SELECT id FROM public.authorisation_level WHERE description='Manager')
);
INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
VALUES (
    (SELECT id FROM photography.image_status WHERE status='UPLOADED'),
    (SELECT id FROM photography.image_status WHERE status='APPROVED'),
    (SELECT id FROM public.authorisation_level WHERE description='Manager')
);
INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
VALUES (
    (SELECT id FROM photography.image_status WHERE status='APPROVED'),
    (SELECT id FROM photography.image_status WHERE status='RESET'),
    (SELECT id FROM public.authorisation_level WHERE description='Manager')
);
INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
VALUES (
    (SELECT id FROM photography.image_status WHERE status='APPROVED'),
    (SELECT id FROM photography.image_status WHERE status='UPLOADED'),
    (SELECT id FROM public.authorisation_level WHERE description='Manager')
);
INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
VALUES (
    (SELECT id FROM photography.image_status WHERE status='RETOUCHED'),
    (SELECT id FROM photography.image_status WHERE status='AMEND_RESHOOT'),
    (SELECT id FROM public.authorisation_level WHERE description='Manager')
);
INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
VALUES (
    (SELECT id FROM photography.image_status WHERE status='RETOUCHED'),
    (SELECT id FROM photography.image_status WHERE status='AMEND_RETOUCH'),
    (SELECT id FROM public.authorisation_level WHERE description='Manager')
);
INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
VALUES (
    (SELECT id FROM photography.image_status WHERE status='RETOUCHED'),
    (SELECT id FROM photography.image_status WHERE status='APPROVED'),
    (SELECT id FROM public.authorisation_level WHERE description='Manager')
);
INSERT INTO photography.image_next_state (current_state_id, next_state_id,authorisation_level)
VALUES (
    (SELECT id FROM photography.image_status WHERE status='APPROVED'),
    (SELECT id FROM photography.image_status WHERE status='FINAL_APPROVAL'),
    (SELECT id FROM public.authorisation_level WHERE description='Manager')
);


-- images belong to a product (not a list)
CREATE TABLE photography.image (
    id              serial          primary key,
    product_id      integer         not null
                    references public.product(id),

    -- images for a product have an ordering
    idx             integer         not null,

    image_status_id integer         not null
                    references photography.image_status(id),
    image_label_id  integer         not null
                    references photography.image_label(id),

    -- for visual reporting/auditing purposes
    last_shooter        integer         REFERENCES public.operator(id),
    last_retoucher      integer         REFERENCES public.operator(id),

    -- for auditing purposes
    created             timestamp with time zone
                        not null
                        default current_timestamp,
    last_modified       timestamp with time zone
                        not null
                        default current_timestamp,

    created_by          integer         not null
                        REFERENCES public.operator(id),
    last_modified_by    integer         not null
                        REFERENCES public.operator(id)

);
-- make sure www can use the table
GRANT ALL ON photography.image TO www;
GRANT ALL ON photography.image_id_seq TO www;
-- add the idx (default) value trigger
CREATE TRIGGER default_index_tgr AFTER INSERT OR UPDATE
    ON photography.image
        FOR EACH ROW EXECUTE PROCEDURE public.default_index_trigger();
CREATE TRIGGER photography_image_last_modified BEFORE UPDATE
    ON photography.image
        FOR EACH ROW EXECUTE PROCEDURE public.update_last_modified_time();


-- People would like to make notes on images ..
CREATE TABLE photography.note_type (
    id              serial          primary key,
    name            varchar(20)     not null
);
GRANT ALL ON photography.note_type to www;
GRANT ALL ON photography.note_type_id_seq to www;
-- Insert the known types of note available
INSERT INTO photography.note_type (id,name) VALUES (0,'Application');
INSERT INTO photography.note_type (name) VALUES ('Photographer');
INSERT INTO photography.note_type (name) VALUES ('Stylist');
INSERT INTO photography.note_type (name) VALUES ('Re-Touch');
INSERT INTO photography.note_type (name) VALUES ('Resize');
INSERT INTO photography.note_type (name) VALUES ('Amends');
INSERT INTO photography.note_type (name) VALUES ('Final Amends');


CREATE TABLE photography.image_note (
    id                      serial          primary key,
    image_id                integer         not null
                            references photography.image(id),
    content                 text            not null,
    note_type_id            integer         not null
                            references photography.note_type(id),
    current_image_status    integer     not null
                            references photography.image_status(id),

    application_note        boolean         not null    default False,

    created_by              integer         not null
                            references public.operator(id),
    created                 timestamp with time zone
                            not null
                            default CURRENT_TIMESTAMP
);
GRANT ALL ON photography.image_note to www;
GRANT ALL ON photography.image_note_id_seq to www;

CREATE TABLE photography.image_amend (
    id                      serial          primary key,
    count                   integer         not null    default 0,

    product_listitem_id     integer         not null
                            references product.list_item(id),

    UNIQUE (product_listitem_id)
);
GRANT ALL ON photography.image_amend to www;
GRANT ALL ON photography.image_amend_id_seq to www;

CREATE TABLE photography.sample_state (
    id                      serial          primary key,
    name                    varchar(255)    not null,
    icon                    text            not null,

    UNIQUE(name)
);
GRANT ALL ON photography.sample_state to www;
GRANT ALL ON photography.sample_state_id_seq to www;

INSERT INTO photography.sample_state (id, name, icon) VALUES (0,        'Missing',   '/images/icons/exclamation.png');
INSERT INTO photography.sample_state (id, name, icon) VALUES (default,  'Received',  '/images/icons/accept.png');
INSERT INTO photography.sample_state (id, name, icon) VALUES (default,  'Incorrect', '/images/icons/error.png');

CREATE TABLE photography.sample_information (
    id                      serial          primary key,

    sample_state_id         integer         not null
                            references photography.sample_state(id)
                            default 0,
    product_id              integer         not null
                            references public.product(id),

    UNIQUE(product_id)
);
GRANT ALL ON photography.sample_information to www;
GRANT ALL ON photography.sample_information_id_seq to www;


CREATE TABLE photography.image_collection (
    id                      serial          primary key,
    name                    varchar(255)    not null,

    UNIQUE(name)
);
GRANT ALL ON photography.image_collection to www;
GRANT ALL ON photography.image_collection_id_seq to www;

CREATE TABLE photography.image_collection_item (
    id                      serial          primary key,

    image_collection_id     integer         not null
                            references photography.image_collection(id),
    image_index             integer         not null,

    image_label_id          integer         not null
                            references photography.image_label(id),
    set_not_required        boolean         not null    default false,

    UNIQUE (image_collection_id, image_index)
);
GRANT ALL ON photography.image_collection_item to www;
GRANT ALL ON photography.image_collection_item_id_seq to www;

COMMIT;
