BEGIN;

  -- http://confluence.net-a-porter.com/display/BA/RMA+Automation#RMAAutomation-2.9CreateReturn
  -- 14 days for DC1
  UPDATE return
    SET expiry_date = creation_date+'14 day'::interval,
        cancellation_date = creation_date+'14 day'::interval
    WHERE creation_date IS NOT NULL;

COMMIT;
