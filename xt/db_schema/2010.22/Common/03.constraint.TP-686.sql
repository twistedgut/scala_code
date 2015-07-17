
-- TP-686
BEGIN WORK;
ALTER TABLE ONLY public.variant
    ADD CONSTRAINT variant_designer_size_id_fkey
    	FOREIGN KEY (designer_size_id)
    	REFERENCES public.size(id) DEFERRABLE;
COMMIT WORK;