
--CANDO-8601: Add 'Special Order' Reservation source underneath
--            'Appointment'



BEGIN WORK;

UPDATE reservation_source
    SET is_active  = TRUE,
        sort_order = (
            SELECT ( sort_order + 1 ) FROM reservation_source WHERE source='Appointment'
        )
WHERE source ='Special Order'
;



COMMIT WORK;
