BEGIN WORK;

INSERT INTO event.website(id, name) VALUES (9, 'APAC'), (10, 'OUT-APAC');

INSERT INTO event.shipping_option(id, name) VALUES (7, 'APAC Standard');

COMMIT WORK;
