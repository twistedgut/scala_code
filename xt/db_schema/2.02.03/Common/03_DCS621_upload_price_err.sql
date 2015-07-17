-- Add a new error for zero price found in the upload

BEGIN WORK;

INSERT INTO system_to_english_errors VALUES ( default, 'Receive::Upload::DoUpload', 'validation of ''price'' failed', 'Zero Price Found' );

COMMIT WORK;
