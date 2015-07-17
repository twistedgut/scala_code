BEGIN;

  CREATE INDEX return_status_log_return_id ON return_status_log (return_id);
  UPDATE return me 
     SET creation_date = l.date 
    FROM return_status_log l,
         return_status s
   WHERE me.creation_date IS NULL
     AND l.return_id = me.id
     AND l.return_status_id = s.id
     AND s.status = 'Awaiting Return';

COMMIT;
