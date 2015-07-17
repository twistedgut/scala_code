-- CANDO-2198: Add Language to Promotion Table
--             and Populate it for Welcome Packs

BEGIN WORK;

--
-- Create the Table
--
CREATE TABLE language__promotion_type (
    language_id         INTEGER NOT NULL REFERENCES language(id),
    promotion_type_id   INTEGER NOT NULL REFERENCES promotion_type(id),
    PRIMARY KEY ( language_id, promotion_type_id )
);
ALTER TABLE language__promotion_type OWNER TO postgres;
GRANT ALL ON TABLE language__promotion_type TO www;

--
-- Populate it
--

--
-- NET-A-PORTER
--

-- English
INSERT INTO language__promotion_type (language_id, promotion_type_id) VALUES
(
    (
        SELECT  id
        FROM    language
        WHERE   code = 'en'
    ),
    (
        SELECT  id
        FROM    promotion_type
        WHERE   name = 'Welcome Pack - English'
        AND     channel_id = (
            SELECT  ch.id
            FROM    channel ch
                        JOIN business b ON b.id = ch.business_id
                                       AND b.config_section = 'NAP'
        )
    )
)
;

-- French
INSERT INTO language__promotion_type (language_id, promotion_type_id) VALUES
(
    (
        SELECT  id
        FROM    language
        WHERE   code = 'fr'
    ),
    (
        SELECT  id
        FROM    promotion_type
        WHERE   name = 'Welcome Pack - French'
        AND     channel_id = (
            SELECT  ch.id
            FROM    channel ch
                        JOIN business b ON b.id = ch.business_id
                                       AND b.config_section = 'NAP'
        )
    )
)
;

-- German
INSERT INTO language__promotion_type (language_id, promotion_type_id) VALUES
(
    (
        SELECT  id
        FROM    language
        WHERE   code = 'de'
    ),
    (
        SELECT  id
        FROM    promotion_type
        WHERE   name = 'Welcome Pack - German'
        AND     channel_id = (
            SELECT  ch.id
            FROM    channel ch
                        JOIN business b ON b.id = ch.business_id
                                       AND b.config_section = 'NAP'
        )
    )
)
;

-- Chinese
INSERT INTO language__promotion_type (language_id, promotion_type_id) VALUES
(
    (
        SELECT  id
        FROM    language
        WHERE   code = 'zh'
    ),
    (
        SELECT  id
        FROM    promotion_type
        WHERE   name = 'Welcome Pack - Chinese'
        AND     channel_id = (
            SELECT  ch.id
            FROM    channel ch
                        JOIN business b ON b.id = ch.business_id
                                       AND b.config_section = 'NAP'
        )
    )
)
;


--
-- MR PORTER
--

-- English
INSERT INTO language__promotion_type (language_id, promotion_type_id) VALUES
(
    (
        SELECT  id
        FROM    language
        WHERE   code = 'en'
    ),
    (
        SELECT  id
        FROM    promotion_type
        WHERE   name = 'Welcome Pack - English'
        AND     channel_id = (
            SELECT  ch.id
            FROM    channel ch
                        JOIN business b ON b.id = ch.business_id
                                       AND b.config_section = 'MRP'
        )
    )
)
;

COMMIT WORK;
