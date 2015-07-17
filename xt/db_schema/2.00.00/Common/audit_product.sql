BEGIN;

DROP TRIGGER audit_tgr ON product;

CREATE OR REPLACE FUNCTION product_audit() RETURNS "trigger"
    AS '
DECLARE
    -- Variables
    v_operator_id     INTEGER := NULL;
    v_table_id        INTEGER := NULL;
    v_product_id      INTEGER := NULL;
    v_action_id       INTEGER := NULL;
    v_comment         TEXT    := '''';
    v_pushed_to_live  BOOLEAN := NULL;
BEGIN
 
    --RAISE NOTICE ''FIELDS: % %'', TG_RELNAME, TG_OP;
 
    SELECT INTO v_action_id id FROM audit.action WHERE table_name = TG_RELNAME AND action = TG_OP;
 
    IF v_action_id IS NULL THEN
        RAISE NOTICE ''audit_trigger: Undefined action for table: % ; action: %'', TG_RELNAME, TG_OP;
    END IF;
 
    -- INSERT and UPDATE use NEW
    IF (TG_OP = ''INSERT'' OR TG_OP = ''UPDATE'') THEN
    
        v_operator_id    := NEW.operator_id;
        v_table_id       := NEW.id;
        v_product_id     := v_table_id;
        
        IF (NOT TG_RELNAME = ''product'') THEN
            v_product_id := NEW.product_id;
        END IF;
 
    -- DELETE uses OLD
    ELSE
    
        v_operator_id    := OLD.operator_id;
        v_table_id       := OLD.id;
        v_product_id     := v_table_id;
 
        IF (NOT TG_RELNAME = ''product'') THEN
            v_product_id := OLD.product_id;
        END IF;
 
    END IF;
 
    v_comment := build_comment(v_action_id, v_operator_id);
    
 IF (TG_RELNAME = ''product_attribute'') THEN
 
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''product_id'', NULL, CAST(NEW.product_id AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.product_id AS TEXT), '''') <> COALESCE(CAST(OLD.product_id AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''product_id'', CAST(OLD.product_id AS Text), CAST(NEW.product_id AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''product_id'', CAST(OLD.product_id AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''name'', NULL, CAST(NEW.name AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.name AS TEXT), '''') <> COALESCE(CAST(OLD.name AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''name'', CAST(OLD.name AS Text), CAST(NEW.name AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''name'', CAST(OLD.name AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''description'', NULL, CAST(NEW.description AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.description AS TEXT), '''') <> COALESCE(CAST(OLD.description AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''description'', CAST(OLD.description AS Text), CAST(NEW.description AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''description'', CAST(OLD.description AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;

  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''size_fit'', NULL, CAST(NEW.size_fit AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.size_fit AS TEXT), '''') <> COALESCE(CAST(OLD.size_fit AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''size_fit'', CAST(OLD.size_fit AS Text), CAST(NEW.size_fit AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''size_fit'', CAST(OLD.size_fit AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;

  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''long_description'', NULL, CAST(NEW.long_description AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.long_description AS TEXT), '''') <> COALESCE(CAST(OLD.long_description AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''long_description'', CAST(OLD.long_description AS Text), CAST(NEW.long_description AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''long_description'', CAST(OLD.long_description AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;

  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''short_description'', NULL, CAST(NEW.short_description AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.short_description AS TEXT), '''') <> COALESCE(CAST(OLD.short_description AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''short_description'', CAST(OLD.short_description AS Text), CAST(NEW.short_description AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''short_description'', CAST(OLD.short_description AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;

  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''designer_colour'', NULL, CAST(NEW.designer_colour AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.designer_colour AS TEXT), '''') <> COALESCE(CAST(OLD.designer_colour AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''designer_colour'', CAST(OLD.designer_colour AS Text), CAST(NEW.designer_colour AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''designer_colour'', CAST(OLD.designer_colour AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''editors_comments'', NULL, CAST(NEW.editors_comments AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.editors_comments AS TEXT), '''') <> COALESCE(CAST(OLD.editors_comments AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''editors_comments'', CAST(OLD.editors_comments AS Text), CAST(NEW.editors_comments AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''editors_comments'', CAST(OLD.editors_comments AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''keywords'', NULL, CAST(NEW.keywords AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.keywords AS TEXT), '''') <> COALESCE(CAST(OLD.keywords AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''keywords'', CAST(OLD.keywords AS Text), CAST(NEW.keywords AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''keywords'', CAST(OLD.keywords AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''recommended'', NULL, CAST(NEW.recommended AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.recommended AS TEXT), '''') <> COALESCE(CAST(OLD.recommended AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''recommended'', CAST(OLD.recommended AS Text), CAST(NEW.recommended AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''recommended'', CAST(OLD.recommended AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''designer_colour_code'', NULL, CAST(NEW.designer_colour_code AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.designer_colour_code AS TEXT), '''') <> COALESCE(CAST(OLD.designer_colour_code AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''designer_colour_code'', CAST(OLD.designer_colour_code AS Text), CAST(NEW.designer_colour_code AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''designer_colour_code'', CAST(OLD.designer_colour_code AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''size_scheme_id'', NULL, CAST(NEW.size_scheme_id AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.size_scheme_id AS TEXT), '''') <> COALESCE(CAST(OLD.size_scheme_id AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''size_scheme_id'', CAST(OLD.size_scheme_id AS Text), CAST(NEW.size_scheme_id AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''size_scheme_id'', CAST(OLD.size_scheme_id AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''custom_lists'', NULL, CAST(NEW.custom_lists AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.custom_lists AS TEXT), '''') <> COALESCE(CAST(OLD.custom_lists AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''custom_lists'', CAST(OLD.custom_lists AS Text), CAST(NEW.custom_lists AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''custom_lists'', CAST(OLD.custom_lists AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''act_id'', NULL, CAST(NEW.act_id AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.act_id AS TEXT), '''') <> COALESCE(CAST(OLD.act_id AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''act_id'', CAST(OLD.act_id AS Text), CAST(NEW.act_id AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''act_id'', CAST(OLD.act_id AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''operator_id'', NULL, CAST(NEW.operator_id AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.operator_id AS TEXT), '''') <> COALESCE(CAST(OLD.operator_id AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''operator_id'', CAST(OLD.operator_id AS Text), CAST(NEW.operator_id AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''operator_id'', CAST(OLD.operator_id AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''id'', NULL, CAST(NEW.id AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.id AS TEXT), '''') <> COALESCE(CAST(OLD.id AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''id'', CAST(OLD.id AS Text), CAST(NEW.id AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''id'', CAST(OLD.id AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''runway_look'', NULL, CAST(NEW.runway_look AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.runway_look AS TEXT), '''') <> COALESCE(CAST(OLD.runway_look AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''runway_look'', CAST(OLD.runway_look AS Text), CAST(NEW.runway_look AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''runway_look'', CAST(OLD.runway_look AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''sample_correct'', NULL, CAST(NEW.sample_correct AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.sample_correct AS TEXT), '''') <> COALESCE(CAST(OLD.sample_correct AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''sample_correct'', CAST(OLD.sample_correct AS Text), CAST(NEW.sample_correct AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''sample_correct'', CAST(OLD.sample_correct AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''sample_colour_correct'', NULL, CAST(NEW.sample_colour_correct AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.sample_colour_correct AS TEXT), '''') <> COALESCE(CAST(OLD.sample_colour_correct AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''sample_colour_correct'', CAST(OLD.sample_colour_correct AS Text), CAST(NEW.sample_colour_correct AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''sample_colour_correct'', CAST(OLD.sample_colour_correct AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''product_department_id'', NULL, CAST(NEW.product_department_id AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.product_department_id AS TEXT), '''') <> COALESCE(CAST(OLD.product_department_id AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''product_department_id'', CAST(OLD.product_department_id AS Text), CAST(NEW.product_department_id AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''product_department_id'', CAST(OLD.product_department_id AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''fit_notes'', NULL, CAST(NEW.fit_notes AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.fit_notes AS TEXT), '''') <> COALESCE(CAST(OLD.fit_notes AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''fit_notes'', CAST(OLD.fit_notes AS Text), CAST(NEW.fit_notes AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''fit_notes'', CAST(OLD.fit_notes AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''style_notes'', NULL, CAST(NEW.style_notes AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.style_notes AS TEXT), '''') <> COALESCE(CAST(OLD.style_notes AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''style_notes'', CAST(OLD.style_notes AS Text), CAST(NEW.style_notes AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''style_notes'', CAST(OLD.style_notes AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''editorial_approved'', NULL, CAST(NEW.editorial_approved AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.editorial_approved AS TEXT), '''') <> COALESCE(CAST(OLD.editorial_approved AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''editorial_approved'', CAST(OLD.editorial_approved AS Text), CAST(NEW.editorial_approved AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''editorial_approved'', CAST(OLD.editorial_approved AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''use_measurements'', NULL, CAST(NEW.use_measurements AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.use_measurements AS TEXT), '''') <> COALESCE(CAST(OLD.use_measurements AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''use_measurements'', CAST(OLD.use_measurements AS Text), CAST(NEW.use_measurements AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''use_measurements'', CAST(OLD.use_measurements AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
 ELSIF (TG_RELNAME = ''price_region'') THEN
 
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''product_id'', NULL, CAST(NEW.product_id AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.product_id AS TEXT), '''') <> COALESCE(CAST(OLD.product_id AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''product_id'', CAST(OLD.product_id AS Text), CAST(NEW.product_id AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''product_id'', CAST(OLD.product_id AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''region_id'', NULL, CAST(NEW.region_id AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.region_id AS TEXT), '''') <> COALESCE(CAST(OLD.region_id AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''region_id'', CAST(OLD.region_id AS Text), CAST(NEW.region_id AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''region_id'', CAST(OLD.region_id AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''price'', NULL, CAST(NEW.price AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.price AS TEXT), '''') <> COALESCE(CAST(OLD.price AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''price'', CAST(OLD.price AS Text), CAST(NEW.price AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''price'', CAST(OLD.price AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''currency_id'', NULL, CAST(NEW.currency_id AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.currency_id AS TEXT), '''') <> COALESCE(CAST(OLD.currency_id AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''currency_id'', CAST(OLD.currency_id AS Text), CAST(NEW.currency_id AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''currency_id'', CAST(OLD.currency_id AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''operator_id'', NULL, CAST(NEW.operator_id AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.operator_id AS TEXT), '''') <> COALESCE(CAST(OLD.operator_id AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''operator_id'', CAST(OLD.operator_id AS Text), CAST(NEW.operator_id AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''operator_id'', CAST(OLD.operator_id AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''id'', NULL, CAST(NEW.id AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.id AS TEXT), '''') <> COALESCE(CAST(OLD.id AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''id'', CAST(OLD.id AS Text), CAST(NEW.id AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''id'', CAST(OLD.id AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
 ELSIF (TG_RELNAME = ''shipping_attribute'') THEN
 
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''product_id'', NULL, CAST(NEW.product_id AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.product_id AS TEXT), '''') <> COALESCE(CAST(OLD.product_id AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''product_id'', CAST(OLD.product_id AS Text), CAST(NEW.product_id AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''product_id'', CAST(OLD.product_id AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''scientific_term'', NULL, CAST(NEW.scientific_term AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.scientific_term AS TEXT), '''') <> COALESCE(CAST(OLD.scientific_term AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''scientific_term'', CAST(OLD.scientific_term AS Text), CAST(NEW.scientific_term AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''scientific_term'', CAST(OLD.scientific_term AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''country_id'', NULL, CAST(NEW.country_id AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.country_id AS TEXT), '''') <> COALESCE(CAST(OLD.country_id AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''country_id'', CAST(OLD.country_id AS Text), CAST(NEW.country_id AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''country_id'', CAST(OLD.country_id AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''packing_note'', NULL, CAST(NEW.packing_note AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.packing_note AS TEXT), '''') <> COALESCE(CAST(OLD.packing_note AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''packing_note'', CAST(OLD.packing_note AS Text), CAST(NEW.packing_note AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''packing_note'', CAST(OLD.packing_note AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''weight'', NULL, CAST(NEW.weight AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.weight AS TEXT), '''') <> COALESCE(CAST(OLD.weight AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''weight'', CAST(OLD.weight AS Text), CAST(NEW.weight AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''weight'', CAST(OLD.weight AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''box_id'', NULL, CAST(NEW.box_id AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.box_id AS TEXT), '''') <> COALESCE(CAST(OLD.box_id AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''box_id'', CAST(OLD.box_id AS Text), CAST(NEW.box_id AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''box_id'', CAST(OLD.box_id AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''fabric_content'', NULL, CAST(NEW.fabric_content AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.fabric_content AS TEXT), '''') <> COALESCE(CAST(OLD.fabric_content AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''fabric_content'', CAST(OLD.fabric_content AS Text), CAST(NEW.fabric_content AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''fabric_content'', CAST(OLD.fabric_content AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''legacy_countryoforigin'', NULL, CAST(NEW.legacy_countryoforigin AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.legacy_countryoforigin AS TEXT), '''') <> COALESCE(CAST(OLD.legacy_countryoforigin AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''legacy_countryoforigin'', CAST(OLD.legacy_countryoforigin AS Text), CAST(NEW.legacy_countryoforigin AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''legacy_countryoforigin'', CAST(OLD.legacy_countryoforigin AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''fish_wildlife'', NULL, CAST(NEW.fish_wildlife AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.fish_wildlife AS TEXT), '''') <> COALESCE(CAST(OLD.fish_wildlife AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''fish_wildlife'', CAST(OLD.fish_wildlife AS Text), CAST(NEW.fish_wildlife AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''fish_wildlife'', CAST(OLD.fish_wildlife AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''operator_id'', NULL, CAST(NEW.operator_id AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.operator_id AS TEXT), '''') <> COALESCE(CAST(OLD.operator_id AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''operator_id'', CAST(OLD.operator_id AS Text), CAST(NEW.operator_id AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''operator_id'', CAST(OLD.operator_id AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''id'', NULL, CAST(NEW.id AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.id AS TEXT), '''') <> COALESCE(CAST(OLD.id AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''id'', CAST(OLD.id AS Text), CAST(NEW.id AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''id'', CAST(OLD.id AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
 ELSIF (TG_RELNAME = ''product'') THEN
 
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''id'', NULL, CAST(NEW.id AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.id AS TEXT), '''') <> COALESCE(CAST(OLD.id AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''id'', CAST(OLD.id AS Text), CAST(NEW.id AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''id'', CAST(OLD.id AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''world_id'', NULL, CAST(NEW.world_id AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.world_id AS TEXT), '''') <> COALESCE(CAST(OLD.world_id AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''world_id'', CAST(OLD.world_id AS Text), CAST(NEW.world_id AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''world_id'', CAST(OLD.world_id AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''designer_id'', NULL, CAST(NEW.designer_id AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.designer_id AS TEXT), '''') <> COALESCE(CAST(OLD.designer_id AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''designer_id'', CAST(OLD.designer_id AS Text), CAST(NEW.designer_id AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''designer_id'', CAST(OLD.designer_id AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''division_id'', NULL, CAST(NEW.division_id AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.division_id AS TEXT), '''') <> COALESCE(CAST(OLD.division_id AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''division_id'', CAST(OLD.division_id AS Text), CAST(NEW.division_id AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''division_id'', CAST(OLD.division_id AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''classification_id'', NULL, CAST(NEW.classification_id AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.classification_id AS TEXT), '''') <> COALESCE(CAST(OLD.classification_id AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''classification_id'', CAST(OLD.classification_id AS Text), CAST(NEW.classification_id AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''classification_id'', CAST(OLD.classification_id AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''product_type_id'', NULL, CAST(NEW.product_type_id AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.product_type_id AS TEXT), '''') <> COALESCE(CAST(OLD.product_type_id AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''product_type_id'', CAST(OLD.product_type_id AS Text), CAST(NEW.product_type_id AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''product_type_id'', CAST(OLD.product_type_id AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''sub_type_id'', NULL, CAST(NEW.sub_type_id AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.sub_type_id AS TEXT), '''') <> COALESCE(CAST(OLD.sub_type_id AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''sub_type_id'', CAST(OLD.sub_type_id AS Text), CAST(NEW.sub_type_id AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''sub_type_id'', CAST(OLD.sub_type_id AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''colour_id'', NULL, CAST(NEW.colour_id AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.colour_id AS TEXT), '''') <> COALESCE(CAST(OLD.colour_id AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''colour_id'', CAST(OLD.colour_id AS Text), CAST(NEW.colour_id AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''colour_id'', CAST(OLD.colour_id AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''style_number'', NULL, CAST(NEW.style_number AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.style_number AS TEXT), '''') <> COALESCE(CAST(OLD.style_number AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''style_number'', CAST(OLD.style_number AS Text), CAST(NEW.style_number AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''style_number'', CAST(OLD.style_number AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''season_id'', NULL, CAST(NEW.season_id AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.season_id AS TEXT), '''') <> COALESCE(CAST(OLD.season_id AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''season_id'', CAST(OLD.season_id AS Text), CAST(NEW.season_id AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''season_id'', CAST(OLD.season_id AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''hs_code_id'', NULL, CAST(NEW.hs_code_id AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.hs_code_id AS TEXT), '''') <> COALESCE(CAST(OLD.hs_code_id AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''hs_code_id'', CAST(OLD.hs_code_id AS Text), CAST(NEW.hs_code_id AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''hs_code_id'', CAST(OLD.hs_code_id AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''note'', NULL, CAST(NEW.note AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.note AS TEXT), '''') <> COALESCE(CAST(OLD.note AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''note'', CAST(OLD.note AS Text), CAST(NEW.note AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''note'', CAST(OLD.note AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''legacy_sku'', NULL, CAST(NEW.legacy_sku AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.legacy_sku AS TEXT), '''') <> COALESCE(CAST(OLD.legacy_sku AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''legacy_sku'', CAST(OLD.legacy_sku AS Text), CAST(NEW.legacy_sku AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''legacy_sku'', CAST(OLD.legacy_sku AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''colour_filter_id'', NULL, CAST(NEW.colour_filter_id AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.colour_filter_id AS TEXT), '''') <> COALESCE(CAST(OLD.colour_filter_id AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''colour_filter_id'', CAST(OLD.colour_filter_id AS Text), CAST(NEW.colour_filter_id AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''colour_filter_id'', CAST(OLD.colour_filter_id AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''payment_term_id'', NULL, CAST(NEW.payment_term_id AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.payment_term_id AS TEXT), '''') <> COALESCE(CAST(OLD.payment_term_id AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''payment_term_id'', CAST(OLD.payment_term_id AS Text), CAST(NEW.payment_term_id AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''payment_term_id'', CAST(OLD.payment_term_id AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''payment_deposit_id'', NULL, CAST(NEW.payment_deposit_id AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.payment_deposit_id AS TEXT), '''') <> COALESCE(CAST(OLD.payment_deposit_id AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''payment_deposit_id'', CAST(OLD.payment_deposit_id AS Text), CAST(NEW.payment_deposit_id AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''payment_deposit_id'', CAST(OLD.payment_deposit_id AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''payment_settlement_discount_id'', NULL, CAST(NEW.payment_settlement_discount_id AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.payment_settlement_discount_id AS TEXT), '''') <> COALESCE(CAST(OLD.payment_settlement_discount_id AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''payment_settlement_discount_id'', CAST(OLD.payment_settlement_discount_id AS Text), CAST(NEW.payment_settlement_discount_id AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''payment_settlement_discount_id'', CAST(OLD.payment_settlement_discount_id AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''operator_id'', NULL, CAST(NEW.operator_id AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.operator_id AS TEXT), '''') <> COALESCE(CAST(OLD.operator_id AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''operator_id'', CAST(OLD.operator_id AS Text), CAST(NEW.operator_id AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''operator_id'', CAST(OLD.operator_id AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
 ELSIF (TG_RELNAME = ''price_default'') THEN
 
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''product_id'', NULL, CAST(NEW.product_id AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.product_id AS TEXT), '''') <> COALESCE(CAST(OLD.product_id AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''product_id'', CAST(OLD.product_id AS Text), CAST(NEW.product_id AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''product_id'', CAST(OLD.product_id AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''price'', NULL, CAST(NEW.price AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.price AS TEXT), '''') <> COALESCE(CAST(OLD.price AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''price'', CAST(OLD.price AS Text), CAST(NEW.price AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''price'', CAST(OLD.price AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''currency_id'', NULL, CAST(NEW.currency_id AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.currency_id AS TEXT), '''') <> COALESCE(CAST(OLD.currency_id AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''currency_id'', CAST(OLD.currency_id AS Text), CAST(NEW.currency_id AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''currency_id'', CAST(OLD.currency_id AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''complete_by_operator_id'', NULL, CAST(NEW.complete_by_operator_id AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.complete_by_operator_id AS TEXT), '''') <> COALESCE(CAST(OLD.complete_by_operator_id AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''complete_by_operator_id'', CAST(OLD.complete_by_operator_id AS Text), CAST(NEW.complete_by_operator_id AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''complete_by_operator_id'', CAST(OLD.complete_by_operator_id AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''complete'', NULL, CAST(NEW.complete AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.complete AS TEXT), '''') <> COALESCE(CAST(OLD.complete AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''complete'', CAST(OLD.complete AS Text), CAST(NEW.complete AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''complete'', CAST(OLD.complete AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''operator_id'', NULL, CAST(NEW.operator_id AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.operator_id AS TEXT), '''') <> COALESCE(CAST(OLD.operator_id AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''operator_id'', CAST(OLD.operator_id AS Text), CAST(NEW.operator_id AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''operator_id'', CAST(OLD.operator_id AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''id'', NULL, CAST(NEW.id AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.id AS TEXT), '''') <> COALESCE(CAST(OLD.id AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''id'', CAST(OLD.id AS Text), CAST(NEW.id AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''id'', CAST(OLD.id AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
 ELSIF (TG_RELNAME = ''price_country'') THEN
 
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''product_id'', NULL, CAST(NEW.product_id AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.product_id AS TEXT), '''') <> COALESCE(CAST(OLD.product_id AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''product_id'', CAST(OLD.product_id AS Text), CAST(NEW.product_id AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''product_id'', CAST(OLD.product_id AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''country_id'', NULL, CAST(NEW.country_id AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.country_id AS TEXT), '''') <> COALESCE(CAST(OLD.country_id AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''country_id'', CAST(OLD.country_id AS Text), CAST(NEW.country_id AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''country_id'', CAST(OLD.country_id AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''price'', NULL, CAST(NEW.price AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.price AS TEXT), '''') <> COALESCE(CAST(OLD.price AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''price'', CAST(OLD.price AS Text), CAST(NEW.price AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''price'', CAST(OLD.price AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''currency_id'', NULL, CAST(NEW.currency_id AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.currency_id AS TEXT), '''') <> COALESCE(CAST(OLD.currency_id AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''currency_id'', CAST(OLD.currency_id AS Text), CAST(NEW.currency_id AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''currency_id'', CAST(OLD.currency_id AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''operator_id'', NULL, CAST(NEW.operator_id AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.operator_id AS TEXT), '''') <> COALESCE(CAST(OLD.operator_id AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''operator_id'', CAST(OLD.operator_id AS Text), CAST(NEW.operator_id AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''operator_id'', CAST(OLD.operator_id AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
  IF (TG_OP = ''INSERT'') THEN
   
   INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''id'', NULL, CAST(NEW.id AS Text), v_product_id, v_action_id, v_comment);
  ELSIF (TG_OP = ''UPDATE'') THEN
   IF ( COALESCE(CAST(NEW.id AS TEXT), '''') <> COALESCE(CAST(OLD.id AS TEXT), '''') ) THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''id'', CAST(OLD.id AS Text), CAST(NEW.id AS Text), v_product_id, v_action_id, v_comment);
   END IF;
  ELSIF (TG_OP = ''DELETE'') THEN
    INSERT INTO audit.product (operator_id, table_id, pushed_to_live, field_name, value_pre, value_post, product_id, action_id, comment) VALUES (v_operator_id, v_table_id, v_pushed_to_live, ''id'', CAST(OLD.id AS Text), NULL, v_product_id, v_action_id, v_comment);
  END IF;
 END IF;
 

    
    IF (TG_OP = ''DELETE'') THEN
        RETURN OLD;
    END IF;
 
    RETURN NEW;
END;
' LANGUAGE plpgsql;

CREATE TRIGGER audit_tgr AFTER INSERT OR UPDATE OR DELETE ON product FOR EACH ROW EXECUTE PROCEDURE product_audit();


COMMIT;