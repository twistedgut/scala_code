BEGIN;


-- premier
UPDATE public.shipping_account SET return_cutoff_days = 7
    WHERE id IN ( 0 );

-- domestic ground
UPDATE public.shipping_account SET return_cutoff_days = 12
    WHERE id IN ( 6 );

-- domestic express
UPDATE public.shipping_account SET return_cutoff_days = 10
    WHERE id IN ( 1,4 );

-- international
UPDATE public.shipping_account SET return_cutoff_days = 12
    WHERE id IN ( 2,5 );



UPDATE public.carrier SET tracking_uri = 'http://wwwapps.ups.com/WebTracking/processInputRequest?TypeOfInquiryNumber=T&AgreeToTermsAndConditions=yes&TypeOfInquiryNumberT&InquiryNumber1=<TOKEN>'
    WHERE id IN ( 2 );

UPDATE public.carrier SET tracking_uri = 'http://track.dhl-usa.com/TrackByNbr.asp?type=fasttrack&ShipmentNumber=<TOKEN>'
    WHERE id IN (1 );

COMMIT;
