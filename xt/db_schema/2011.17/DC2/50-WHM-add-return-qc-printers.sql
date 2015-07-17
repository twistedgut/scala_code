BEGIN;
DROP FUNCTION IF EXISTS update_return_qc_printer();
CREATE FUNCTION update_return_qc_printer() RETURNS text as '
    DECLARE
    cg_id INTEGER;
    count INTEGER := 0;
    BEGIN
        FOR number in 2 .. 8 LOOP
            SELECT INTO cg_id id from system_config.config_group where name = ''Printer_Station_Returns_QC_0'' || number;
            UPDATE system_config.config_group_setting SET value = ''returns_qc_small_0'' || number
                WHERE setting = ''printer_small''
                AND config_group_id = cg_id;
            count = count + 1;
        END LOOP;
        return count || '' printers updated'';
    END;
' LANGUAGE 'plpgsql';
select update_return_qc_printer();
DROP FUNCTION update_return_qc_printer();
COMMIT;
