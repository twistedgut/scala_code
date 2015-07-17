-- HKDC-390: Fraud Hotlist 'field' drop-down has no entries.

BEGIN WORK;

INSERT INTO hotlist_type
( type )
VALUES
( 'Address'  ),
( 'Customer' ),
( 'Payment'  );

INSERT INTO hotlist_field
( hotlist_type_id, field )
VALUES
( ( SELECT id FROM hotlist_type WHERE type = 'Address'  ), 'Street Address'   ),
( ( SELECT id FROM hotlist_type WHERE type = 'Address'  ), 'Town/City'        ),
( ( SELECT id FROM hotlist_type WHERE type = 'Address'  ), 'County/State'     ),
( ( SELECT id FROM hotlist_type WHERE type = 'Address'  ), 'Postcode/Zipcode' ),
( ( SELECT id FROM hotlist_type WHERE type = 'Address'  ), 'Country'          ),
( ( SELECT id FROM hotlist_type WHERE type = 'Customer' ), 'Email'            ),
( ( SELECT id FROM hotlist_type WHERE type = 'Customer' ), 'Telephone'        ),
( ( SELECT id FROM hotlist_type WHERE type = 'Payment'  ), 'Card Number'      );

COMMIT;

