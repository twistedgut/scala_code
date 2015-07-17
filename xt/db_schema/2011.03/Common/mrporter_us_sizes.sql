-- Create tables and data for US size mappings.
-- MrP needs this because the current standard sizes aren't
-- accurate enough to be translated to US sizes for menswear.
-- Only really required in DC2 at the moment but we want to 
-- keep DCs the same.

BEGIN;

    -- Just in case
    DROP TABLE IF EXISTS us_size_mapping;
    DROP TABLE IF EXISTS us_size;

    -- Shirts are a separate group for MrP, so let's make a std_group row for them
    CREATE FUNCTION insert_std_group() RETURNS void
    AS $$
    BEGIN
        BEGIN
            INSERT INTO public.std_group (name)
                VALUES ('Shirts');
        EXCEPTION WHEN unique_violation THEN
                -- ignore duplicate errors 
        END;
    END;
    $$ LANGUAGE plpgsql;

    SELECT insert_std_group();

    DROP FUNCTION insert_std_group();


    -- Create the US size table
    CREATE TABLE us_size (
        id                  serial          primary key,
        name                text            not null,
        std_group_id        integer         not null
                            REFERENCES      std_group(id) DEFERRABLE,
        rank                integer         not null,

        UNIQUE (name, std_group_id),
        UNIQUE (rank, std_group_id)
    );

    GRANT ALL ON us_size TO www;

    -- Insert the US sizes
    INSERT INTO us_size (name, std_group_id, rank)
        SELECT '36', sg.id, 1 FROM std_group sg where sg.name='Clothing';
    INSERT INTO us_size (name, std_group_id, rank)
        SELECT '38', sg.id, 2 FROM std_group sg where sg.name='Clothing';
    INSERT INTO us_size (name, std_group_id, rank)
        SELECT '40', sg.id, 3 FROM std_group sg where sg.name='Clothing';
    INSERT INTO us_size (name, std_group_id, rank)
        SELECT '42', sg.id, 4 FROM std_group sg where sg.name='Clothing';
    INSERT INTO us_size (name, std_group_id, rank)
        SELECT '44', sg.id, 5 FROM std_group sg where sg.name='Clothing';
    INSERT INTO us_size (name, std_group_id, rank)
        SELECT '46', sg.id, 6 FROM std_group sg where sg.name='Clothing';
    INSERT INTO us_size (name, std_group_id, rank)
        SELECT '48', sg.id, 7 FROM std_group sg where sg.name='Clothing';
    INSERT INTO us_size (name, std_group_id, rank)
        SELECT '50', sg.id, 8 FROM std_group sg where sg.name='Clothing';
    INSERT INTO us_size (name, std_group_id, rank)
        SELECT '52', sg.id, 9 FROM std_group sg where sg.name='Clothing';

    INSERT INTO us_size (name, std_group_id, rank)
        SELECT '36', sg.id, 1 FROM std_group sg where sg.name='Shirts';
    INSERT INTO us_size (name, std_group_id, rank)
        SELECT '37', sg.id, 2 FROM std_group sg where sg.name='Shirts';
    INSERT INTO us_size (name, std_group_id, rank)
        SELECT '38', sg.id, 3 FROM std_group sg where sg.name='Shirts';
    INSERT INTO us_size (name, std_group_id, rank)
        SELECT '39', sg.id, 4 FROM std_group sg where sg.name='Shirts';
    INSERT INTO us_size (name, std_group_id, rank)
        SELECT '40', sg.id, 5 FROM std_group sg where sg.name='Shirts';
    INSERT INTO us_size (name, std_group_id, rank)
        SELECT '41', sg.id, 6 FROM std_group sg where sg.name='Shirts';
    INSERT INTO us_size (name, std_group_id, rank)
        SELECT '42', sg.id, 7 FROM std_group sg where sg.name='Shirts';
    INSERT INTO us_size (name, std_group_id, rank)
        SELECT '43', sg.id, 8 FROM std_group sg where sg.name='Shirts';
    INSERT INTO us_size (name, std_group_id, rank)
        SELECT '44', sg.id, 9 FROM std_group sg where sg.name='Shirts';
    INSERT INTO us_size (name, std_group_id, rank)
        SELECT '45', sg.id, 10 FROM std_group sg where sg.name='Shirts';

    INSERT INTO us_size (name, std_group_id, rank)
        SELECT '5', sg.id, 1 FROM std_group sg where sg.name='Shoes';
    INSERT INTO us_size (name, std_group_id, rank)
        SELECT '5.5', sg.id, 2 FROM std_group sg where sg.name='Shoes';
    INSERT INTO us_size (name, std_group_id, rank)
        SELECT '6', sg.id, 3 FROM std_group sg where sg.name='Shoes';
    INSERT INTO us_size (name, std_group_id, rank)
        SELECT '6.5', sg.id, 4 FROM std_group sg where sg.name='Shoes';
    INSERT INTO us_size (name, std_group_id, rank)
        SELECT '7', sg.id, 5 FROM std_group sg where sg.name='Shoes';
    INSERT INTO us_size (name, std_group_id, rank)
        SELECT '7.5', sg.id, 6 FROM std_group sg where sg.name='Shoes';
    INSERT INTO us_size (name, std_group_id, rank)
        SELECT '8', sg.id, 7 FROM std_group sg where sg.name='Shoes';
    INSERT INTO us_size (name, std_group_id, rank)
        SELECT '8.5', sg.id, 8 FROM std_group sg where sg.name='Shoes';
    INSERT INTO us_size (name, std_group_id, rank)
        SELECT '9', sg.id, 9 FROM std_group sg where sg.name='Shoes';
    INSERT INTO us_size (name, std_group_id, rank)
        SELECT '9.5', sg.id, 10 FROM std_group sg where sg.name='Shoes';
    INSERT INTO us_size (name, std_group_id, rank)
        SELECT '10', sg.id, 11 FROM std_group sg where sg.name='Shoes';
    INSERT INTO us_size (name, std_group_id, rank)
        SELECT '10.5', sg.id, 12 FROM std_group sg where sg.name='Shoes';
    INSERT INTO us_size (name, std_group_id, rank)
        SELECT '11', sg.id, 13 FROM std_group sg where sg.name='Shoes';
    INSERT INTO us_size (name, std_group_id, rank)
        SELECT '11.5', sg.id, 14 FROM std_group sg where sg.name='Shoes';
    INSERT INTO us_size (name, std_group_id, rank)
        SELECT '12', sg.id, 15 FROM std_group sg where sg.name='Shoes';
    INSERT INTO us_size (name, std_group_id, rank)
        SELECT '12.5', sg.id, 16 FROM std_group sg where sg.name='Shoes';
    INSERT INTO us_size (name, std_group_id, rank)
        SELECT '13', sg.id, 17 FROM std_group sg where sg.name='Shoes';
    INSERT INTO us_size (name, std_group_id, rank)
        SELECT '13.5', sg.id, 18 FROM std_group sg where sg.name='Shoes';

    -- Create the mappings between sizes and US sizes
    CREATE TABLE us_size_mapping (
        id                  serial          primary key,
        size_scheme_id      integer         not null
                            REFERENCES      size_scheme(id) DEFERRABLE,
        size_id             integer         not null
                            REFERENCES      size(id) DEFERRABLE,
        us_size_id          integer         not null
                            REFERENCES      us_size(id) DEFERRABLE,

        UNIQUE (size_scheme_id, size_id)
    );

    GRANT ALL ON us_size_mapping TO www;


    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - FR full size' AND s.size='40' AND us.name='7' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - FR full size' AND s.size='41' AND us.name='8' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - FR full size' AND s.size='42' AND us.name='9' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - FR full size' AND s.size='43' AND us.name='10' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - FR full size' AND s.size='44' AND us.name='11' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - FR full size' AND s.size='45' AND us.name='12' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - FR full size' AND s.size='46' AND us.name='13' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - EU full size' AND s.size='40' AND us.name='7' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - EU full size' AND s.size='41' AND us.name='8' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - EU full size' AND s.size='42' AND us.name='9' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - EU full size' AND s.size='43' AND us.name='10' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - EU full size' AND s.size='44' AND us.name='11' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - EU full size' AND s.size='45' AND us.name='12' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - EU full size' AND s.size='46' AND us.name='13' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - EU half size' AND s.size='39' AND us.name='6' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - EU half size' AND s.size='39.5' AND us.name='6.5' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - EU half size' AND s.size='40' AND us.name='7' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - EU half size' AND s.size='40.5' AND us.name='7.5' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - EU half size' AND s.size='41' AND us.name='8' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - EU half size' AND s.size='41.5' AND us.name='8.5' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - EU half size' AND s.size='42' AND us.name='9' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - EU half size' AND s.size='42.5' AND us.name='9.5' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - EU half size' AND s.size='43' AND us.name='10' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - EU half size' AND s.size='43.5' AND us.name='10.5' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - EU half size' AND s.size='44' AND us.name='11' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - EU half size' AND s.size='44.5' AND us.name='11.5' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - EU half size' AND s.size='45' AND us.name='12' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - EU half size' AND s.size='45.5' AND us.name='12.5' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - EU half size' AND s.size='46' AND us.name='13' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - EU half size' AND s.size='46.5' AND us.name='13.5' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - UK full size' AND s.size='5' AND us.name='5.5' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - UK full size' AND s.size='6' AND us.name='6.5' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - UK full size' AND s.size='7' AND us.name='7.5' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - UK full size' AND s.size='8' AND us.name='8.5' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - UK full size' AND s.size='9' AND us.name='9.5' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - UK full size' AND s.size='10' AND us.name='10.5' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - UK full size' AND s.size='11' AND us.name='11.5' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - UK full size' AND s.size='12' AND us.name='12.5' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - UK full size' AND s.size='13' AND us.name='13.5' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - UK half size' AND s.size='5' AND us.name='5.5' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - UK half size' AND s.size='5.5' AND us.name='6' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - UK half size' AND s.size='6' AND us.name='6.5' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - UK half size' AND s.size='6.5' AND us.name='7' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - UK half size' AND s.size='7' AND us.name='7.5' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - UK half size' AND s.size='7.5' AND us.name='8' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - UK half size' AND s.size='8' AND us.name='8.5' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - UK half size' AND s.size='8.5' AND us.name='9' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - UK half size' AND s.size='9' AND us.name='9.5' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - UK half size' AND s.size='9.5' AND us.name='10' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - UK half size' AND s.size='10' AND us.name='10.5' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - UK half size' AND s.size='10.5' AND us.name='11' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - UK half size' AND s.size='11' AND us.name='11.5' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - UK half size' AND s.size='11.5' AND us.name='12' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - UK half size' AND s.size='12' AND us.name='12.5' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - UK half size' AND s.size='12.5' AND us.name='13' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shoes - UK half size' AND s.size='13' AND us.name='13.5' AND sg.name='Shoes'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts EU' AND s.size='37' AND us.name='36' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts EU' AND s.size='38' AND us.name='37' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts EU' AND s.size='39' AND us.name='38' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts EU' AND s.size='40' AND us.name='39' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts EU' AND s.size='41' AND us.name='40' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts EU' AND s.size='42' AND us.name='41' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts EU' AND s.size='43' AND us.name='42' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts EU' AND s.size='44' AND us.name='43' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts EU' AND s.size='45' AND us.name='44' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts EU' AND s.size='46' AND us.name='45' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts UK' AND s.size='14' AND us.name='36' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts UK' AND s.size='14.5' AND us.name='37' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts UK' AND s.size='15' AND us.name='38' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts UK' AND s.size='15.5' AND us.name='39' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts UK' AND s.size='16' AND us.name='40' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts UK' AND s.size='16.5' AND us.name='41' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts UK' AND s.size='17' AND us.name='42' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts UK' AND s.size='17.5' AND us.name='43' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts UK' AND s.size='18' AND us.name='44' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts UK' AND s.size='18.5' AND us.name='45' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts UK sleeves size' AND s.size='14/33' AND us.name='36' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts UK sleeves size' AND s.size='14.5/33' AND us.name='37' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts UK sleeves size' AND s.size='15/33' AND us.name='38' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts UK sleeves size' AND s.size='15.5/33' AND us.name='39' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts UK sleeves size' AND s.size='16/33' AND us.name='40' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts UK sleeves size' AND s.size='16.5/33' AND us.name='41' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts UK sleeves size' AND s.size='17/33' AND us.name='42' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts UK sleeves size' AND s.size='17.5/33' AND us.name='43' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts UK sleeves size' AND s.size='18/33' AND us.name='44' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts UK sleeves size' AND s.size='18.5/33' AND us.name='45' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts UK sleeves size' AND s.size='14/34' AND us.name='36' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts UK sleeves size' AND s.size='14.5/34' AND us.name='37' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts UK sleeves size' AND s.size='15/34' AND us.name='38' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts UK sleeves size' AND s.size='15.5/34' AND us.name='39' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts UK sleeves size' AND s.size='16/34' AND us.name='40' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts UK sleeves size' AND s.size='16.5/34' AND us.name='41' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts UK sleeves size' AND s.size='17/34' AND us.name='42' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts UK sleeves size' AND s.size='17.5/34' AND us.name='43' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts UK sleeves size' AND s.size='18/34' AND us.name='44' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts UK sleeves size' AND s.size='18.5/34' AND us.name='45' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts UK sleeves size' AND s.size='14/35' AND us.name='36' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts UK sleeves size' AND s.size='14.5/35' AND us.name='37' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts UK sleeves size' AND s.size='15/35' AND us.name='38' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts UK sleeves size' AND s.size='15.5/35' AND us.name='39' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts UK sleeves size' AND s.size='16/35' AND us.name='40' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts UK sleeves size' AND s.size='16.5/35' AND us.name='41' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts UK sleeves size' AND s.size='17/35' AND us.name='42' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts UK sleeves size' AND s.size='17.5/35' AND us.name='43' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts UK sleeves size' AND s.size='18/35' AND us.name='44' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts UK sleeves size' AND s.size='18.5/35' AND us.name='45' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts 38R-44L' AND s.size='38R' AND us.name='37' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts 38R-44L' AND s.size='38L' AND us.name='37' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts 38R-44L' AND s.size='39R' AND us.name='38' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts 38R-44L' AND s.size='39L' AND us.name='38' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts 38R-44L' AND s.size='40R' AND us.name='39' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts 38R-44L' AND s.size='40L' AND us.name='39' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts 38R-44L' AND s.size='41R' AND us.name='40' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts 38R-44L' AND s.size='41L' AND us.name='40' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts 38R-44L' AND s.size='42R' AND us.name='41' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts 38R-44L' AND s.size='42L' AND us.name='41' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts 38R-44L' AND s.size='43R' AND us.name='42' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts 38R-44L' AND s.size='43L' AND us.name='42' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts 38R-44L' AND s.size='44R' AND us.name='43' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts 38R-44L' AND s.size='44L' AND us.name='43' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts 38R-44L' AND s.size='45R' AND us.name='44' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M Shirts 38R-44L' AND s.size='45L' AND us.name='44' AND sg.name='Shirts'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M RTW - FRANCE' AND s.size='46' AND us.name='36' AND sg.name='Clothing'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M RTW - FRANCE' AND s.size='48' AND us.name='38' AND sg.name='Clothing'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M RTW - FRANCE' AND s.size='50' AND us.name='40' AND sg.name='Clothing'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M RTW - FRANCE' AND s.size='52' AND us.name='42' AND sg.name='Clothing'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M RTW - FRANCE' AND s.size='54' AND us.name='44' AND sg.name='Clothing'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M RTW - FRANCE' AND s.size='56' AND us.name='46' AND sg.name='Clothing'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M RTW - FRANCE' AND s.size='58' AND us.name='48' AND sg.name='Clothing'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M RTW - FRANCE' AND s.size='60' AND us.name='50' AND sg.name='Clothing'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M RTW - FRANCE' AND s.size='62' AND us.name='52' AND sg.name='Clothing'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M RTW - ITALY' AND s.size='46' AND us.name='36' AND sg.name='Clothing'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M RTW - ITALY' AND s.size='48' AND us.name='38' AND sg.name='Clothing'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M RTW - ITALY' AND s.size='50' AND us.name='40' AND sg.name='Clothing'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M RTW - ITALY' AND s.size='52' AND us.name='42' AND sg.name='Clothing'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M RTW - ITALY' AND s.size='54' AND us.name='44' AND sg.name='Clothing'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M RTW - ITALY' AND s.size='56' AND us.name='46' AND sg.name='Clothing'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M RTW - ITALY' AND s.size='58' AND us.name='48' AND sg.name='Clothing'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M RTW - ITALY' AND s.size='60' AND us.name='50' AND sg.name='Clothing'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M RTW - ITALY' AND s.size='62' AND us.name='52' AND sg.name='Clothing'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M RTW - UK' AND s.size='36' AND us.name='36' AND sg.name='Clothing'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M RTW - UK' AND s.size='38' AND us.name='38' AND sg.name='Clothing'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M RTW - UK' AND s.size='40' AND us.name='40' AND sg.name='Clothing'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M RTW - UK' AND s.size='42' AND us.name='42' AND sg.name='Clothing'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M RTW - UK' AND s.size='44' AND us.name='44' AND sg.name='Clothing'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M RTW - UK' AND s.size='46' AND us.name='46' AND sg.name='Clothing'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M RTW - UK' AND s.size='48' AND us.name='48' AND sg.name='Clothing'; 
    
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='M RTW - UK' AND s.size='50' AND us.name='50' AND sg.name='Clothing'; 
    



COMMIT;
