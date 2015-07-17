-- Add 'from_company_name' to shipping_account table

BEGIN WORK;

ALTER TABLE shipping_account ADD from_company_name TEXT;

UPDATE shipping_account sa SET from_company_name = 'NET-A-PORTER' FROM channel c WHERE c.id = sa.channel_id AND c.name = 'NET-A-PORTER.COM';
UPDATE shipping_account sa SET from_company_name = 'MRPORTER' FROM channel c WHERE c.id = sa.channel_id AND c.name = 'MRPORTER.COM';
UPDATE shipping_account sa SET from_company_name = 'THE OUTNET' FROM channel c WHERE c.id = sa.channel_id AND c.name = 'theOutnet.com';

COMMIT WORK;
