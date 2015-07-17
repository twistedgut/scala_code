-- CANDO-2201: Use a Mobile Friendly Premier Telephone Number
--             in the SMS Copy for Premier Routing Communications

BEGIN WORK;

UPDATE  correspondence_templates
    SET content = REPLACE(content,'company_detail.premier_tel ','company_detail.premier_tel_mobile_friendly ')
WHERE   name ILIKE 'Premier - %SMS%'
AND     department_id = (
    SELECT  id
    FROM    department
    WHERE   department = 'Shipping'
)
AND     content ILIKE '%company_detail.premier_tel %'
;

COMMIT WORK;
