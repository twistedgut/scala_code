-- Create tables for standard size mappings

BEGIN;

    -- Create the group names of the standard sizes
    CREATE TABLE std_group (
        id                  serial          primary key,
        name                text            not null unique
    );

    GRANT ALL ON std_group TO www;

    -- Create the standard size table
    CREATE TABLE std_size (
        id                  serial          primary key,
        name                text            not null,
        std_group_id        integer         not null
                            REFERENCES      std_group(id),
        rank                integer         not null,

        UNIQUE (name, std_group_id),
        UNIQUE (rank, std_group_id)
    );

    GRANT ALL ON std_size TO www;

    -- Create the mappings between sizes and standard sizes
    CREATE TABLE std_size_mapping (
        id                  serial          primary key,
        size_scheme_id      integer         not null
                            REFERENCES      size_scheme(id),
        size_id             integer         not null
                            REFERENCES      size(id),
        classification_id   integer         not null
                            REFERENCES      classification(id),
        product_type_id     integer
                            REFERENCES      product_type(id),
        std_size_id         integer         not null
                            REFERENCES      std_size(id),

        UNIQUE (size_scheme_id, size_id, classification_id, product_type_id)
    );

    GRANT ALL ON std_size_mapping TO www;

    -- Link variant table to standard size
    ALTER TABLE variant ADD COLUMN std_size_id integer
        REFERENCES std_size(id);

COMMIT;
