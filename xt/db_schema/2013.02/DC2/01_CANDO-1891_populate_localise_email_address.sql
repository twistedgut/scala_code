-- CANDO-1891: Populate 'localised_email_address' table

BEGIN WORK;

INSERT INTO localised_email_address (email_address, locale, localised_email_address ) VALUES
( 'customercare.usa@net-a-porter.com', 'fr_FR', 'serviceclientele@net-a-porter.com' ),
( 'customercare.usa@net-a-porter.com', 'de_DE', 'kundenservice@net-a-porter.com' ),
( 'customercare.usa@net-a-porter.com', 'zh_CN', 'customercare.cn@net-a-porter.com' ),
( 'fashionadvisor.usa@net-a-porter.com', 'fr_FR', 'conseillerstyle@net-a-porter.com' ),
( 'fashionadvisor.usa@net-a-porter.com', 'de_DE', 'modeexperte@net-a-porter.com' ),
( 'fashionadvisor.usa@net-a-porter.com', 'zh_CN', 'fashionadvisor.cn@net-a-porter.com' )
;

COMMIT WORK;
