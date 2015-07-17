BEGIN;

--
-- Data for Name: coupon_restriction_group; Type: TABLE DATA; Schema: promotion; Owner: www
--

INSERT INTO coupon_restriction_group (id, name, idx) VALUES (1, 'Item Limit', 10);
INSERT INTO coupon_restriction_group (id, name, idx) VALUES (2, 'Order Limit', 20);


INSERT INTO coupon_restriction (id, idx, description, group_id, usage_limit) VALUES (1, 10, 'limited to 1 item', 1, 1);
INSERT INTO coupon_restriction (id, idx, description, group_id, usage_limit) VALUES (2, 20, 'limited to 2 items', 1, 2);
INSERT INTO coupon_restriction (id, idx, description, group_id, usage_limit) VALUES (3, 30, 'limited to 3 items', 1, 3);
INSERT INTO coupon_restriction (id, idx, description, group_id, usage_limit) VALUES (4, 40, 'limited to 4 items', 1, 4);
INSERT INTO coupon_restriction (id, idx, description, group_id, usage_limit) VALUES (5, 50, 'limited to 5 items', 1, 5);
INSERT INTO coupon_restriction (id, idx, description, group_id, usage_limit) VALUES (6, 60, 'unlimited items', 1, NULL);
INSERT INTO coupon_restriction (id, idx, description, group_id, usage_limit) VALUES (7, 70, 'limited to 1 order', 2, 1);
INSERT INTO coupon_restriction (id, idx, description, group_id, usage_limit) VALUES (8, 80, 'limited to 2 orders', 2, 2);
INSERT INTO coupon_restriction (id, idx, description, group_id, usage_limit) VALUES (9, 90, 'limited to 3 orders', 2, 3);
INSERT INTO coupon_restriction (id, idx, description, group_id, usage_limit) VALUES (10, 100, 'limited to 4 orders', 2, 4);
INSERT INTO coupon_restriction (id, idx, description, group_id, usage_limit) VALUES (11, 110, 'limited to 5 orders', 2, 5);
INSERT INTO coupon_restriction (id, idx, description, group_id, usage_limit) VALUES (12, 120, 'unlimited orders', 2, NULL);



--
-- Data for Name: coupon_target; Type: TABLE DATA; Schema: promotion; Owner: www
--

INSERT INTO coupon_target (id, description) VALUES (1, 'Customer Specific');
INSERT INTO coupon_target (id, description) VALUES (2, 'Generic');


--
-- Data for Name: price_group; Type: TABLE DATA; Schema: promotion; Owner: www
--

INSERT INTO price_group (id, description) VALUES (1, 'All (Full Price & Markdown)');
INSERT INTO price_group (id, description) VALUES (2, 'Full Price');
INSERT INTO price_group (id, description) VALUES (3, 'Markdown');


--
-- Data for Name: shipping_option; Type: TABLE DATA; Schema: promotion; Owner: www
--

INSERT INTO shipping_option (id, name) VALUES (1, 'London Premier');
INSERT INTO shipping_option (id, name) VALUES (2, 'New York Same Day');
INSERT INTO shipping_option (id, name) VALUES (3, 'Next Business Day');
INSERT INTO shipping_option (id, name) VALUES (4, 'Ground');



