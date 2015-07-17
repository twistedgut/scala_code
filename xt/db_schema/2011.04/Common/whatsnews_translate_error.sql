-- make the message more meaningful!!!
BEGIN;
    UPDATE  system_to_english_errors
    SET     english_translation = 'Product does not exist in web-site database'
    WHERE   module_name         = 'Receive::Upload::WhatsNew'
      AND   english_translation = 'A product has not been uploaded';
COMMIT;
