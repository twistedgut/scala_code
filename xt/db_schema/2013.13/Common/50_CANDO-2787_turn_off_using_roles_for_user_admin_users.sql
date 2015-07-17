-- CANDO-2787: For Operators who have access to User Admin give them
--             access to the ACL Admin page and make sure they don't
--             use ACL Roles by default to build the Main Nav

BEGIN WORK;

--
-- Make sure User Admin Operators don't build
-- the Main Nav using Roles by default
--
UPDATE  operator
    SET use_acl_for_main_nav = FALSE
WHERE id IN (
    SELECT  oa.operator_id
    FROM    operator_authorisation oa
            JOIN authorisation_sub_section ass ON ass.id          = oa.authorisation_sub_section_id
                                              AND ass.sub_section = 'User Admin'
            JOIN authorisation_section asect   ON asect.id        = ass.authorisation_section_id
                                              AND asect.section   = 'Admin'
    WHERE   oa.authorisation_level_id > (
        SELECT  id
        FROM    authorisation_level
        WHERE   description = 'Read Only'
    )
)
;

--
-- Give Access to 'ACL Admin' to User Admin Operators
--
INSERT INTO operator_authorisation ( operator_id, authorisation_sub_section_id, authorisation_level_id )
SELECT  oa.operator_id,
        (
            SELECT  id
            FROM    authorisation_sub_section
            WHERE   sub_section = 'ACL Admin'
        ),
        (
            SELECT  id
            FROM    authorisation_level
            WHERE   description = 'Manager'
        )
FROM    operator_authorisation oa
        JOIN authorisation_sub_section ass ON ass.id          = oa.authorisation_sub_section_id
                                          AND ass.sub_section = 'User Admin'
        JOIN authorisation_section asect   ON asect.id        = ass.authorisation_section_id
                                          AND asect.section   = 'Admin'
WHERE   oa.authorisation_level_id > (
    SELECT  id
    FROM    authorisation_level
    WHERE   description = 'Read Only'
)
;

COMMIT WORK;
