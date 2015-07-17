-- CANDO-2198: Add Welcome Pack menu option

BEGIN WORK;

INSERT INTO authorisation_sub_section (authorisation_section_id,sub_section,ord) VALUES (
    (
        SELECT  id
        FROM    authorisation_section
        WHERE   section = 'NAP Events'
    ),
    'Welcome Packs',
    (
        SELECT  COUNT(*) + 1
        FROM    authorisation_sub_section
        WHERE   authorisation_section_id = (
            SELECT  id
            FROM    authorisation_section
            WHERE   section = 'NAP Events'
        )
    )
);

--
-- Give everyone who has access to 'In The Box' access to 'Welcome Packs'
--
INSERT INTO operator_authorisation ( operator_id, authorisation_sub_section_id, authorisation_level_id )
SELECT  oa.operator_id,
        as2.id,
        al.id
FROM    operator_authorisation oa
            JOIN authorisation_sub_section as1 ON as1.id          = oa.authorisation_sub_section_id
                                              AND as1.sub_section = 'In The Box',
        authorisation_sub_section as2,
        authorisation_level al
WHERE   as2.sub_section = 'Welcome Packs'
AND     al.description   = 'Operator'
;

COMMIT WORK;
