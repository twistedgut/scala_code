-- CANDO-576: New Tables to support the sending of SMS's
--            in particular and correspondence in general

BEGIN WORK;

--
-- SMS Status table
--
CREATE TABLE sms_correspondence_status (
    id              SERIAL NOT NULL PRIMARY KEY,
    status          CHARACTER VARYING(50) NOT NULL UNIQUE
)
;

ALTER TABLE sms_correspondence_status OWNER TO postgres;
GRANT ALL ON TABLE sms_correspondence_status TO postgres;
GRANT ALL ON TABLE sms_correspondence_status TO www;

GRANT ALL ON SEQUENCE sms_correspondence_status_id_seq TO postgres;
GRANT ALL ON SEQUENCE sms_correspondence_status_id_seq TO www;

-- Populate Status Table
INSERT INTO sms_correspondence_status (status) VALUES
('Pending'),
('Success'),
('Fail'),
('Not Sent to Proxy')
;


--
-- SMS table to store Messages sent to the SMS Proxy
--
CREATE TABLE sms_correspondence (
    id                              SERIAL NOT NULL PRIMARY KEY,
    csm_id                          INTEGER NOT NULL REFERENCES correspondence_subject_method(id),
    mobile_number                   CHARACTER VARYING(255) NOT NULL,
    message                         CHARACTER VARYING(160),
    date_sent                       TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    sms_correspondence_status_id    INTEGER NOT NULL REFERENCES sms_correspondence_status(id),
    failure_code                    CHARACTER VARYING(50)
)
;
CREATE INDEX sms_correspondence_mobile_number_idx ON sms_correspondence(mobile_number);

ALTER TABLE sms_correspondence OWNER TO postgres;
GRANT ALL ON TABLE sms_correspondence TO postgres;
GRANT ALL ON TABLE sms_correspondence TO www;

GRANT ALL ON SEQUENCE sms_correspondence_id_seq TO postgres;
GRANT ALL ON SEQUENCE sms_correspondence_id_seq TO www;

-- create link tables to a Shipment and Return to the above table
CREATE TABLE link_sms_correspondence__shipment (
    sms_correspondence_id   INTEGER NOT NULL REFERENCES sms_correspondence(id),
    shipment_id             INTEGER NOT NULL REFERENCES shipment(id)
)
;

ALTER TABLE link_sms_correspondence__shipment OWNER TO postgres;
GRANT ALL ON TABLE link_sms_correspondence__shipment TO postgres;
GRANT ALL ON TABLE link_sms_correspondence__shipment TO www;

CREATE TABLE link_sms_correspondence__return (
    sms_correspondence_id   INTEGER NOT NULL REFERENCES sms_correspondence(id),
    return_id               INTEGER NOT NULL REFERENCES return(id)
)
;

ALTER TABLE link_sms_correspondence__return OWNER TO postgres;
GRANT ALL ON TABLE link_sms_correspondence__return TO postgres;
GRANT ALL ON TABLE link_sms_correspondence__return TO www;


--
-- Alter 'correspondence_subject_method' to add
-- 'notify_on_failure' column
--
ALTER TABLE correspondence_subject_method
    ADD COLUMN send_from CHARACTER VARYING(50),
    ADD COLUMN copy_to_crm BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN notify_on_failure CHARACTER VARYING(50)
;

-- Populate the new fields for SMS & Email Methods
UPDATE  correspondence_subject_method
    SET copy_to_crm = TRUE,
        notify_on_failure = 'premier_email'
WHERE   correspondence_subject_id IN (
            SELECT  id
            FROM    correspondence_subject
            WHERE   subject = 'Premier Delivery'
        )
AND     correspondence_method_id = (
            SELECT  id
            FROM    correspondence_method
            WHERE   method = 'SMS'
        )
;
UPDATE  correspondence_subject_method
    SET send_from = 'premier_email'
WHERE   correspondence_subject_id IN (
            SELECT  id
            FROM    correspondence_subject
            WHERE   subject = 'Premier Delivery'
        )
AND     correspondence_method_id = (
            SELECT  id
            FROM    correspondence_method
            WHERE   method = 'Email'
        )
;

--
-- CSM Exclusion Calendar
--
CREATE TABLE csm_exclusion_calendar (
    id              SERIAL NOT NULL PRIMARY KEY,
    csm_id          INTEGER NOT NULL REFERENCES correspondence_subject_method(id),
    start_time      TIME,
    end_time        TIME,
    start_date      CHARACTER VARYING(10),
    end_date        CHARACTER VARYING(10),
    day_of_week     CHARACTER VARYING(13),
    UNIQUE(csm_id,start_time,end_time,start_date,end_date,day_of_week)
)
;

ALTER TABLE csm_exclusion_calendar OWNER TO postgres;
GRANT ALL ON TABLE csm_exclusion_calendar TO postgres;
GRANT ALL ON TABLE csm_exclusion_calendar TO www;

GRANT ALL ON SEQUENCE csm_exclusion_calendar_id_seq TO postgres;
GRANT ALL ON SEQUENCE csm_exclusion_calendar_id_seq TO www;

-- Populate Exclusion Calendar
INSERT INTO csm_exclusion_calendar (csm_id,start_time,end_time,start_date)
SELECT  csm.id,
        CAST('21:00:00' AS TIME),
        CAST('07:59:59' AS TIME),
        null
FROM    correspondence_subject_method csm
        JOIN correspondence_subject cs ON cs.id = csm.correspondence_subject_id
                                        AND subject = 'Premier Delivery'
        JOIN correspondence_method cm ON cm.id = csm.correspondence_method_id
                                        AND method = 'SMS'
UNION
SELECT  csm.id,
        null,
        null,
        '25/12'
FROM    correspondence_subject_method csm
        JOIN correspondence_subject cs ON cs.id = csm.correspondence_subject_id
                                        AND subject = 'Premier Delivery'
        JOIN correspondence_method cm ON cm.id = csm.correspondence_method_id
                                        AND method = 'SMS'
ORDER BY 1,2
;

--
-- New Sales Channel Branding for SMS Sender Id
--
INSERT INTO branding (code,description) VALUES ( 'SMS_SENDER_ID', 'SMS Sender Id' );

-- Now populate it for each Sales Channel
INSERT INTO channel_branding (channel_id,branding_id,value)
SELECT  ch.id,
        (
            SELECT  id
            FROM    branding
            WHERE   code = 'SMS_SENDER_ID'
        ),
        CASE b.config_section
            WHEN 'NAP' THEN 'NETAPORTER'
            WHEN 'OUTNET' THEN 'THEOUTNET'
            WHEN 'MRP' THEN 'MRPORTER'
            WHEN 'JC' THEN 'JIMMYCHOO'
        END
FROM    channel ch
        JOIN business b ON b.id = ch.business_id
ORDER BY ch.id
;


COMMIT WORK;
