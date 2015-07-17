BEGIN;

--SEASON CR13

-- HK CONVERSIONS
-- insert conversion rate for HKD to HKD
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'HKD'),(SELECT id FROM public.currency WHERE currency = 'HKD'),1
    );

-- insert conversion rate for HKD to JPY
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'HKD'),(SELECT id FROM public.currency WHERE currency = 'JPY'),10.417
    );

-- insert conversion rate for HKD to CNY
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'HKD'),(SELECT id FROM public.currency WHERE currency = 'CNY'),0.833
    );

-- insert conversion rate for HKD to KRW
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'HKD'),(SELECT id FROM public.currency WHERE currency = 'KRW'),145.8
    );

-- insert conversion rate for HKD to USD
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'HKD'),(SELECT id FROM public.currency WHERE currency = 'USD'),0.1292
    );

-- insert conversion rate for HKD to GBP
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'HKD'),(SELECT id FROM public.currency WHERE currency = 'GBP'),0.0833
    );

-- insert conversion rate for HKD to EUR
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'HKD'),(SELECT id FROM public.currency WHERE currency = 'EUR'),0.1
    );

-- insert conversion rate for HKD to AUD
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'HKD'),(SELECT id FROM public.currency WHERE currency = 'AUD'),0.125
    );


-- GBP CONVERSIONS
-- insert conversion rate for GBP to HKD
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'GBP'),(SELECT id FROM public.currency WHERE currency = 'HKD'),12.00
    );

-- insert conversion rate for GBP to JPY
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'GBP'),(SELECT id FROM public.currency WHERE currency = 'JPY'),125
    );

-- insert conversion rate for GBP to CNY
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'GBP'),(SELECT id FROM public.currency WHERE currency = 'CNY'),10.00
    );

-- insert conversion rate for GBP to KRW
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'GBP'),(SELECT id FROM public.currency WHERE currency = 'KRW'),1750
    );

-- insert conversion rate for GBP to AUD
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'GBP'),(SELECT id FROM public.currency WHERE currency = 'AUD'),1.50
    );


-- USD CONVERSIONS
-- insert conversion rate for USD to HKD
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'USD'),(SELECT id FROM public.currency WHERE currency = 'HKD'),7.742
    );

-- insert conversion rate for USD to JPY
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'USD'),(SELECT id FROM public.currency WHERE currency = 'JPY'),80.65
    );

-- insert conversion rate for USD to CNY
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'USD'),(SELECT id FROM public.currency WHERE currency = 'CNY'),6.452
    );

-- insert conversion rate for USD to KRW
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'USD'),(SELECT id FROM public.currency WHERE currency = 'KRW'),1129
    );

-- insert conversion rate for USD to AUD
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'USD'),(SELECT id FROM public.currency WHERE currency = 'AUD'),0.968
    );

-- UPDATE FROM FINANCE
-- USD to EUR
UPDATE public.conversion_rate SET conversion_rate = 0.774 where season_id = (SELECT id FROM public.season WHERE season = 'CR13') AND source_currency = (SELECT id FROM public.currency WHERE currency = 'USD') AND destination_currency = (SELECT id FROM public.currency WHERE currency = 'EUR');


-- EUR CONVERSIONS
-- insert conversion rate for EUR to HKD
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'EUR'),(SELECT id FROM public.currency WHERE currency = 'HKD'),10.00
    );

-- insert conversion rate for EUR to JPY
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'EUR'),(SELECT id FROM public.currency WHERE currency = 'JPY'),104.17
    );

-- insert conversion rate for EUR to CNY
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'EUR'),(SELECT id FROM public.currency WHERE currency = 'CNY'),8.333
    );

-- insert conversion rate for EUR to KRW
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'EUR'),(SELECT id FROM public.currency WHERE currency = 'KRW'),1458.3
    );

-- insert conversion rate for EUR to AUD
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'EUR'),(SELECT id FROM public.currency WHERE currency = 'AUD'),1.25
    );

-- UPDATE FROM FINANCE
-- EUR to USD
UPDATE public.conversion_rate SET conversion_rate = 1.292 where season_id = (SELECT id FROM public.season WHERE season = 'CR13') AND source_currency = (SELECT id FROM public.currency WHERE currency = 'EUR') AND destination_currency = (SELECT id FROM public.currency WHERE currency = 'USD');


-- JPY CONVERSIONS
-- insert conversion rate for JPY to HKD
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'JPY'),(SELECT id FROM public.currency WHERE currency = 'HKD'),0.096
    );

-- insert conversion rate for JPY to JPY
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'JPY'),(SELECT id FROM public.currency WHERE currency = 'JPY'),1
    );

