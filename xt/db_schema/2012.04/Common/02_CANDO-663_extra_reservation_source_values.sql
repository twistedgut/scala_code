-- CANDO-663: Extra 'reservation_source' values

BEGIN WORK;

-- Populate the 'reservation_source' table
INSERT
  INTO reservation_source (
     source,
     sort_order
  )
VALUES
    ('Email',          13),
    ('Appointment',    14),
    ('Charge and Send',15)
;

COMMIT WORK;
