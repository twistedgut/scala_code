BEGIN;

  ALTER TABLE recommended_product
    ADD COLUMN channel_id integer REFERENCES channel(id) DEFERRABLE;

  -- Create a trigger so that recomened_product needs a channel_id when the type is 1 (recomened product)
  CREATE OR REPLACE FUNCTION recommended_product_has_channel_id() RETURNS
  TRIGGER AS $$
    DECLARE
       recommendation_type INTEGER := 0;
    BEGIN 

      SELECT INTO recommendation_type id FROM recommended_product_type WHERE type = 'Recommendation';

      IF (NEW.type_id = recommendation_type AND NEW.channel_id IS NULL) THEN
        RAISE EXCEPTION '%: must have a channel_id for product Recommendations', TG_RELNAME;
      END IF;
      RETURN NEW;
    END;
  $$ LANGUAGE plpgsql;

  ALTER FUNCTION recommended_product_has_channel_id() OWNER TO www;


  CREATE TRIGGER recommended_product_tgr
      BEFORE INSERT OR UPDATE ON recommended_product
      FOR EACH ROW
      EXECUTE PROCEDURE recommended_product_has_channel_id();

  UPDATE recommended_product me
    SET channel_id = channel.id
    FROM channel,
         recommended_product_type type 
    WHERE channel.name = 'NET-A-PORTER.COM'
      AND type.type = 'Recommendation'
      AND me.type_id = type.id;

END;
