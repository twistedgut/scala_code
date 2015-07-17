-- CANDO-8326: New Order Search by Designer Menu Option

BEGIN WORK;

--
-- create the new main nav option under 'Customer Care'
--
INSERT INTO authorisation_sub_section (authorisation_section_id, sub_section, ord ) VALUES (
    (
        SELECT  id
        FROM    authorisation_section
        WHERE   section = 'Customer Care'
    ),
    'Order Search by Designer',
    (
        SELECT  MAX(ord) + 1
        FROM    authorisation_sub_section
        WHERE   authorisation_section_id = (
            SELECT  id
            FROM    authorisation_section
            WHERE   section = 'Customer Care'
        )
    )
);

COMMIT WORK;
