-- TP-786 : Slow Running : /Finance/ActiveInvoices/ProcessInvoices

BEGIN WORK;
    
CREATE INDEX link_return_renumeration__return_id_idx ON public.link_return_renumeration(return_id)
;   
    
COMMIT WORK;

