-- Add a stored procedure for correctly formatting the variant.size_id

BEGIN;

CREATE OR REPLACE FUNCTION sku_padding(size_id int)
RETURNS varchar AS $$
BEGIN
  IF size_id > 999 THEN
    RETURN cast(size_id as varchar);
  ELSE
    RETURN LPAD(CAST(size_id as VARCHAR), 3, '0');
  END IF;
END;
$$ LANGUAGE plpgsql;

COMMIT;

