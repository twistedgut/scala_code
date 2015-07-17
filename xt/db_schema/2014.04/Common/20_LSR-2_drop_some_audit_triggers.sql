-- LSR-2: Remove some of the audit triggers

BEGIN WORK;

DROP TRIGGER    audit_tgr       ON product              RESTRICT;
DROP TRIGGER    audit_tgr       ON product_attribute    RESTRICT;
DROP TRIGGER    audit_tgr       ON shipping_attribute   RESTRICT;

COMMIT;

