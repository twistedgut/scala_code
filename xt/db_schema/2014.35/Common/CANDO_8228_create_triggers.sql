-- CANDO-8228: Add a trigger to various tables to update the last_updated column.

/*
    We use the function 'last_updated_func' already defined here, as it does
    exactly what we want:

        db_schema/2012.05/Common/WHM-811_last_updated_cols.sql

    Here it is for reference:

        CREATE OR REPLACE FUNCTION last_updated_func() RETURNS TRIGGER AS $$
            BEGIN
                NEW.last_updated := clock_timestamp();
                RETURN NEW;
            END;
        $$
        LANGUAGE 'plpgsql';
*/

BEGIN WORK;

    CREATE TRIGGER public_link_shipment__promotion_last_updated_tr BEFORE UPDATE ON public.link_shipment__promotion
        FOR EACH ROW EXECUTE PROCEDURE last_updated_func();

    CREATE TRIGGER public_link_shipment_item__price_adjustment_last_updated_tr BEFORE UPDATE ON public.link_shipment_item__price_adjustment
        FOR EACH ROW EXECUTE PROCEDURE last_updated_func();

    CREATE TRIGGER public_link_shipment_item__promotion_last_updated_tr BEFORE UPDATE ON public.link_shipment_item__promotion
        FOR EACH ROW EXECUTE PROCEDURE last_updated_func();

    CREATE TRIGGER public_link_shipment_item__reservation_last_updated_tr BEFORE UPDATE ON public.link_shipment_item__reservation
        FOR EACH ROW EXECUTE PROCEDURE last_updated_func();

    CREATE TRIGGER orders_payment_last_updated_tr BEFORE UPDATE ON orders.payment
        FOR EACH ROW EXECUTE PROCEDURE last_updated_func();

    CREATE TRIGGER orders_tender_last_updated_tr BEFORE UPDATE ON orders.tender
        FOR EACH ROW EXECUTE PROCEDURE last_updated_func();

    CREATE TRIGGER public_pre_order_last_updated_tr BEFORE UPDATE ON public.pre_order
        FOR EACH ROW EXECUTE PROCEDURE last_updated_func();

    CREATE TRIGGER public_pre_order_item_last_updated_tr BEFORE UPDATE ON public.pre_order_item
        FOR EACH ROW EXECUTE PROCEDURE last_updated_func();

    CREATE TRIGGER public_renumeration_last_updated_tr BEFORE UPDATE ON public.renumeration
        FOR EACH ROW EXECUTE PROCEDURE last_updated_func();

    CREATE TRIGGER public_renumeration_item_last_updated_tr BEFORE UPDATE ON public.renumeration_item
        FOR EACH ROW EXECUTE PROCEDURE last_updated_func();

    CREATE TRIGGER public_reservation_last_updated_tr BEFORE UPDATE ON public.reservation
        FOR EACH ROW EXECUTE PROCEDURE last_updated_func();

COMMIT;

