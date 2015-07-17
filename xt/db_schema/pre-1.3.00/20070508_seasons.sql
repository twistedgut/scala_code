-- Stage 1 : alter the table schema
BEGIN;

    create table season_lookup
    (
        code  int primary key,
        value text not null
    );
    insert into season_lookup values(0,'Unknown');
    insert into season_lookup values(10,'Cruise');
    insert into season_lookup values(20,'Spring/Summer');
    insert into season_lookup values(30,'High Summer');
    insert into season_lookup values(40,'Fall/Winter');

    ALTER TABLE season
    ADD COLUMN  season_year     smallint   default('9999'),
    ADD COLUMN  season_code     smallint   references season_lookup(code)  default(0)
    ;

COMMIT;

-- Stage 2 : assign date information for season data
BEGIN;

    -- 2000
    UPDATE season SET   season_year = 2000,     season_code = 10    WHERE   season = 'CR00';
    UPDATE season SET   season_year = 2000,     season_code = 20    WHERE   season = 'SS00';
    UPDATE season SET   season_year = 2000,     season_code = 30    WHERE   season = 'HS00';
    UPDATE season SET   season_year = 2000,     season_code = 40    WHERE   season = 'FW00';

    -- 2001
    UPDATE season SET   season_year = 2001,     season_code = 10    WHERE   season = 'CR01';
    UPDATE season SET   season_year = 2001,     season_code = 20    WHERE   season = 'SS01';
    UPDATE season SET   season_year = 2001,     season_code = 30    WHERE   season = 'HS01';
    UPDATE season SET   season_year = 2001,     season_code = 40    WHERE   season = 'FW01';

    -- 2002
    UPDATE season SET   season_year = 2002,     season_code = 10    WHERE   season = 'CR02';
    UPDATE season SET   season_year = 2002,     season_code = 20    WHERE   season = 'SS02';
    UPDATE season SET   season_year = 2002,     season_code = 30    WHERE   season = 'HS02';
    UPDATE season SET   season_year = 2002,     season_code = 40    WHERE   season = 'FW02';

    -- 2003
    UPDATE season SET   season_year = 2003,     season_code = 10    WHERE   season = 'CR03';
    UPDATE season SET   season_year = 2003,     season_code = 20    WHERE   season = 'SS03';
    UPDATE season SET   season_year = 2003,     season_code = 30    WHERE   season = 'HS03';
    UPDATE season SET   season_year = 2003,     season_code = 40    WHERE   season = 'FW03';

    -- 2004
    UPDATE season SET   season_year = 2004,     season_code = 10    WHERE   season = 'CR04';
    UPDATE season SET   season_year = 2004,     season_code = 20    WHERE   season = 'SS04';
    UPDATE season SET   season_year = 2004,     season_code = 30    WHERE   season = 'HS04';
    UPDATE season SET   season_year = 2004,     season_code = 40    WHERE   season = 'FW04';

    -- 2005
    UPDATE season SET   season_year = 2005,     season_code = 10    WHERE   season = 'CR05';
    UPDATE season SET   season_year = 2005,     season_code = 20    WHERE   season = 'SS05';
    UPDATE season SET   season_year = 2005,     season_code = 30    WHERE   season = 'HS05';
    UPDATE season SET   season_year = 2005,     season_code = 40    WHERE   season = 'FW05';

    -- 2006
    UPDATE season SET   season_year = 2006,     season_code = 10    WHERE   season = 'CR06';
    UPDATE season SET   season_year = 2006,     season_code = 20    WHERE   season = 'SS06';
    UPDATE season SET   season_year = 2006,     season_code = 30    WHERE   season = 'HS06';
    UPDATE season SET   season_year = 2006,     season_code = 40    WHERE   season = 'FW06';

    -- 2007
    UPDATE season SET   season_year = 2007,     season_code = 10    WHERE   season = 'CR07';
    UPDATE season SET   season_year = 2007,     season_code = 20    WHERE   season = 'SS07';
    UPDATE season SET   season_year = 2007,     season_code = 30    WHERE   season = 'HS07';
    UPDATE season SET   season_year = 2007,     season_code = 40    WHERE   season = 'FW07';

    -- 2008
    UPDATE season SET   season_year = 2008,     season_code = 10    WHERE   season = 'CR08';
    UPDATE season SET   season_year = 2008,     season_code = 20    WHERE   season = 'SS08';
    UPDATE season SET   season_year = 2008,     season_code = 30    WHERE   season = 'HS08';
    UPDATE season SET   season_year = 2008,     season_code = 40    WHERE   season = 'FW08';

    -- 2009
    UPDATE season SET   season_year = 2009,     season_code = 10    WHERE   season = 'CR09';
    UPDATE season SET   season_year = 2009,     season_code = 20    WHERE   season = 'SS09';
    UPDATE season SET   season_year = 2009,     season_code = 30    WHERE   season = 'HS09';
    UPDATE season SET   season_year = 2009,     season_code = 40    WHERE   season = 'FW09';

    -- 2010
    UPDATE season SET   season_year = 2010,     season_code = 10    WHERE   season = 'CR10';
    UPDATE season SET   season_year = 2010,     season_code = 20    WHERE   season = 'SS10';
    UPDATE season SET   season_year = 2010,     season_code = 30    WHERE   season = 'HS10';
    UPDATE season SET   season_year = 2010,     season_code = 40    WHERE   season = 'FW10';

COMMIT;
