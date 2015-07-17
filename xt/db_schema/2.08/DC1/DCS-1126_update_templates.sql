-- Change 'Return/Exchange' & 'Convert to Exchange' emails to check for the absence of a Return Airway Bill for DHL Ground

BEGIN WORK;

UPDATE  correspondence_templates
    SET content = REPLACE(content,
                            'IF shipment_info.carrier == "DHL Ground" %',
                            'IF shipment_info.carrier == "DHL Ground" && shipment_info.return_airway_bill == "none" %')
WHERE   name = 'Return/Exchange'
;

UPDATE  correspondence_templates
    SET content = REPLACE(content,
                            'IF shipment_info.carrier == "DHL Ground" %',
                            'IF shipment_info.carrier == "DHL Ground" && shipment_info.return_airway_bill == "none" %')
WHERE   name = 'Convert to Exchange'
;

COMMIT WORK;
