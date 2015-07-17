-- cat patch-promotion_target_cities.MySQL.sql |mysql ice_netaporter_intl
-- cat patch-promotion_target_cities.MySQL.sql |mysql ice_netaporter_am
BEGIN;

    -- make sure (id=1) is correct
    UPDATE  target_city
    SET     name='GMT (London)'
    WHERE   id=1;

    -- then set the target timezone for *everything* to London
    UPDATE  detail
    SET     target_city_id=1;

    -- now destroy everything else we already have in the target city table
    DELETE  FROM target_city
    WHERE   id != 1;


    -- other items that the spoec says need to be at the top of the list
    INSERT INTO target_city (id, name, timezone, display_order)
    VALUES
    ( 2,    'GMT-5 (New York)',                         'America/New_York',         2);
    INSERT INTO target_city (id, name, timezone, display_order)
    VALUES
    ( 3,    'GMT-8 (Los Angeles)',                      'America/Los_Angeles',      3);

    -- everything else

    -- GMT+X
    INSERT INTO target_city (id, name, timezone, display_order)
    VALUES
    ( 4,    'GMT+1 (Paris, Rome, Berlin)',              'Europe/Paris',         105);
    INSERT INTO target_city (id, name, timezone, display_order)
    VALUES
    ( 5,    'GMT+2 (Athens, Helsinki, Jerusalem)',      'Europe/Athens',        110);
    INSERT INTO target_city (id, name, timezone, display_order)
    VALUES
    ( 6,    'GMT+3 (Kuwait, Moscow, Riyadh)',           'Asia/Kuwait',          115);
    INSERT INTO target_city (id, name, timezone, display_order)
    VALUES
    ( 7,    'GMT+4 (Abu Dhabi, Tblisi, Kabul)',         'Asia/Tbilisi',         120);
    INSERT INTO target_city (id, name, timezone, display_order)
    VALUES
    ( 8,    'GMT+5 (Tashkent)',                         'Asia/Tashkent',        125);
    -- this one needs double checking;
    -- Delhi's zone was deduced from: http://bugs.php.net/bug.php?id=22418
    -- http://www.davidsemporium.co.uk/worldclock2.html makes us think it's
    -- incorrect
    INSERT INTO target_city (id, name, timezone, display_order)
    VALUES
    ( 9,    'GMT+5:30 (Delhi)',                         'Asia/Katmandu',        130);
    INSERT INTO target_city (id, name, timezone, display_order)
    VALUES
    (10,    'GMT+6 (Colombo)',                          'Asia/Colombo',         135);
    INSERT INTO target_city (id, name, timezone, display_order)
    VALUES
    (11,    'GMT+7 (Bangkok, Jakarta)',                 'Asia/Bangkok',         140);
    INSERT INTO target_city (id, name, timezone, display_order)
    VALUES
    (12,    'GMT+8 (Singapore, Hong Kong, Beijing)',    'Asia/Singapore',       145);
    INSERT INTO target_city (id, name, timezone, display_order)
    VALUES
    (13,    'GMT+9 (Tokyo)',                            'Asia/Tokyo',           150);
    INSERT INTO target_city (id, name, timezone, display_order)
    VALUES
    (14,    'GMT+10 (Sydney)',                          'Australia/Sydney',     155);
    INSERT INTO target_city (id, name, timezone, display_order)
    VALUES
    (15,    'GMT+11 (New Caledonia, Magadan)',          'Asia/Magadan',         160);
    INSERT INTO target_city (id, name, timezone, display_order)
    VALUES
    (16,    'GMT+12 (Wellington, Fiji)',                'Pacific/Fiji',         165);


    -- GMT-X
    INSERT INTO target_city (id, name, timezone, display_order)
    VALUES
    (17,    'GMT-1 (Azores, Cape Verde Islands)',       'Atlantic/Azores',      205);
    INSERT INTO target_city (id, name, timezone, display_order)
    VALUES
    (18,    'GMT-2 (Mid-Atlantic)',                     '-0200',                210);
    INSERT INTO target_city (id, name, timezone, display_order)
    VALUES
    (19,    'GMT-3 (Brasilia, Buenos Aires)', 'Argentina/Buenos_Aires',         215);
    INSERT INTO target_city (id, name, timezone, display_order)
    VALUES
    (20,    'GMT-4 (Caracas, La Paz, Santiago)',        'America/Santiago',     220);
    INSERT INTO target_city (id, name, timezone, display_order)
    VALUES
    (21,    'GMT-6 (Mexico City, Chicago)',             'America/Chicago',      225);
    INSERT INTO target_city (id, name, timezone, display_order)
    VALUES
    (22,    'GMT-7 (Denver)',                           'America/Denver',       230);
    INSERT INTO target_city (id, name, timezone, display_order)
    VALUES
    (23,    'GMT-9 (Juneau, Alaska)',                   'America/Juneau',       235);
    INSERT INTO target_city (id, name, timezone, display_order)
    VALUES
    (24,    'GMT-10 (Honolulu, Hawaii)',                'Pacific/Honolulu',     240);
    INSERT INTO target_city (id, name, timezone, display_order)
    VALUES
    (25,    'GMT-11 (Midway Island)',                   'Pacific/Midway',       245);
COMMIT;