-- insert conversion rate for JPY to CNY
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'JPY'),(SELECT id FROM public.currency WHERE currency = 'CNY'),0.08
    );

-- insert conversion rate for JPY to KRW
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'JPY'),(SELECT id FROM public.currency WHERE currency = 'KRW'),14.00
    );

-- insert conversion rate for JPY to USD
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'JPY'),(SELECT id FROM public.currency WHERE currency = 'USD'),0.0124
    );

-- insert conversion rate for JPY to GBP
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'JPY'),(SELECT id FROM public.currency WHERE currency = 'GBP'),0.0080
    );

-- insert conversion rate for JPY to EUR
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'JPY'),(SELECT id FROM public.currency WHERE currency = 'EUR'),0.0096
    );

-- insert conversion rate for JPY to AUD
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'JPY'),(SELECT id FROM public.currency WHERE currency = 'AUD'),0.012
    );


-- CNY CONVERSIONS
-- insert conversion rate for CNY to HKD
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'CNY'),(SELECT id FROM public.currency WHERE currency = 'HKD'),1.2
    );

-- insert conversion rate for CNY to JPY
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'CNY'),(SELECT id FROM public.currency WHERE currency = 'JPY'),12.5
    );

-- insert conversion rate for CNY to CNY
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'CNY'),(SELECT id FROM public.currency WHERE currency = 'CNY'),1
    );

-- insert conversion rate for CNY to KRW
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'CNY'),(SELECT id FROM public.currency WHERE currency = 'KRW'),175.00
    );

-- insert conversion rate for CNY to USD
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'CNY'),(SELECT id FROM public.currency WHERE currency = 'USD'),0.155
    );

-- insert conversion rate for CNY to GBP
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'CNY'),(SELECT id FROM public.currency WHERE currency = 'GBP'),0.1
    );

-- insert conversion rate for CNY to EUR
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'CNY'),(SELECT id FROM public.currency WHERE currency = 'EUR'),0.12
    );

-- insert conversion rate for CNY to AUD
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'CNY'),(SELECT id FROM public.currency WHERE currency = 'AUD'),0.15
    );


-- KRW CONVERSIONS
-- insert conversion rate for KRW to HKD
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'KRW'),(SELECT id FROM public.currency WHERE currency = 'HKD'),0.0068571
    );

-- insert conversion rate for KRW to JPY
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'KRW'),(SELECT id FROM public.currency WHERE currency = 'JPY'),0.07143
    );

-- insert conversion rate for KRW to CNY
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'KRW'),(SELECT id FROM public.currency WHERE currency = 'CNY'),0.0057143
    );

-- insert conversion rate for KRW to KRW
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'KRW'),(SELECT id FROM public.currency WHERE currency = 'KRW'),1
    );

-- insert conversion rate for KRW to USD
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'KRW'),(SELECT id FROM public.currency WHERE currency = 'USD'),0.0008857
    );

-- insert conversion rate for KRW to GBP
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'KRW'),(SELECT id FROM public.currency WHERE currency = 'GBP'),0.0005714
    );

-- insert conversion rate for KRW to EUR
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'KRW'),(SELECT id FROM public.currency WHERE currency = 'EUR'),0.0006857
    );

-- insert conversion rate for KRW to AUD
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'KRW'),(SELECT id FROM public.currency WHERE currency = 'AUD'),0.0008571
    );


-- AUD CONVERSIONS
-- insert conversion rate for AUD to HKD
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'AUD'),(SELECT id FROM public.currency WHERE currency = 'HKD'),8
    );

-- insert conversion rate for AUD to JPY
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'AUD'),(SELECT id FROM public.currency WHERE currency = 'JPY'),83.33
    );

-- insert conversion rate for AUD to CNY
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'AUD'),(SELECT id FROM public.currency WHERE currency = 'CNY'),6.667
    );

-- insert conversion rate for AUD to KRW
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'AUD'),(SELECT id FROM public.currency WHERE currency = 'KRW'),1166.7
    );

-- insert conversion rate for AUD to USD
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'AUD'),(SELECT id FROM public.currency WHERE currency = 'USD'),1.0333
    );

-- insert conversion rate for AUD to GBP
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'AUD'),(SELECT id FROM public.currency WHERE currency = 'GBP'),0.6667
    );

-- insert conversion rate for AUD to EUR
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'AUD'),(SELECT id FROM public.currency WHERE currency = 'EUR'),0.8
    );

-- insert conversion rate for AUD to AUD
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'CR13'),(SELECT id FROM public.currency WHERE currency = 'AUD'),(SELECT id FROM public.currency WHERE currency = 'AUD'),1
    );




--SEASON SS13