--
-- Data for Name: target_city; Type: TABLE DATA; Schema: promotion; Owner: www
--
-- some entries to get things moving, first few should appear at the top
INSERT INTO target_city (id, name, timezone, display_order) VALUES ( 1,    'GMT (London)',                             'Europe/London',            1);
INSERT INTO target_city (id, name, timezone, display_order) VALUES ( 2,    'GMT-5 (New York)',                         'America/New_York',         2);
INSERT INTO target_city (id, name, timezone, display_order) VALUES ( 3,    'GMT-8 (Los Angeles)',                      'America/Los_Angeles',      3);
-- everything else
-- GMT+X
INSERT INTO target_city (id, name, timezone, display_order) VALUES ( 4,    'GMT+1 (Paris, Rome, Berlin)',              'Europe/Paris',         105);
INSERT INTO target_city (id, name, timezone, display_order) VALUES ( 5,    'GMT+2 (Athens, Helsinki, Jerusalem)',      'Europe/Athens',        110);
INSERT INTO target_city (id, name, timezone, display_order) VALUES ( 6,    'GMT+3 (Kuwait, Moscow, Riyadh)',           'Asia/Kuwait',          115);
INSERT INTO target_city (id, name, timezone, display_order) VALUES ( 7,    'GMT+4 (Abu Dhabi, Tblisi, Kabul)',         'Asia/Tbilisi',         120);
INSERT INTO target_city (id, name, timezone, display_order) VALUES ( 8,    'GMT+5 (Tashkent)',                         'Asia/Tashkent',        125);
-- this one needs double checking;
-- Delhi's zone was deduced from: http://bugs.php.net/bug.php?id=22418
-- http://www.davidsemporium.co.uk/worldclock2.html makes us think it's
-- incorrect
INSERT INTO target_city (id, name, timezone, display_order) VALUES ( 9,    'GMT+5:30 (Delhi)',                         'Asia/Katmandu',        130);
INSERT INTO target_city (id, name, timezone, display_order) VALUES (10,    'GMT+6 (Colombo)',                          'Asia/Colombo',         135);
INSERT INTO target_city (id, name, timezone, display_order) VALUES (11,
    'GMT+7 (Bangkok, Jakarta)',                 'Asia/Bangkok',         140);
INSERT INTO target_city (id, name, timezone, display_order) VALUES (12,    'GMT+8 (Singapore, Hong Kong, Beijing)',    'Asia/Singapore',       145);
INSERT INTO target_city (id, name, timezone, display_order) VALUES (13,    'GMT+9 (Tokyo)',                            'Asia/Tokyo',           150);
INSERT INTO target_city (id, name, timezone, display_order) VALUES (14,    'GMT+10 (Sydney)',                          'Australia/Sydney',     155);
INSERT INTO target_city (id, name, timezone, display_order) VALUES (15,    'GMT+11 (New Caledonia, Magadan)',          'Asia/Magadan',         160);
INSERT INTO target_city (id, name, timezone, display_order) VALUES (16,    'GMT+12 (Wellington, Fiji)',                'Pacific/Fiji',         165);
-- GMT-X
INSERT INTO target_city (id, name, timezone, display_order) VALUES (17,    'GMT-1 (Azores, Cape Verde Islands)',       'Atlantic/Azores',      205);
INSERT INTO target_city (id, name, timezone, display_order) VALUES (18,    'GMT-2 (Mid-Atlantic)',                     '-0200',                210);
INSERT INTO target_city (id, name, timezone, display_order) VALUES (19,    'GMT-3 (Brasilia, Buenos Aires)', 'Argentina/Buenos_Aires',         215);
INSERT INTO target_city (id, name, timezone, display_order) VALUES (20,    'GMT-4 (Caracas, La Paz, Santiago)',        'America/Santiago',     220);
INSERT INTO target_city (id, name, timezone, display_order) VALUES (21,    'GMT-6 (Mexico City, Chicago)',             'America/Chicago',      225);
INSERT INTO target_city (id, name, timezone, display_order) VALUES (22,    'GMT-7 (Denver)',                           'America/Denver',       230);
INSERT INTO target_city (id, name, timezone, display_order) VALUES (23,    'GMT-9 (Juneau, Alaska)',                   'America/Juneau',       235);
INSERT INTO target_city (id, name, timezone, display_order) VALUES (24,    'GMT-10 (Honolulu, Hawaii)',                'Pacific/Honolulu',     240);
INSERT INTO target_city (id, name, timezone, display_order) VALUES (25,    'GMT-11 (Midway Island)',                   'Pacific/Midway',       245);


--
-- Data for Name: website; Type: TABLE DATA; Schema: promotion; Owner: www
--

INSERT INTO website (id, name) VALUES (1, 'Intl');
INSERT INTO website (id, name) VALUES (2, 'AM');

COMMIT;
