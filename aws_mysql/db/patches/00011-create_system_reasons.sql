-- liquibase formatted sql
-- changeset m.esquerra:11


INSERT INTO    reason (name,         code,                                    is_active,  is_positive,  reason_type)
       VALUES         ('PACKING',    '2d3d14d3-349d-434b-afbe-18d78c60254c',  true,       false,        'System')
       ON DUPLICATE KEY UPDATE
              name        = VALUES(name),
              code        = VALUES(code),
              is_active   = VALUES(is_active),
              is_positive = VALUES(is_positive),
              reason_type = VALUES(reason_type);


INSERT INTO    reason (name,         code,                                    is_active,  is_positive,  reason_type)
       VALUES         ('DELIVERY',   'f7766dcf-afa6-47aa-93d6-fad2e99157cd',  true,       true,         'System')
       ON DUPLICATE KEY UPDATE
              name        = VALUES(name),
              code        = VALUES(code),
              is_active   = VALUES(is_active),
              is_positive = VALUES(is_positive),
              reason_type = VALUES(reason_type);
