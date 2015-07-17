BEGIN;

  -- http://confluence.net-a-porter.com/display/BA/RMA+Automation#RMAAutomation-2.9CreateReturn
  -- 7 days for DC2
  UPDATE return
    SET expiry_date = creation_date+'7 day'::interval,
        cancellation_date = creation_date+'7 day'::interval
    WHERE creation_date IS NOT NULL;

COMMIT;
