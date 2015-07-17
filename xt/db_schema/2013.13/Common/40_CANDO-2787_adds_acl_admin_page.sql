-- CANDO-2787: Adds ACL Admin page to Main Nav

BEGIN WORK;

INSERT INTO authorisation_sub_section ( authorisation_section_id, sub_section, ord ) VALUES (
    (
        SELECT  id
        FROM    authorisation_section
        WHERE   section = 'Admin'
    ),
    'ACL Admin',
    (
        SELECT  MAX(ord) + 1
        FROM    authorisation_sub_section
        WHERE   authorisation_section_id = (
            SELECT  id
            FROM    authorisation_section
            WHERE   section = 'Admin'
        )
    )
);


COMMIT WORK;
