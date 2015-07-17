BEGIN;

    UPDATE shipping_option SET name='London Premier' WHERE id=1;
    UPDATE shipping_option SET name='UK Standard' WHERE id=2;
    UPDATE shipping_option SET name='US Next Business Day' WHERE id=3;
    UPDATE shipping_option SET name='US Ground' WHERE id=4;

    INSERT INTO shipping_option (id, name) VALUES (5, 'New York Premier');

COMMIT;
