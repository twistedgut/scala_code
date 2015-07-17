--
-- Hacky pre-order name, until product management do it properly

BEGIN WORK;

CREATE
 TABLE hacky_preorder_name (
           product_id       INTEGER        NOT NULL UNIQUE,
           name             TEXT           NOT NULL,
           FOREIGN KEY      (product_id)   REFERENCES product(id)
       );
    
GRANT ALL ON hacky_preorder_name TO www;

COMMIT WORK;
