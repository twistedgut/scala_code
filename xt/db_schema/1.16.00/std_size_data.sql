-- Populate the standardised size tables

BEGIN;

    DELETE FROM std_size_mapping;
    DELETE FROM std_size;
    DELETE FROM std_group;
    -- Populate standardised group names
    INSERT INTO std_group (name) VALUES
        ('Clothing'),
        ('Shoes')
    ;

    -- Populate standardised value names
    INSERT INTO std_size (name, std_group_id, rank) VALUES
        ('XXS'  , (SELECT id FROM std_group WHERE name = 'Clothing'), 1),
        ('XS'   , (SELECT id FROM std_group WHERE name = 'Clothing'), 2),
        ('S'    , (SELECT id FROM std_group WHERE name = 'Clothing'), 3),
        ('M'    , (SELECT id FROM std_group WHERE name = 'Clothing'), 4),
        ('L'    , (SELECT id FROM std_group WHERE name = 'Clothing'), 5),
        ('XL'   , (SELECT id FROM std_group WHERE name = 'Clothing'), 6),
        ('36'   , (SELECT id FROM std_group WHERE name = 'Shoes'), 1),
        ('36.5' , (SELECT id FROM std_group WHERE name = 'Shoes'), 2),
        ('37'   , (SELECT id FROM std_group WHERE name = 'Shoes'), 3),
        ('37.5' , (SELECT id FROM std_group WHERE name = 'Shoes'), 4),
        ('38'   , (SELECT id FROM std_group WHERE name = 'Shoes'), 5),
        ('38.5' , (SELECT id FROM std_group WHERE name = 'Shoes'), 6),
        ('39'   , (SELECT id FROM std_group WHERE name = 'Shoes'), 7),
        ('39.5' , (SELECT id FROM std_group WHERE name = 'Shoes'), 8),
        ('40'   , (SELECT id FROM std_group WHERE name = 'Shoes'), 9),
        ('40.5' , (SELECT id FROM std_group WHERE name = 'Shoes'), 10),
        ('41'   , (SELECT id FROM std_group WHERE name = 'Shoes'), 11),
	('41.5' , (SELECT id FROM std_group WHERE name = 'Shoes'), 12),
	('42'   , (SELECT id FROM std_group WHERE name = 'Shoes'), 13)
    ;

    -- Populate standardised size mapping table
    INSERT INTO std_size_mapping (
        size_scheme_id,
        size_id,
        classification_id,
        product_type_id,
        std_size_id
    ) VALUES
    (
        (SELECT id FROM size_scheme WHERE name = 'RTW - UK'),
        (SELECT id FROM size WHERE size = '6'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'XXS')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'RTW - Danish'),
        (SELECT id FROM size WHERE size = '32'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'XXS')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'RTW - Japan'),
        (SELECT id FROM size WHERE size = '5'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'XXS')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'RTW - US'),
        (SELECT id FROM size WHERE size = '0'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'XXS')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'RTW - US'),
        (SELECT id FROM size WHERE size = '1'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'XXS')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'RTW - US'),
        (SELECT id FROM size WHERE size = '2'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'XXS')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'RTW - France'),
        (SELECT id FROM size WHERE size = '34'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'XXS')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'RTW - Italy'),
        (SELECT id FROM size WHERE size = '38'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'XXS')
    );

    INSERT INTO std_size_mapping (
        size_scheme_id,
        size_id,
        classification_id,
        product_type_id,
        std_size_id
    ) VALUES
    (
        (SELECT id FROM size_scheme WHERE name = 'RTW - UK'),
        (SELECT id FROM size WHERE size = '8'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'XS')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'RTW - Danish'),
        (SELECT id FROM size WHERE size = '34'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'XS')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'RTW - Japan'),
        (SELECT id FROM size WHERE size = '7'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'XS')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'RTW - US'),
        (SELECT id FROM size WHERE size = '4'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'XS')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'RTW - France'),
        (SELECT id FROM size WHERE size = '36'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'XS')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'RTW - Italy'),
        (SELECT id FROM size WHERE size = '40'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'XS')
    );

    INSERT INTO std_size_mapping (
        size_scheme_id,
        size_id,
        classification_id,
        product_type_id,
        std_size_id
    ) VALUES
    (
        (SELECT id FROM size_scheme WHERE name = 'RTW - UK'),
        (SELECT id FROM size WHERE size = '10'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'S')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'RTW - Danish'),
        (SELECT id FROM size WHERE size = '36'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'S')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'RTW - Japan'),
        (SELECT id FROM size WHERE size = '9'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'S')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'RTW - US'),
        (SELECT id FROM size WHERE size = '6'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'S')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'RTW - France'),
        (SELECT id FROM size WHERE size = '38'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'S')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'RTW - Italy'),
        (SELECT id FROM size WHERE size = '42'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'S')
    );

    INSERT INTO std_size_mapping (
        size_scheme_id,
        size_id,
        classification_id,
        product_type_id,
        std_size_id
    ) VALUES
    (
        (SELECT id FROM size_scheme WHERE name = 'RTW - UK'),
        (SELECT id FROM size WHERE size = '12'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'M')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'RTW - Danish'),
        (SELECT id FROM size WHERE size = '38'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'M')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'RTW - Japan'),
        (SELECT id FROM size WHERE size = '11'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'M')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'RTW - US'),
        (SELECT id FROM size WHERE size = '8'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'M')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'RTW - France'),
        (SELECT id FROM size WHERE size = '40'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'M')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'RTW - Italy'),
        (SELECT id FROM size WHERE size = '44'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'M')
    );

    INSERT INTO std_size_mapping (
        size_scheme_id,
        size_id,
        classification_id,
        product_type_id,
        std_size_id
    ) VALUES
    (
        (SELECT id FROM size_scheme WHERE name = 'RTW - UK'),
        (SELECT id FROM size WHERE size = '14'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'L')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'RTW - Danish'),
        (SELECT id FROM size WHERE size = '40'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'L')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'RTW - Japan'),
        (SELECT id FROM size WHERE size = '13'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'L')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'RTW - US'),
        (SELECT id FROM size WHERE size = '10'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'L')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'RTW - France'),
        (SELECT id FROM size WHERE size = '42'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'L')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'RTW - Italy'),
        (SELECT id FROM size WHERE size = '46'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'L')
    );

    INSERT INTO std_size_mapping (
        size_scheme_id,
        size_id,
        classification_id,
        product_type_id,
        std_size_id
    ) VALUES
    (
        (SELECT id FROM size_scheme WHERE name = 'RTW - UK'),
        (SELECT id FROM size WHERE size = '16'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'XL')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'RTW - Danish'),
        (SELECT id FROM size WHERE size = '42'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'XL')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'RTW - Japan'),
        (SELECT id FROM size WHERE size = '15'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'XL')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'RTW - US'),
        (SELECT id FROM size WHERE size = '12'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'XL')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'RTW - France'),
        (SELECT id FROM size WHERE size = '44'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'XL')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'RTW - Italy'),
        (SELECT id FROM size WHERE size = '48'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'XL')
    );

    INSERT INTO std_size_mapping (
        size_scheme_id,
        size_id,
        classification_id,
        product_type_id,
        std_size_id
    ) VALUES
    (
        (SELECT id FROM size_scheme WHERE name = 'RTW - UK'),
        (SELECT id FROM size WHERE size = '16'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'XL')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'RTW - Danish'),
        (SELECT id FROM size WHERE size = '42'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'XL')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'RTW - Japan'),
        (SELECT id FROM size WHERE size = '15'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'XL')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'RTW - US'),
        (SELECT id FROM size WHERE size = '12'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'XL')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'RTW - France'),
        (SELECT id FROM size WHERE size = '44'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'XL')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'RTW - Italy'),
        (SELECT id FROM size WHERE size = '48'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'XL')
    );

    INSERT INTO std_size_mapping (
        size_scheme_id,
        size_id,
        classification_id,
        product_type_id,
        std_size_id
    ) VALUES
    (
        (SELECT id FROM size_scheme WHERE name = 'Shoes - Italian'),
        (SELECT id FROM size WHERE size = '36'),
        (SELECT id FROM classification WHERE classification = 'Shoes'),
        NULL,
        (SELECT id FROM std_size WHERE name = '36')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'Shoes - UK'),
        (SELECT id FROM size WHERE size = '3'),
        (SELECT id FROM classification WHERE classification = 'Shoes'),
        NULL,
        (SELECT id FROM std_size WHERE name = '36')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'Shoes - US'),
        (SELECT id FROM size WHERE size = '6'),
        (SELECT id FROM classification WHERE classification = 'Shoes'),
        NULL,
        (SELECT id FROM std_size WHERE name = '36')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'Shoes - France'),
        (SELECT id FROM size WHERE size = '37'),
        (SELECT id FROM classification WHERE classification = 'Shoes'),
        NULL,
        (SELECT id FROM std_size WHERE name = '36')
    );

    INSERT INTO std_size_mapping (
        size_scheme_id,
        size_id,
        classification_id,
        product_type_id,
        std_size_id
    ) VALUES
    (
        (SELECT id FROM size_scheme WHERE name = 'Shoes - Italian'),
        (SELECT id FROM size WHERE size = '36.5'),
        (SELECT id FROM classification WHERE classification = 'Shoes'),
        NULL,
        (SELECT id FROM std_size WHERE name = '36.5')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'Shoes - UK'),
        (SELECT id FROM size WHERE size = '3.5'),
        (SELECT id FROM classification WHERE classification = 'Shoes'),
        NULL,
        (SELECT id FROM std_size WHERE name = '36.5')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'Shoes - US'),
        (SELECT id FROM size WHERE size = '6.5'),
        (SELECT id FROM classification WHERE classification = 'Shoes'),
        NULL,
        (SELECT id FROM std_size WHERE name = '36.5')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'Shoes - France'),
        (SELECT id FROM size WHERE size = '37.5'),
        (SELECT id FROM classification WHERE classification = 'Shoes'),
        NULL,
        (SELECT id FROM std_size WHERE name = '36.5')
    );

    INSERT INTO std_size_mapping (
        size_scheme_id,
        size_id,
        classification_id,
        product_type_id,
        std_size_id
    ) VALUES
    (
        (SELECT id FROM size_scheme WHERE name = 'Shoes - Italian'),
        (SELECT id FROM size WHERE size = '37'),
        (SELECT id FROM classification WHERE classification = 'Shoes'),
        NULL,
        (SELECT id FROM std_size WHERE name = '37')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'Shoes - UK'),
        (SELECT id FROM size WHERE size = '4'),
        (SELECT id FROM classification WHERE classification = 'Shoes'),
        NULL,
        (SELECT id FROM std_size WHERE name = '37')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'Shoes - US'),
        (SELECT id FROM size WHERE size = '7'),
        (SELECT id FROM classification WHERE classification = 'Shoes'),
        NULL,
        (SELECT id FROM std_size WHERE name = '37')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'Shoes - France'),
        (SELECT id FROM size WHERE size = '38'),
        (SELECT id FROM classification WHERE classification = 'Shoes'),
        NULL,
        (SELECT id FROM std_size WHERE name = '37')
    );

    INSERT INTO std_size_mapping (
        size_scheme_id,
        size_id,
        classification_id,
        product_type_id,
        std_size_id
    ) VALUES
    (
        (SELECT id FROM size_scheme WHERE name = 'Shoes - Italian'),
        (SELECT id FROM size WHERE size = '37.5'),
        (SELECT id FROM classification WHERE classification = 'Shoes'),
        NULL,
        (SELECT id FROM std_size WHERE name = '37.5')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'Shoes - UK'),
        (SELECT id FROM size WHERE size = '4.5'),
        (SELECT id FROM classification WHERE classification = 'Shoes'),
        NULL,
        (SELECT id FROM std_size WHERE name = '37.5')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'Shoes - US'),
        (SELECT id FROM size WHERE size = '7.5'),
        (SELECT id FROM classification WHERE classification = 'Shoes'),
        NULL,
        (SELECT id FROM std_size WHERE name = '37.5')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'Shoes - France'),
        (SELECT id FROM size WHERE size = '38.5'),
        (SELECT id FROM classification WHERE classification = 'Shoes'),
        NULL,
        (SELECT id FROM std_size WHERE name = '37.5')
    );

    INSERT INTO std_size_mapping (
        size_scheme_id,
        size_id,
        classification_id,
        product_type_id,
        std_size_id
    ) VALUES
    (
        (SELECT id FROM size_scheme WHERE name = 'Shoes - Italian'),
        (SELECT id FROM size WHERE size = '38'),
        (SELECT id FROM classification WHERE classification = 'Shoes'),
        NULL,
        (SELECT id FROM std_size WHERE name = '38')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'Shoes - UK'),
        (SELECT id FROM size WHERE size = '5'),
        (SELECT id FROM classification WHERE classification = 'Shoes'),
        NULL,
        (SELECT id FROM std_size WHERE name = '38')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'Shoes - US'),
        (SELECT id FROM size WHERE size = '8'),
        (SELECT id FROM classification WHERE classification = 'Shoes'),
        NULL,
        (SELECT id FROM std_size WHERE name = '38')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'Shoes - France'),
        (SELECT id FROM size WHERE size = '39.5'),
        (SELECT id FROM classification WHERE classification = 'Shoes'),
        NULL,
        (SELECT id FROM std_size WHERE name = '38')
    );

    INSERT INTO std_size_mapping (
        size_scheme_id,
        size_id,
        classification_id,
        product_type_id,
        std_size_id
    ) VALUES
    (
        (SELECT id FROM size_scheme WHERE name = 'Shoes - Italian'),
        (SELECT id FROM size WHERE size = '38.5'),
        (SELECT id FROM classification WHERE classification = 'Shoes'),
        NULL,
        (SELECT id FROM std_size WHERE name = '38.5')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'Shoes - UK'),
        (SELECT id FROM size WHERE size = '5.5'),
        (SELECT id FROM classification WHERE classification = 'Shoes'),
        NULL,
        (SELECT id FROM std_size WHERE name = '38.5')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'Shoes - US'),
        (SELECT id FROM size WHERE size = '8.5'),
        (SELECT id FROM classification WHERE classification = 'Shoes'),
        NULL,
        (SELECT id FROM std_size WHERE name = '38.5')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'Shoes - France'),
        (SELECT id FROM size WHERE size = '39.5'),
        (SELECT id FROM classification WHERE classification = 'Shoes'),
        NULL,
        (SELECT id FROM std_size WHERE name = '38.5')
    );

    INSERT INTO std_size_mapping (
        size_scheme_id,
        size_id,
        classification_id,
        product_type_id,
        std_size_id
    ) VALUES
    (
        (SELECT id FROM size_scheme WHERE name = 'Shoes - Italian'),
        (SELECT id FROM size WHERE size = '39'),
        (SELECT id FROM classification WHERE classification = 'Shoes'),
        NULL,
        (SELECT id FROM std_size WHERE name = '39')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'Shoes - UK'),
        (SELECT id FROM size WHERE size = '6'),
        (SELECT id FROM classification WHERE classification = 'Shoes'),
        NULL,
        (SELECT id FROM std_size WHERE name = '39')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'Shoes - US'),
        (SELECT id FROM size WHERE size = '9'),
        (SELECT id FROM classification WHERE classification = 'Shoes'),
        NULL,
        (SELECT id FROM std_size WHERE name = '39')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'Shoes - France'),
        (SELECT id FROM size WHERE size = '40'),
        (SELECT id FROM classification WHERE classification = 'Shoes'),
        NULL,
        (SELECT id FROM std_size WHERE name = '39')
    );

    INSERT INTO std_size_mapping (
        size_scheme_id,
        size_id,
        classification_id,
        product_type_id,
        std_size_id
    ) VALUES
    (
        (SELECT id FROM size_scheme WHERE name = 'Shoes - Italian'),
        (SELECT id FROM size WHERE size = '39.5'),
        (SELECT id FROM classification WHERE classification = 'Shoes'),
        NULL,
        (SELECT id FROM std_size WHERE name = '39.5')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'Shoes - UK'),
        (SELECT id FROM size WHERE size = '6.5'),
        (SELECT id FROM classification WHERE classification = 'Shoes'),
        NULL,
        (SELECT id FROM std_size WHERE name = '39.5')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'Shoes - US'),
        (SELECT id FROM size WHERE size = '9.5'),
        (SELECT id FROM classification WHERE classification = 'Shoes'),
        NULL,
        (SELECT id FROM std_size WHERE name = '39.5')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'Shoes - France'),
        (SELECT id FROM size WHERE size = '40.5'),
        (SELECT id FROM classification WHERE classification = 'Shoes'),
        NULL,
        (SELECT id FROM std_size WHERE name = '39.5')
    );

    INSERT INTO std_size_mapping (
        size_scheme_id,
        size_id,
        classification_id,
        product_type_id,
        std_size_id
    ) VALUES
    (
        (SELECT id FROM size_scheme WHERE name = 'Shoes - Italian'),
        (SELECT id FROM size WHERE size = '40'),
        (SELECT id FROM classification WHERE classification = 'Shoes'),
        NULL,
        (SELECT id FROM std_size WHERE name = '40')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'Shoes - UK'),
        (SELECT id FROM size WHERE size = '7'),
        (SELECT id FROM classification WHERE classification = 'Shoes'),
        NULL,
        (SELECT id FROM std_size WHERE name = '40')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'Shoes - US'),
        (SELECT id FROM size WHERE size = '10'),
        (SELECT id FROM classification WHERE classification = 'Shoes'),
        NULL,
        (SELECT id FROM std_size WHERE name = '40')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'Shoes - France'),
        (SELECT id FROM size WHERE size = '41'),
        (SELECT id FROM classification WHERE classification = 'Shoes'),
        NULL,
        (SELECT id FROM std_size WHERE name = '40')
    );

    INSERT INTO std_size_mapping (
        size_scheme_id,
        size_id,
        classification_id,
        product_type_id,
        std_size_id
    ) VALUES
    (
        (SELECT id FROM size_scheme WHERE name = 'Shoes - Italian'),
        (SELECT id FROM size WHERE size = '40.5'),
        (SELECT id FROM classification WHERE classification = 'Shoes'),
        NULL,
        (SELECT id FROM std_size WHERE name = '40.5')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'Shoes - UK'),
        (SELECT id FROM size WHERE size = '7.5'),
        (SELECT id FROM classification WHERE classification = 'Shoes'),
        NULL,
        (SELECT id FROM std_size WHERE name = '40.5')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'Shoes - US'),
        (SELECT id FROM size WHERE size = '10.5'),
        (SELECT id FROM classification WHERE classification = 'Shoes'),
        NULL,
        (SELECT id FROM std_size WHERE name = '40.5')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'Shoes - France'),
        (SELECT id FROM size WHERE size = '41.5'),
        (SELECT id FROM classification WHERE classification = 'Shoes'),
        NULL,
        (SELECT id FROM std_size WHERE name = '40.5')
    );

    INSERT INTO std_size_mapping (
        size_scheme_id,
        size_id,
        classification_id,
        product_type_id,
        std_size_id
    ) VALUES
    (
        (SELECT id FROM size_scheme WHERE name = 'Shoes - Italian'),
        (SELECT id FROM size WHERE size = '41'),
        (SELECT id FROM classification WHERE classification = 'Shoes'),
        NULL,
        (SELECT id FROM std_size WHERE name = '41')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'Shoes - UK'),
        (SELECT id FROM size WHERE size = '8'),
        (SELECT id FROM classification WHERE classification = 'Shoes'),
        NULL,
        (SELECT id FROM std_size WHERE name = '41')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'Shoes - US'),
        (SELECT id FROM size WHERE size = '11'),
        (SELECT id FROM classification WHERE classification = 'Shoes'),
        NULL,
        (SELECT id FROM std_size WHERE name = '41')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'Shoes - France'),
        (SELECT id FROM size WHERE size = '42'),
        (SELECT id FROM classification WHERE classification = 'Shoes'),
        NULL,
        (SELECT id FROM std_size WHERE name = '41')
    );

    INSERT INTO std_size_mapping (
        size_scheme_id,
        size_id,
        classification_id,
        product_type_id,
        std_size_id
    ) VALUES
    (
        (SELECT id FROM size_scheme WHERE name = 'Shoes - Italian'),
        (SELECT id FROM size WHERE size = '41.5'),
        (SELECT id FROM classification WHERE classification = 'Shoes'),
        NULL,
        (SELECT id FROM std_size WHERE name = '41.5')
    );

    INSERT INTO std_size_mapping (
        size_scheme_id,
        size_id,
        classification_id,
        product_type_id,
        std_size_id
    ) VALUES
    (
        (SELECT id FROM size_scheme WHERE name = 'Shoes - Italian'),
        (SELECT id FROM size WHERE size = '42'),
        (SELECT id FROM classification WHERE classification = 'Shoes'),
        NULL,
        (SELECT id FROM std_size WHERE name = '42')
    );

    INSERT INTO std_size_mapping (
        size_scheme_id,
        size_id,
        classification_id,
        product_type_id,
        std_size_id
    ) VALUES
    (
        (SELECT id FROM size_scheme WHERE name = 'Jeans'),
        (SELECT id FROM size WHERE size = '24'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'XS')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'Jeans'),
        (SELECT id FROM size WHERE size = '25'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'XS')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'Jeans'),
        (SELECT id FROM size WHERE size = '26'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'XS')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'Jeans'),
        (SELECT id FROM size WHERE size = '27'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'S')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'Jeans'),
        (SELECT id FROM size WHERE size = '28'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'S')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'Jeans'),
        (SELECT id FROM size WHERE size = '29'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'M')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'Jeans'),
        (SELECT id FROM size WHERE size = '30'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'M')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'Jeans'),
        (SELECT id FROM size WHERE size = '31'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'L')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'Jeans'),
        (SELECT id FROM size WHERE size = '32'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'L')
    );

    INSERT INTO std_size_mapping (
        size_scheme_id,
        size_id,
        classification_id,
        product_type_id,
        std_size_id
    ) VALUES
    (
        (SELECT id FROM size_scheme WHERE name = 'RTW XS - XL'),
        (SELECT id FROM size WHERE size = 'x small'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'XS')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'RTW XS - XL'),
        (SELECT id FROM size WHERE size = 'small'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'S')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'RTW XS - XL'),
        (SELECT id FROM size WHERE size = 'medium'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'M')
    ),
    (
        (SELECT id FROM size_scheme WHERE name = 'RTW XS - XL'),
        (SELECT id FROM size WHERE size = 'large'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'L')
    );

COMMIT;
