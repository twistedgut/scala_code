-- Update current box table with correct weights/dimensions

BEGIN WORK;

-- NAP Boxes --
-- Box - Size 1
UPDATE box
	SET	weight	= 1,
		length	= 9.56,
		width	= 7.62,
		height	= 4.00
WHERE	box = 'Box - Size 1'
AND		active = true
AND		channel_id IN (SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'NAP')
;
-- Box - Size 2
UPDATE box
	SET	weight	= 2,
		length	= 13.87,
		width	= 10.87,
		height	= 5.5
WHERE	box = 'Box - Size 2'
AND		active = true
AND		channel_id IN (SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'NAP')
;
-- Box - Size 3
UPDATE box
	SET	weight	= 3,
		length	= 16.37,
		width	= 13.12,
		height	= 6.62
WHERE	box = 'Box - Size 3'
AND		active = true
AND		channel_id IN (SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'NAP')
;
-- Box - Size 4
UPDATE box
	SET	weight	= 4,
		length	= 21.37,
		width	= 13.81,
		height	= 9.87
WHERE	box = 'Box - Size 4'
AND		active = true
AND		channel_id IN (SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'NAP')
;
-- Box - Size 5
UPDATE box
	SET	weight	= 6,
		length	= 26.75,
		width	= 20.5,
		height	= 10.31
WHERE	box = 'Box - Size 5'
AND		active = true
AND		channel_id IN (SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'NAP')
;
-- Shoe Box
UPDATE box
	SET	weight	= 1,
		length	= 13.18,
		width	= 8.62,
		height	= 5.8
WHERE	box = 'SHOE BOX'
AND		active = true
AND		channel_id IN (SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'NAP')
;
-- Boot Box
UPDATE box
	SET	weight	= 1,
		length	= 23.25,
		width	= 14.5,
		height	= 6.0
WHERE	box = 'BOOT BOX'
AND		active = true
AND		channel_id IN (SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'NAP')
;

-- OUTNET Boxes --
-- Box - Size 1
UPDATE box
	SET	weight	= 1,
		length	= 9.56,
		width	= 7.62,
		height	= 4.00
WHERE	box = 'Box - Size 1'
AND		active = true
AND		channel_id IN (SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'OUTNET')
;
-- Box - Size 2
UPDATE box
	SET	weight	= 2,
		length	= 13.87,
		width	= 10.87,
		height	= 5.5
WHERE	box = 'Box - Size 2'
AND		active = true
AND		channel_id IN (SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'OUTNET')
;
-- Box - Size 3
UPDATE box
	SET	weight	= 3,
		length	= 16.37,
		width	= 13.12,
		height	= 6.62
WHERE	box = 'Box - Size 3'
AND		active = true
AND		channel_id IN (SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'OUTNET')
;
-- Box - Size 4
UPDATE box
	SET	weight	= 4,
		length	= 21.37,
		width	= 13.81,
		height	= 9.87
WHERE	box = 'Box - Size 4'
AND		active = true
AND		channel_id IN (SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'OUTNET')
;
-- Box - Size 5
UPDATE box
	SET	weight	= 6,
		length	= 26.75,
		width	= 20.5,
		height	= 10.31
WHERE	box = 'Box - Size 5'
AND		active = true
AND		channel_id IN (SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'OUTNET')
;
-- Shoe Box
UPDATE box
	SET	weight	= 1,
		length	= 13.18,
		width	= 8.62,
		height	= 5.8
WHERE	box = 'SHOE BOX'
AND		active = true
AND		channel_id IN (SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'OUTNET')
;
-- Boot Box
UPDATE box
	SET	weight	= 1,
		length	= 23.25,
		width	= 14.5,
		height	= 6.0
WHERE	box = 'BOOT BOX'
AND		active = true
AND		channel_id IN (SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'OUTNET')
;
-- Medium Box
UPDATE box
	SET	weight	= 1,
		length	= 17.75,
		width	= 14.75,
		height	= 4.13
WHERE	box = 'OUTNET - Medium Box'
AND		active = true
AND		channel_id IN (SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'OUTNET')
;
COMMIT WORK;