-- HK CONVERSIONS
-- insert conversion rate for HKD to HKD
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'HKD'),(SELECT id FROM public.currency WHERE currency = 'HKD'),1
    );

-- insert conversion rate for HKD to JPY
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'HKD'),(SELECT id FROM public.currency WHERE currency = 'JPY'),10.417
    );

-- insert conversion rate for HKD to CNY
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'HKD'),(SELECT id FROM public.currency WHERE currency = 'CNY'),0.833
    );

-- insert conversion rate for HKD to KRW
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'HKD'),(SELECT id FROM public.currency WHERE currency = 'KRW'),145.8
    );

-- insert conversion rate for HKD to USD
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'HKD'),(SELECT id FROM public.currency WHERE currency = 'USD'),0.1292
    );

-- insert conversion rate for HKD to GBP
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'HKD'),(SELECT id FROM public.currency WHERE currency = 'GBP'),0.0833
    );

-- insert conversion rate for HKD to EUR
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'HKD'),(SELECT id FROM public.currency WHERE currency = 'EUR'),0.1
    );

-- insert conversion rate for HKD to AUD
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'HKD'),(SELECT id FROM public.currency WHERE currency = 'AUD'),0.125
    );


-- GBP CONVERSIONS
-- insert conversion rate for GBP to HKD
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'GBP'),(SELECT id FROM public.currency WHERE currency = 'HKD'),12.00
    );

-- insert conversion rate for GBP to JPY
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'GBP'),(SELECT id FROM public.currency WHERE currency = 'JPY'),125
    );

-- insert conversion rate for GBP to CNY
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'GBP'),(SELECT id FROM public.currency WHERE currency = 'CNY'),10.00
    );

-- insert conversion rate for GBP to KRW
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'GBP'),(SELECT id FROM public.currency WHERE currency = 'KRW'),1750
    );

-- insert conversion rate for GBP to AUD
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'GBP'),(SELECT id FROM public.currency WHERE currency = 'AUD'),1.50
    );


-- USD CONVERSIONS
-- insert conversion rate for USD to HKD
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'USD'),(SELECT id FROM public.currency WHERE currency = 'HKD'),7.742
    );

-- insert conversion rate for USD to JPY
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'USD'),(SELECT id FROM public.currency WHERE currency = 'JPY'),80.65
    );

-- insert conversion rate for USD to CNY
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'USD'),(SELECT id FROM public.currency WHERE currency = 'CNY'),6.452
    );

-- insert conversion rate for USD to KRW
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'USD'),(SELECT id FROM public.currency WHERE currency = 'KRW'),1129
    );

-- insert conversion rate for USD to AUD
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'USD'),(SELECT id FROM public.currency WHERE currency = 'AUD'),0.968
    );

-- UPDATE FROM FINANCE
-- USD to EUR
UPDATE public.conversion_rate SET conversion_rate = 0.774 where season_id = (SELECT id FROM public.season WHERE season = 'SS13') AND source_currency = (SELECT id FROM public.currency WHERE currency = 'USD') AND destination_currency = (SELECT id FROM public.currency WHERE currency = 'EUR');


-- EUR CONVERSIONS
-- insert conversion rate for EUR to HKD
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'EUR'),(SELECT id FROM public.currency WHERE currency = 'HKD'),10.00
    );

-- insert conversion rate for EUR to JPY
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'EUR'),(SELECT id FROM public.currency WHERE currency = 'JPY'),104.17
    );

-- insert conversion rate for EUR to CNY
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'EUR'),(SELECT id FROM public.currency WHERE currency = 'CNY'),8.333
    );

-- insert conversion rate for EUR to KRW
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'EUR'),(SELECT id FROM public.currency WHERE currency = 'KRW'),1458.3
    );

-- insert conversion rate for EUR to AUD
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'EUR'),(SELECT id FROM public.currency WHERE currency = 'AUD'),1.25
    );

-- UPDATE FROM FINANCE
-- EUR to USD
UPDATE public.conversion_rate SET conversion_rate = 1.292 where season_id = (SELECT id FROM public.season WHERE season = 'SS13') AND source_currency = (SELECT id FROM public.currency WHERE currency = 'EUR') AND destination_currency = (SELECT id FROM public.currency WHERE currency = 'USD');


-- JPY CONVERSIONS
-- insert conversion rate for JPY to HKD
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'JPY'),(SELECT id FROM public.currency WHERE currency = 'HKD'),0.096
    );

-- insert conversion rate for JPY to JPY
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'JPY'),(SELECT id FROM public.currency WHERE currency = 'JPY'),1
    );

-- insert conversion rate for JPY to CNY
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'JPY'),(SELECT id FROM public.currency WHERE currency = 'CNY'),0.08
    );

