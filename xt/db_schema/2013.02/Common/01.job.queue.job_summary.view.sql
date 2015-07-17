\c job_queue
BEGIN;
    CREATE OR REPLACE VIEW job_summary AS select j.grabbed_until,map.funcid, priority, funcname, count(*) from job j JOIN funcmap map ON j.funcid = map.funcid group by map.funcid,j.priority,funcname,j.grabbed_until order by j.grabbed_until desc, count(*) desc;
    ALTER TABLE public.job_summary OWNER TO www;
COMMIT;
