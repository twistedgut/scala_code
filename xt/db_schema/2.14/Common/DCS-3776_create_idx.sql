BEGIN WORK;

CREATE INDEX idx_public_product_channel__channel_id ON public.product_channel(channel_id);
CREATE INDEX idx_public_product__designer_id ON public.product(designer_id);
CREATE INDEX idx_public_reservation__variant_id ON public.reservation(variant_id);
CREATE INDEX idx_public_reservation__customer_id ON public.reservation(customer_id);
CREATE INDEX idx_public_reservation__channel_id ON public.reservation(channel_id);
CREATE INDEX idx_public_reservation__status_id ON public.reservation(status_id);

COMMIT WORK;