-- insert conversion rate for JPY to KRW
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'JPY'),(SELECT id FROM public.currency WHERE currency = 'KRW'),14.00
    );

-- insert conversion rate for JPY to USD
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'JPY'),(SELECT id FROM public.currency WHERE currency = 'USD'),0.0124
    );

-- insert conversion rate for JPY to GBP
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'JPY'),(SELECT id FROM public.currency WHERE currency = 'GBP'),0.0080
    );

-- insert conversion rate for JPY to EUR
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'JPY'),(SELECT id FROM public.currency WHERE currency = 'EUR'),0.0096
    );

-- insert conversion rate for JPY to AUD
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'JPY'),(SELECT id FROM public.currency WHERE currency = 'AUD'),0.012
    );


-- CNY CONVERSIONS
-- insert conversion rate for CNY to HKD
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'CNY'),(SELECT id FROM public.currency WHERE currency = 'HKD'),1.2
    );

-- insert conversion rate for CNY to JPY
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'CNY'),(SELECT id FROM public.currency WHERE currency = 'JPY'),12.5
    );

-- insert conversion rate for CNY to CNY
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'CNY'),(SELECT id FROM public.currency WHERE currency = 'CNY'),1
    );

-- insert conversion rate for CNY to KRW
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'CNY'),(SELECT id FROM public.currency WHERE currency = 'KRW'),175.00
    );

-- insert conversion rate for CNY to USD
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'CNY'),(SELECT id FROM public.currency WHERE currency = 'USD'),0.155
    );

-- insert conversion rate for CNY to GBP
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'CNY'),(SELECT id FROM public.currency WHERE currency = 'GBP'),0.1
    );

-- insert conversion rate for CNY to EUR
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'CNY'),(SELECT id FROM public.currency WHERE currency = 'EUR'),0.12
    );

-- insert conversion rate for CNY to AUD
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'CNY'),(SELECT id FROM public.currency WHERE currency = 'AUD'),0.15
    );


-- KRW CONVERSIONS
-- insert conversion rate for KRW to HKD
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'KRW'),(SELECT id FROM public.currency WHERE currency = 'HKD'),0.0068571
    );

-- insert conversion rate for KRW to JPY
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'KRW'),(SELECT id FROM public.currency WHERE currency = 'JPY'),0.07143
    );

-- insert conversion rate for KRW to CNY
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'KRW'),(SELECT id FROM public.currency WHERE currency = 'CNY'),0.0057143
    );

-- insert conversion rate for KRW to KRW
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'KRW'),(SELECT id FROM public.currency WHERE currency = 'KRW'),1
    );

-- insert conversion rate for KRW to USD
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'KRW'),(SELECT id FROM public.currency WHERE currency = 'USD'),0.0008857
    );

-- insert conversion rate for KRW to GBP
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'KRW'),(SELECT id FROM public.currency WHERE currency = 'GBP'),0.0005714
    );

-- insert conversion rate for KRW to EUR
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'KRW'),(SELECT id FROM public.currency WHERE currency = 'EUR'),0.0006857
    );

-- insert conversion rate for KRW to AUD
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'KRW'),(SELECT id FROM public.currency WHERE currency = 'AUD'),0.0008571
    );


-- AUD CONVERSIONS
-- insert conversion rate for AUD to HKD
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'AUD'),(SELECT id FROM public.currency WHERE currency = 'HKD'),8
    );

-- insert conversion rate for AUD to JPY
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'AUD'),(SELECT id FROM public.currency WHERE currency = 'JPY'),83.33
    );

-- insert conversion rate for AUD to CNY
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'AUD'),(SELECT id FROM public.currency WHERE currency = 'CNY'),6.667
    );

-- insert conversion rate for AUD to KRW
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'AUD'),(SELECT id FROM public.currency WHERE currency = 'KRW'),1166.7
    );

-- insert conversion rate for AUD to USD
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'AUD'),(SELECT id FROM public.currency WHERE currency = 'USD'),1.0333
    );

-- insert conversion rate for AUD to GBP
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'AUD'),(SELECT id FROM public.currency WHERE currency = 'GBP'),0.6667
    );

-- insert conversion rate for AUD to EUR
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'AUD'),(SELECT id FROM public.currency WHERE currency = 'EUR'),0.8
    );

-- insert conversion rate for AUD to AUD
INSERT INTO public.conversion_rate (season_id,source_currency,destination_currency,conversion_rate)
    VALUES (
        (SELECT id FROM public.season WHERE season = 'SS13'),(SELECT id FROM public.currency WHERE currency = 'AUD'),(SELECT id FROM public.currency WHERE currency = 'AUD'),1
    );

COMMIT;

