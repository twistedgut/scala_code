-- CANDO-1261: Add an Index for the Upload Date
--             on the 'product_channel' table

BEGIN WORK;

CREATE INDEX idx_public_product_channel__upload_date ON product_channel(upload_date);
CREATE INDEX idx_public_product_channel__channel_id_upload_date ON product_channel(channel_id,upload_date);

COMMIT WORK;
