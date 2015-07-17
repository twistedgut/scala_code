BEGIN;
    -- Update shipment_status to 'Cancelled'
    UPDATE shipment
        SET shipment_status_id=(
            SELECT id FROM shipment_status WHERE status='Cancelled'
        )
        WHERE id in (2360295, 2448891, 2451038, 2451063, 2514119, 2338252, 2338313, 2338314, 
                     2339199, 2339794, 2339795, 2340940, 2350709, 2355401, 2391123, 2423759, 
                     2450742, 2454959, 2457148, 2461019, 2487934, 2518303, 2611508, 2768744, 
                     2774137, 2789622, 2347767, 2355904, 2399180, 2401291, 2403007, 2439925, 
                     2624431, 2636459, 2692305, 2867444)
    ;
    -- Update the logs
    INSERT INTO shipment_status_log (shipment_id, shipment_status_id, operator_id) VALUES
		(2360295, (SELECT id FROM shipment_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(2448891, (SELECT id FROM shipment_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(2451038, (SELECT id FROM shipment_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(2451063, (SELECT id FROM shipment_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(2514119, (SELECT id FROM shipment_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(2338252, (SELECT id FROM shipment_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(2338313, (SELECT id FROM shipment_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(2338314, (SELECT id FROM shipment_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(2339199, (SELECT id FROM shipment_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(2339794, (SELECT id FROM shipment_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(2339795, (SELECT id FROM shipment_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(2340940, (SELECT id FROM shipment_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(2350709, (SELECT id FROM shipment_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(2355401, (SELECT id FROM shipment_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(2391123, (SELECT id FROM shipment_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(2423759, (SELECT id FROM shipment_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(2450742, (SELECT id FROM shipment_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(2454959, (SELECT id FROM shipment_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(2457148, (SELECT id FROM shipment_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(2461019, (SELECT id FROM shipment_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(2487934, (SELECT id FROM shipment_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(2518303, (SELECT id FROM shipment_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(2611508, (SELECT id FROM shipment_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(2768744, (SELECT id FROM shipment_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(2774137, (SELECT id FROM shipment_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(2789622, (SELECT id FROM shipment_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(2347767, (SELECT id FROM shipment_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(2355904, (SELECT id FROM shipment_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(2399180, (SELECT id FROM shipment_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(2401291, (SELECT id FROM shipment_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(2403007, (SELECT id FROM shipment_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(2439925, (SELECT id FROM shipment_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(2624431, (SELECT id FROM shipment_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(2636459, (SELECT id FROM shipment_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(2692305, (SELECT id FROM shipment_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(2867444, (SELECT id FROM shipment_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application'))
    ;
    -- Update shipment_item_status to 'Cancelled'
    UPDATE shipment_item
        SET shipment_item_status_id=(
            SELECT id FROM shipment_item_status WHERE status='Cancelled'
        )
        WHERE shipment_id in (2360295, 2448891, 2451038, 2451063, 2514119, 2338252, 2338313, 2338314, 
                              2339199, 2339794, 2339795, 2340940, 2350709, 2355401, 2391123, 2423759, 
                              2450742, 2454959, 2457148, 2461019, 2487934, 2518303, 2611508, 2768744, 
                              2774137, 2789622, 2347767, 2355904, 2399180, 2401291, 2403007, 2439925, 
                              2624431, 2636459, 2692305, 2867444)
    ;
    -- Update the logs, possibly multiple copies
    INSERT INTO shipment_item_status_log (shipment_item_id, shipment_item_status_id, operator_id) VALUES
		(4946106, (SELECT id FROM shipment_item_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(4948776, (SELECT id FROM shipment_item_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(5160583, (SELECT id FROM shipment_item_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(4963862, (SELECT id FROM shipment_item_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(5161115, (SELECT id FROM shipment_item_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(4978628, (SELECT id FROM shipment_item_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(4979513, (SELECT id FROM shipment_item_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(5109292, (SELECT id FROM shipment_item_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(5069865, (SELECT id FROM shipment_item_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(5789684, (SELECT id FROM shipment_item_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(5982783, (SELECT id FROM shipment_item_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(5533312, (SELECT id FROM shipment_item_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(4946030, (SELECT id FROM shipment_item_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(4946107, (SELECT id FROM shipment_item_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(4947758, (SELECT id FROM shipment_item_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(5140033, (SELECT id FROM shipment_item_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(4948777, (SELECT id FROM shipment_item_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(4950848, (SELECT id FROM shipment_item_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(5168052, (SELECT id FROM shipment_item_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(5157173, (SELECT id FROM shipment_item_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(5062960, (SELECT id FROM shipment_item_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(5046834, (SELECT id FROM shipment_item_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(4969376, (SELECT id FROM shipment_item_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(5161090, (SELECT id FROM shipment_item_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(4987782, (SELECT id FROM shipment_item_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(5066846, (SELECT id FROM shipment_item_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(5172227, (SELECT id FROM shipment_item_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(5179269, (SELECT id FROM shipment_item_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(5288617, (SELECT id FROM shipment_item_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(5280346, (SELECT id FROM shipment_item_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(5230709, (SELECT id FROM shipment_item_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(5485022, (SELECT id FROM shipment_item_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(5509779, (SELECT id FROM shipment_item_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(5642002, (SELECT id FROM shipment_item_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(5829740, (SELECT id FROM shipment_item_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application')),
		(5800076, (SELECT id FROM shipment_item_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application'))
    ;

COMMIT;
